// TotalTimeTargetTests.swift
// Grill Time Pro
//
// Swift Testing suite for TotalTimeTarget / TotalTimeLatch — the optional
// per-timer "Total Time" alert (total-time-spec.md). All time math is
// injectable-`now`-free here (doneAt/overtime take dates/intervals directly),
// per the house rule that time math must be pure and unit-tested.

import Testing
import Foundation
@testable import JF_BBQ_Timer

@Suite("TotalTimeTarget")
struct TotalTimeTargetTests {

    private let referenceStart = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - doneAt

    @Test("nil with no target")
    func doneAtNilWithNoTarget() {
        #expect(TotalTimeTarget.doneAt(elapsedStart: referenceStart, totalTime: nil) == nil)
    }

    @Test("nil with no elapsed start")
    func doneAtNilWithNoElapsedStart() {
        #expect(TotalTimeTarget.doneAt(elapsedStart: nil, totalTime: 720) == nil)
    }

    @Test("start + 720 for a 12-minute target")
    func doneAtTwelveMinutes() {
        let expected = referenceStart.addingTimeInterval(720)
        #expect(TotalTimeTarget.doneAt(elapsedStart: referenceStart, totalTime: 720) == expected)
    }

    @Test("unaffected by pause — there is no pause input, only elapsedStart")
    func doneAtIgnoresAnythingButElapsedStart() {
        // Calling twice with the same elapsedStart/totalTime always yields
        // the same absolute instant — nothing about "pause" can move it.
        let first = TotalTimeTarget.doneAt(elapsedStart: referenceStart, totalTime: 720)
        let second = TotalTimeTarget.doneAt(elapsedStart: referenceStart, totalTime: 720)
        #expect(first == second)
    }

    @Test("zero totalTime is treated as off, not an instant target")
    func doneAtZeroTotalTimeIsOff() {
        #expect(TotalTimeTarget.doneAt(elapsedStart: referenceStart, totalTime: 0) == nil)
    }

    // MARK: - overtime

    @Test("nil before the target")
    func overtimeNilBeforeTarget() {
        #expect(TotalTimeTarget.overtime(elapsed: 11 * 60, totalTime: 720) == nil)
    }

    @Test("nil exactly at the target")
    func overtimeNilExactlyAtTarget() {
        #expect(TotalTimeTarget.overtime(elapsed: 720, totalTime: 720) == nil)
    }

    @Test("+80 at 13:20 against a 12:00 target")
    func overtimeEightySecondsPast() {
        let elapsed: TimeInterval = 13 * 60 + 20 // 800s
        #expect(TotalTimeTarget.overtime(elapsed: elapsed, totalTime: 720) == 80)
    }

    @Test("nil when no target is set")
    func overtimeNilWithNoTarget() {
        #expect(TotalTimeTarget.overtime(elapsed: 999, totalTime: nil) == nil)
    }

    // MARK: - TotalTimeLatch

    @Test("fires once at the boundary and not again on later ticks")
    func latchFiresOnceAtBoundary() {
        var latch = TotalTimeLatch()
        #expect(latch.update(elapsed: 0, totalTime: 720) == false)
        #expect(latch.update(elapsed: 600, totalTime: 720) == false)
        #expect(latch.update(elapsed: 719, totalTime: 720) == false)
        #expect(latch.update(elapsed: 720, totalTime: 720) == true)   // boundary — fires here, not late
        #expect(latch.update(elapsed: 721, totalTime: 720) == false) // stays quiet
        #expect(latch.update(elapsed: 800, totalTime: 720) == false)
    }

    @Test("never fires when the target is nil")
    func latchNeverFiresWithNilTarget() {
        var latch = TotalTimeLatch()
        #expect(latch.update(elapsed: 0, totalTime: nil) == false)
        #expect(latch.update(elapsed: 10_000, totalTime: nil) == false)
    }

    @Test("never fires when the first observed elapsed is already past the target")
    func latchNeverFiresWhenAlreadyPast() {
        var latch = TotalTimeLatch()
        // First observation is already past the target — never having seen
        // "below" means this cook simply never fires.
        #expect(latch.update(elapsed: 900, totalTime: 720) == false)
        #expect(latch.update(elapsed: 1_000, totalTime: 720) == false)
        #expect(latch.update(elapsed: 10_000, totalTime: 720) == false)
    }

    @Test("reset() re-arms")
    func latchResetRearms() {
        var latch = TotalTimeLatch()
        _ = latch.update(elapsed: 0, totalTime: 720)
        #expect(latch.update(elapsed: 720, totalTime: 720) == true)
        latch.reset()
        // Fresh below-then-cross required again.
        #expect(latch.update(elapsed: 800, totalTime: 720) == false) // above, not armed yet
        _ = latch.update(elapsed: 0, totalTime: 720)
        #expect(latch.update(elapsed: 720, totalTime: 720) == true)
    }

    @Test("changing the target re-arms (owner calls reset())")
    func latchChangingTargetRearmsViaReset() {
        var latch = TotalTimeLatch()
        _ = latch.update(elapsed: 0, totalTime: 720)
        #expect(latch.update(elapsed: 720, totalTime: 720) == true)
        // Target changes to 5:00 (owner resets on target change) — Lit is
        // already at 12:00, well past the new target.
        latch.reset()
        #expect(latch.update(elapsed: 720, totalTime: 300) == false) // never seen below 300
        #expect(latch.update(elapsed: 800, totalTime: 300) == false)
    }

    @Test("a target set below current elapsed never fires that cook")
    func latchTargetBelowCurrentElapsedNeverFires() {
        var latch = TotalTimeLatch()
        // Lit is already at 9:00 when a 5:00 target is set.
        latch.reset()
        #expect(latch.update(elapsed: 540, totalTime: 300) == false)
        #expect(latch.update(elapsed: 600, totalTime: 300) == false)
        #expect(latch.update(elapsed: 700, totalTime: 300) == false)
    }
}
