// TargetCrossingLatchTests.swift
// Grill Time Pro
//
// Swift Testing suite for TargetCrossingLatch — the phone-side, measured-core
// target-crossed alert latch (spec 3D).

import Testing
import Foundation
@testable import JF_BBQ_Timer

@Suite("TargetCrossingLatch")
struct TargetCrossingLatchTests {

    @Test("classic cook: below → cross fires exactly once")
    func firesOnceOnCrossing() {
        var latch = TargetCrossingLatch()
        #expect(latch.update(coreCelsius: 40, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 80, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 95.1, targetCelsius: 95) == true)
        // Stays latched through further readings above target
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 97, targetCelsius: 95) == false)
    }

    @Test("exactly hitting the target counts as crossing")
    func firesAtExactTarget() {
        var latch = TargetCrossingLatch()
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 95, targetCelsius: 95) == true)
    }

    @Test("attaching an already-hot probe must not fire until a genuine below-then-cross")
    func alreadyHotProbeGuard() {
        var latch = TargetCrossingLatch()
        // First readings already above target — no alert
        #expect(latch.update(coreCelsius: 98, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 99, targetCelsius: 95) == false)
        // Falls below (new food / cooled), then crosses → fires
        #expect(latch.update(coreCelsius: 90, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 95.5, targetCelsius: 95) == true)
    }

    @Test("boundary noise inside the hysteresis band does not re-fire")
    func noiseAtBoundaryStaysQuiet() {
        var latch = TargetCrossingLatch()
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 95.2, targetCelsius: 95) == true)
        // Wobble just under target (within 2 °C) then back over — silent
        #expect(latch.update(coreCelsius: 94.5, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 95.3, targetCelsius: 95) == false)
    }

    @Test("falling ≥ 2 °C below the target re-arms for a genuine second cycle")
    func rearmsAfterHysteresisDrop() {
        var latch = TargetCrossingLatch()
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 95.5, targetCelsius: 95) == true)
        // Cools well below target (e.g. second batch on the same cook)
        #expect(latch.update(coreCelsius: 92.9, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 95.1, targetCelsius: 95) == true)
    }

    @Test("nil target is inert and clears arming history")
    func nilTargetInert() {
        var latch = TargetCrossingLatch()
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)   // armed
        _ = latch.update(coreCelsius: 91, targetCelsius: nil)  // target cleared
        // Target restored — must require seeing below again before firing
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 90, targetCelsius: 95) == false)
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == true)
    }

    @Test("no-data floor readings (−20 °C) are ignored, not treated as below-target")
    func noDataFloorIgnored() {
        var latch = TargetCrossingLatch()
        #expect(latch.update(coreCelsius: -20.0, targetCelsius: 95) == false)
        // Still not armed: the floor reading must not count as \"seen below\"
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == false)
        // Real below-target reading arms it
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == true)
    }

    @Test("reset() requires a fresh below-then-cross")
    func resetRearms() {
        var latch = TargetCrossingLatch()
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == true)
        latch.reset()
        #expect(latch.update(coreCelsius: 97, targetCelsius: 95) == false)  // above, not armed
        _ = latch.update(coreCelsius: 90, targetCelsius: 95)
        #expect(latch.update(coreCelsius: 96, targetCelsius: 95) == true)
    }
}
