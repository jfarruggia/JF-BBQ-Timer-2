// TargetCrossingLatch.swift
// Grill Time Pro
//
// Pure edge-triggered latch for the phone-side target-crossed alert (spec 3D).
// Independent of the probe's prediction engine: watches the ACTUAL measured
// core temperature and fires once when it crosses the cook's target. This is
// the safety net for cooks where the prediction never converges, the user
// ignores the carryover flow, or the Set Prediction write failed.
//
// Rules (from probe-target-prediction-spec.md):
//   • Arms when a target is set; must see at least one reading BELOW the
//     target before it can fire (guards against attaching an already-hot probe).
//   • Fires exactly once, then stays latched.
//   • Re-arms only if the core falls ≥ 2 °C below the target (genuine new
//     heating cycle, not sensor noise at the boundary).
//   • Reset on target change (handled by the owner calling `reset()`).
//   • Readings at the −20 °C sensor floor mean "no data" and are ignored.

import Foundation

struct TargetCrossingLatch: Equatable {

    /// Hysteresis band: after firing, the core must fall this far below the
    /// target before the latch re-arms.
    static let rearmHysteresisCelsius = 2.0

    /// Readings at/below this are the sensor's no-data floor, not temperatures.
    private static let noDataFloorCelsius = -19.99

    private enum State: Equatable {
        /// Waiting to see a reading below the target.
        case waitingForBelow
        /// Seen below; the next reading at/above the target fires.
        case armed
        /// Fired; quiet until the core falls out the bottom of the hysteresis band.
        case latched
    }

    private var state: State = .waitingForBelow

    /// Re-arm from scratch — call when the target changes or the cook resets.
    mutating func reset() {
        state = .waitingForBelow
    }

    /// Feed one measured core reading. Returns true exactly when the
    /// target-crossed alert should fire.
    mutating func update(coreCelsius: Double, targetCelsius: Double?) -> Bool {
        guard let target = targetCelsius else {
            state = .waitingForBelow
            return false
        }
        guard coreCelsius > Self.noDataFloorCelsius else { return false }

        switch state {
        case .waitingForBelow:
            if coreCelsius < target { state = .armed }
            return false
        case .armed:
            if coreCelsius >= target {
                state = .latched
                return true
            }
            return false
        case .latched:
            if coreCelsius <= target - Self.rearmHysteresisCelsius {
                // Genuinely cooled well below target — new heating cycle.
                state = .armed
            }
            return false
        }
    }
}
