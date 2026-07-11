// ProbeCookPhase.swift
// Grill Time Pro
//
// Pure state machine turning the probe's prediction status stream into a
// cook phase (for the card's probe strip) and fire-once alert events
// ("pull now", "resting done"). Foundation-only; unit-tested.
//
// Semantics note (spec 3C): Combustion's documentation defines the prediction
// states but not the removal→resting lifecycle, and their reference library
// never derives "resting complete". This engine therefore leans only on
// signals that are unambiguous:
//   • PULL NOW  = Prediction State enters `removalPredictionDone` while the
//     prediction type is NOT resting — the one documented "act now" signal.
//   • DONE      = while resting, either the probe re-enters
//     `removalPredictionDone`, or the estimated core crosses the app's OWN
//     stored target (never the probe-reported set point, whose meaning in
//     removal+resting mode is undocumented).
// Validate against a real cook (hardware checklist) and adjust if the probe's
// observed behavior contradicts these assumptions.

import Foundation

// MARK: - Phase
//
// NOTE: the `ProbeCookPhase` enum itself lives in WCSessionManager.swift — it
// is part of the phone→watch wire format, and that file is the one compiled
// into BOTH targets (the watch target does not include this file).

// MARK: - Events

/// Fire-once alert moments derived from phase transitions.
enum ProbeCookEvent: Equatable {
    case pullNow
    case restingDone
    /// The MEASURED core temp crossed the cook's target (phone-side safety
    /// net, `TargetCrossingLatch`) with no carryover alert having covered it.
    case targetReached
    /// Probe health, one-shot per user connection: battery low.
    case batteryLow
    /// Probe health, one-shot per user connection: a sensor is overheating.
    case overheating
}

// MARK: - Engine

/// Feed every decoded prediction update through `update(...)`; it returns the
/// alert events that became due (each fires at most once per cook — call
/// `reset()` when the target or the attachment changes to re-arm).
struct ProbeCookPhaseEngine: Equatable {

    private(set) var phase: ProbeCookPhase = .none
    private var firedPull = false
    private var firedDone = false

    /// Whether a carryover alert has already covered this cook — used by the
    /// owner to suppress the redundant phone-side target-crossed alert.
    var hasAlertedCarryover: Bool { firedPull || firedDone }

    mutating func reset() {
        self = ProbeCookPhaseEngine()
    }

    /// - Parameters:
    ///   - prediction: the decoded prediction block from a status notification.
    ///   - targetCelsius: the app's own stored target for the attached cook
    ///     (used as the trustworthy "done" threshold); nil when unset.
    /// - Returns: events to alert on, in order (practically 0 or 1).
    mutating func update(prediction: ProbePrediction, targetCelsius: Double?) -> [ProbeCookEvent] {
        // Nothing configured on the probe → plain display, no events.
        guard prediction.mode != .none else {
            phase = firedDone ? .done : .none
            return []
        }

        // An unreadable state must not flap the UI or re-fire alerts.
        if prediction.state == .unknown { return [] }

        var events: [ProbeCookEvent] = []

        if firedDone {
            phase = .done
            return []
        }

        let resting = (prediction.type == .resting)
        let coreAtTarget = targetCelsius.map { prediction.estimatedCoreTempC >= $0 } ?? false

        if resting {
            if prediction.state == .removalPredictionDone || coreAtTarget {
                phase = .done
                firedDone = true
                events.append(.restingDone)
            } else {
                phase = .resting
                // Entering resting implies the removal moment happened even if
                // we never saw state 4 (e.g. reconnect gap) — don't fire a
                // stale "pull now" later.
                firedPull = true
            }
        } else {
            switch prediction.state {
            case .removalPredictionDone:
                phase = .pullNow
                if !firedPull {
                    firedPull = true
                    events.append(.pullNow)
                }
            case .predicting:
                phase = firedPull ? .pullNow : .predictingRemoval
            default:
                // notInserted / inserted / cooking — keep pullNow sticky once
                // fired (pulling the probe's ambient off heat can bounce the
                // state); otherwise we're just monitoring.
                phase = firedPull ? .pullNow : .monitoring
            }
        }

        return events
    }
}
