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
