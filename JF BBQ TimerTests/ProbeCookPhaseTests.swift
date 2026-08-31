// ProbeCookPhaseTests.swift
// Grill Time Pro
//
// Swift Testing suite for ProbeCookPhaseEngine — the pure state machine that
// turns prediction updates into cook phases and fire-once alert events.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - Prediction factory

private func prediction(
    state: PredictionState,
    type: PredictionType,
    mode: PredictionMode = .removalAndResting,
    estCore: Double = 50,
    setPoint: Double = 95,
    seconds: UInt32 = 600
) -> ProbePrediction {
    ProbePrediction(
        state: state,
        mode: mode,
        type: type,
        setPointTempC: setPoint,
        heatStartTempC: 20,
        predictionSeconds: seconds,
        estimatedCoreTempC: estCore
    )
}

@Suite("ProbeCookPhaseEngine")
struct ProbeCookPhaseTests {

    @Test("mode none → phase none, no events")
    func modeNoneIsInert() {
        var engine = ProbeCookPhaseEngine()
        let events = engine.update(
            prediction: prediction(state: .predicting, type: .none, mode: .none),
            targetCelsius: 95
        )
        #expect(events.isEmpty)
        #expect(engine.phase == .none)
    }

    @Test("full happy path: monitoring → pull in → PULL NOW → resting → done, each alert once")
    func happyPath() {
        var engine = ProbeCookPhaseEngine()

        // Probe inserted, prediction warming up
        var events = engine.update(prediction: prediction(state: .probeInserted, type: .removal),
                                   targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == .monitoring)

        // Counting down to removal
        events = engine.update(prediction: prediction(state: .predicting, type: .removal),
                               targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == .predictingRemoval)

        // Removal prediction done → the one PULL NOW alert
        events = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                               targetCelsius: 95)
        #expect(events == [.pullNow])
        #expect(engine.phase == .pullNow)

        // Same state again → no duplicate alert
        events = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                               targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == .pullNow)

        // Probe switches to resting prediction
        events = engine.update(prediction: prediction(state: .predicting, type: .resting, estCore: 90),
                               targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == .resting)

        // Resting completes (probe re-enters prediction-done) → the one DONE alert
        events = engine.update(prediction: prediction(state: .removalPredictionDone, type: .resting, estCore: 95),
                               targetCelsius: 95)
        #expect(events == [.restingDone])
        #expect(engine.phase == .done)

        // Anything after done stays done, silently
        events = engine.update(prediction: prediction(state: .predicting, type: .resting, estCore: 94),
                               targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == .done)
    }

    @Test("resting completes via the app's own target crossing")
    func doneViaOwnTargetCrossing() {
        var engine = ProbeCookPhaseEngine()
        _ = engine.update(prediction: prediction(state: .predicting, type: .resting, estCore: 93),
                          targetCelsius: 95)
        #expect(engine.phase == .resting)

        let events = engine.update(prediction: prediction(state: .predicting, type: .resting, estCore: 95.2),
                                   targetCelsius: 95)
        #expect(events == [.restingDone])
        #expect(engine.phase == .done)
    }

    @Test("core crossing uses the app's target, not the probe's set point")
    func crossingIgnoresProbeSetPoint() {
        var engine = ProbeCookPhaseEngine()
        // Probe-reported set point is low (semantics undocumented) but our
        // target is not yet reached → must NOT be done.
        let events = engine.update(
            prediction: prediction(state: .predicting, type: .resting, estCore: 80, setPoint: 75),
            targetCelsius: 95
        )
        #expect(events.isEmpty)
        #expect(engine.phase == .resting)

        // And with no app target at all, crossing can never fire.
        var engine2 = ProbeCookPhaseEngine()
        let events2 = engine2.update(
            prediction: prediction(state: .predicting, type: .resting, estCore: 200, setPoint: 75),
            targetCelsius: nil
        )
        #expect(events2.isEmpty)
        #expect(engine2.phase == .resting)
    }

    @Test("resting seen without a prior PULL NOW suppresses the stale pull alert")
    func restingSuppressesLatePull() {
        var engine = ProbeCookPhaseEngine()
        // e.g. reconnect gap swallowed the removal moment
        _ = engine.update(prediction: prediction(state: .predicting, type: .resting, estCore: 90),
                          targetCelsius: 95)
        #expect(engine.phase == .resting)

        // A weird late non-resting prediction-done must not fire pull-now
        let events = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                                   targetCelsius: 95)
        #expect(events.isEmpty)
    }

    @Test("pullNow phase is sticky across state wobble")
    func pullNowSticky() {
        var engine = ProbeCookPhaseEngine()
        _ = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                          targetCelsius: 95)
        #expect(engine.phase == .pullNow)

        // Food off the grill can bounce the state back to cooking/predicting
        _ = engine.update(prediction: prediction(state: .cooking, type: .removal),
                          targetCelsius: 95)
        #expect(engine.phase == .pullNow)
        _ = engine.update(prediction: prediction(state: .predicting, type: .removal),
                          targetCelsius: 95)
        #expect(engine.phase == .pullNow)
    }

    @Test("unknown state neither flaps the phase nor fires events")
    func unknownStateIgnored() {
        var engine = ProbeCookPhaseEngine()
        _ = engine.update(prediction: prediction(state: .predicting, type: .removal),
                          targetCelsius: 95)
        let before = engine.phase
        let events = engine.update(prediction: prediction(state: .unknown, type: .removal),
                                   targetCelsius: 95)
        #expect(events.isEmpty)
        #expect(engine.phase == before)
    }

    @Test("reset re-arms both alerts")
    func resetRearms() {
        var engine = ProbeCookPhaseEngine()
        _ = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                          targetCelsius: 95)
        _ = engine.update(prediction: prediction(state: .removalPredictionDone, type: .resting, estCore: 95),
                          targetCelsius: 95)
        #expect(engine.phase == .done)

        engine.reset()
        #expect(engine.phase == .none)

        let pullAgain = engine.update(prediction: prediction(state: .removalPredictionDone, type: .removal),
                                      targetCelsius: 96)
        #expect(pullAgain == [.pullNow])
    }
}

// MARK: - ProbeAlertContent

@Suite("ProbeAlertContent")
struct ProbeAlertContentTests {

    @Test("pullNow builds the act-now card with temp + name passed through")
    func pullNowContent() {
        let content = ProbeAlertContent.make(event: .pullNow, tempText: "135°F", cookName: "Ribeye")
        #expect(content?.symbolName == "thermometer.high")
        #expect(content?.cookName == "Ribeye")
        #expect(content?.tempText == "135°F")
        #expect(content?.message == "Pull the food now")
    }

    @Test("targetReached message")
    func targetReachedContent() {
        let content = ProbeAlertContent.make(event: .targetReached, tempText: "160°F", cookName: "Brisket")
        #expect(content?.message == "Target temperature reached")
        #expect(content?.tempText == "160°F")
        #expect(content?.cookName == "Brisket")
    }

    @Test("restingDone message")
    func restingDoneContent() {
        let content = ProbeAlertContent.make(event: .restingDone, tempText: "203°F", cookName: "Pork Shoulder")
        #expect(content?.message == "Food is ready")
        #expect(content?.symbolName == "thermometer.high")
    }

    @Test("batteryLow and overheating never get a card")
    func quietEventsReturnNil() {
        #expect(ProbeAlertContent.make(event: .batteryLow, tempText: "135°F", cookName: "Ribeye") == nil)
        #expect(ProbeAlertContent.make(event: .overheating, tempText: "135°F", cookName: "Ribeye") == nil)
    }

    @Test("nil temp and nil name are omitted, not placeholders")
    func nilInputsOmitLines() {
        let content = ProbeAlertContent.make(event: .pullNow, tempText: nil, cookName: nil)
        #expect(content?.tempText == nil)
        #expect(content?.cookName == nil)
    }

    @Test("empty or whitespace-only cook name is treated as nil")
    func blankNameOmitted() {
        let empty = ProbeAlertContent.make(event: .pullNow, tempText: "135°F", cookName: "")
        #expect(empty?.cookName == nil)

        let whitespace = ProbeAlertContent.make(event: .targetReached, tempText: "135°F", cookName: "   ")
        #expect(whitespace?.cookName == nil)
    }
}

// MARK: - Manager wiring

#if os(iOS)
@Suite("ProbeBLEManager cook-phase wiring")
@MainActor
struct ProbeCookPhaseManagerTests {

    @Test("setTarget resets the published cook phase")
    func setTargetResetsPhase() {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        mgr.setTarget(95.0)
        #expect(mgr.cookPhase == .none)
    }
}
#endif

// MARK: - Foreground notification presentation

// iOS hides a foreground app's notifications unless the delegate opts in.
// Probe alerts must show (they ARE the alert when the green card isn't
// visible); timer/preheat notifications stay suppressed — the in-app
// AlertView covers those and a banner would double-alert.
@Suite("foregroundNotificationOptions")
struct ForegroundNotificationOptionsTests {

    @Test("Probe alerts present with banner + sound in foreground")
    func probeAlertsPresent() {
        let opts = foregroundNotificationOptions(forIdentifier: "probe-alert-1234")
        #expect(opts.contains(.banner))
        #expect(opts.contains(.sound))
    }

    @Test("Timer and preheat notifications stay suppressed in foreground")
    func othersSuppressed() {
        #expect(foregroundNotificationOptions(forIdentifier: "timer-ABC") == [])
        #expect(foregroundNotificationOptions(forIdentifier: "preheat-XYZ") == [])
        #expect(foregroundNotificationOptions(forIdentifier: "anything") == [])
    }
}
