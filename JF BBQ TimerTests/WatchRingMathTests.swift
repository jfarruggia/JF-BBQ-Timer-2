// WatchRingMathTests.swift
// Grill Time Pro
//
// Swift Testing suite for WatchRingMath — the pure fill math behind the watch
// app's countdown ring (watch-ring-layout-spec.md). The helper compiles into
// both targets via WCSessionManager.swift, so tests run in the iOS target.

import Testing
@testable import JF_BBQ_Timer

struct WatchRingMathTests {
    @Test func fullRingAtStart() {
        #expect(WatchRingMath.progress(remaining: 300, runDuration: 300) == 1.0)
    }

    @Test func halfwayThrough() {
        #expect(WatchRingMath.progress(remaining: 150, runDuration: 300) == 0.5)
    }

    @Test func emptyWhenDone() {
        #expect(WatchRingMath.progress(remaining: 0, runDuration: 300) == 0.0)
    }

    @Test func clampsWhenRemainingExceedsDuration() {
        // Can happen briefly after a preset change races a stale snapshot.
        #expect(WatchRingMath.progress(remaining: 400, runDuration: 300) == 1.0)
    }

    @Test func clampsNegativeRemaining() {
        // endDate in the past (timer finished while watch was suspended).
        #expect(WatchRingMath.progress(remaining: -5, runDuration: 300) == 0.0)
    }

    @Test func zeroDurationIsSafe() {
        #expect(WatchRingMath.progress(remaining: 10, runDuration: 0) == 0.0)
    }

    @Test func negativeDurationIsSafe() {
        #expect(WatchRingMath.progress(remaining: 10, runDuration: -1) == 0.0)
    }
}
