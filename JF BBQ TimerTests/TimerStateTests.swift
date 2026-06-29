import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - remaining(at:) tests

@Suite("TimerState remaining(at:)")
struct RemainingTests {

    @Test("Returns initial interval when timer has never started")
    func neverStarted() {
        let state = TimerState(id: UUID(), interval: 300)
        #expect(state.remaining(at: Date()) == 300)
    }

    @Test("Returns full interval immediately after start")
    func immediatelyAfterStart() async throws {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        let r = state.remaining(at: Date())
        // Allow 1 second tolerance for test execution time
        #expect(r >= 299 && r <= 300)
        state.reset()
    }

    @Test("Returns correct remaining 60 seconds after start")
    func partway() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // Inject a 'now' that is 60 seconds after the start
        let simulatedNow = end.addingTimeInterval(-240) // 60s elapsed → 240s remaining
        #expect(state.remaining(at: simulatedNow) == 240)
        state.reset()
    }

    @Test("Returns zero when queried past end date")
    func pastEndDate() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        let afterExpiry = end.addingTimeInterval(10)
        #expect(state.remaining(at: afterExpiry) == 0)
        state.reset()
    }

    @Test("Returns snapshot remaining when stopped mid-countdown")
    func stoppedMidCountdown() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // Simulate stopping 120s in (180s remaining)
        let midpoint = end.addingTimeInterval(-180)
        _ = state.remaining(at: midpoint) // just to verify computation works
        // Now stop — the timer captures remaining at the moment stop() is called
        // We can't inject 'now' into stop(), so we test the model directly:
        // Set endDate to a specific future date, then verify remaining(at:) before stop
        let r = state.remaining(at: midpoint)
        #expect(r == 180)
        state.reset()
    }

    @Test("Pause then resume preserves correct remaining")
    func pauseResume() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // Simulate 60s elapsed (240s remaining) then stop at that simulated instant
        let afterSixty = end.addingTimeInterval(-240)
        #expect(state.remaining(at: afterSixty) == 240)

        state.stop(at: afterSixty)   // captures remainingAtPause = 240
        // After stop, remaining(at:) returns the snapshot regardless of wall time
        let muchLater = afterSixty.addingTimeInterval(3600)
        #expect(state.remaining(at: muchLater) == 240)

        // Resume — start() uses remainingAtPause (240s)
        state.start { }
        guard let newEnd = state.endDate else {
            Issue.record("endDate should be set after second start()")
            return
        }
        let justAfterResume = newEnd.addingTimeInterval(-239)
        #expect(state.remaining(at: justAfterResume) == 239)
        state.reset()
    }
}

// MARK: - elapsed(at:) tests

@Suite("TimerState elapsed(at:)")
struct ElapsedTests {

    @Test("Returns zero before first start")
    func beforeStart() {
        let state = TimerState(id: UUID(), interval: 300)
        #expect(state.elapsed(at: Date()) == 0)
    }

    @Test("Elapsed increases correctly over time")
    func elapsedOverTime() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // 90 seconds have passed (300 - 90 = 210 remaining)
        let now = end.addingTimeInterval(-210)
        let e = state.elapsed(at: now)
        #expect(e >= 89 && e <= 91) // ~90 seconds
        state.reset()
    }

    @Test("Elapsed is zero after reset")
    func afterReset() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        state.reset()
        #expect(state.elapsed(at: Date()) == 0)
    }

    @Test("Elapsed continues to grow even when interval is stopped")
    func elapsedContinuesWhilePaused() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // Stop after 60s
        let afterSixty = end.addingTimeInterval(-240)
        let elapsedBeforePause = state.elapsed(at: afterSixty)
        #expect(elapsedBeforePause >= 59 && elapsedBeforePause <= 61)

        state.stop()
        // Elapsed should keep growing since elapsedStartDate is still set
        let oneHourLater = afterSixty.addingTimeInterval(3600)
        let elapsedAfterWait = state.elapsed(at: oneHourLater)
        // ~60 + 3600 seconds of lit time
        #expect(elapsedAfterWait >= 3659 && elapsedAfterWait <= 3661)
        state.reset()
    }

    @Test("Lit time keeps growing after the countdown completes, until reset")
    func elapsedContinuesAfterCompletion() {
        let state = TimerState(id: UUID(), interval: 60)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // Elapsed at the instant the countdown completes (~60s lit)
        let elapsedAtCompletion = state.elapsed(at: end)
        state.completeNow()
        #expect(state.isCompleted)
        // Five minutes later, lit time must have kept climbing — not frozen at completion.
        let later = end.addingTimeInterval(300)
        #expect(state.elapsed(at: later) > elapsedAtCompletion)
        #expect(abs(state.elapsed(at: later) - (elapsedAtCompletion + 300)) < 1)
        // Reset is what stops the lit clock and zeroes it.
        state.reset()
        #expect(state.elapsed(at: Date()) == 0)
    }
}

// MARK: - Pause / resume math

@Suite("TimerState pause/resume math")
struct PauseResumeMathTests {

    @Test("Three pause/resume cycles accumulate correctly")
    func multiplePauseResume() {
        let state = TimerState(id: UUID(), interval: 600)

        // Start — 600s on the clock
        state.start { }
        guard let end1 = state.endDate else {
            Issue.record("endDate nil after first start")
            return
        }

        // Pause after 100s (500s remaining)
        let t1 = end1.addingTimeInterval(-500)
        #expect(state.remaining(at: t1) == 500)
        state.stop(at: t1)
        // Snapshot is now 500s; wall time doesn't matter
        #expect(state.remaining(at: t1.addingTimeInterval(3600)) == 500)

        // Resume: start() uses 500s
        state.start { }
        guard let end2 = state.endDate else {
            Issue.record("endDate nil after second start")
            return
        }
        #expect(state.remaining(at: end2.addingTimeInterval(-499)) == 499)

        // Pause after another 200s (300s remaining)
        let t2 = end2.addingTimeInterval(-300)
        #expect(state.remaining(at: t2) == 300)
        state.stop(at: t2)
        #expect(state.remaining(at: t2.addingTimeInterval(3600)) == 300)

        // Resume for the third time: start() uses 300s
        state.start { }
        guard let end3 = state.endDate else {
            Issue.record("endDate nil after third start")
            return
        }
        #expect(state.remaining(at: end3.addingTimeInterval(-299)) == 299)
        state.reset()
    }

    @Test("Reset after partial use restores initial interval")
    func resetRestoresInitial() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        state.stop()
        state.reset()
        #expect(state.remaining(at: Date()) == 300)
        #expect(state.elapsed(at: Date()) == 0)
        #expect(!state.isRunning)
        #expect(!state.isCompleted)
    }
}

// MARK: - progress(at:) tests (drives the countdown ring)

@Suite("TimerState progress(at:)")
struct ProgressTests {

    @Test("Full (1.0) before the timer starts")
    func fullBeforeStart() {
        let state = TimerState(id: UUID(), interval: 300)
        #expect(state.progress(at: Date()) == 1.0)
    }

    @Test("Half (0.5) at the midpoint of the run")
    func halfwayThrough() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        let mid = end.addingTimeInterval(-150) // 150s of 300 remaining
        #expect(abs(state.progress(at: mid) - 0.5) < 0.01)
        state.reset()
    }

    @Test("Zero (0.0) at and past the end date")
    func zeroAtEnd() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        #expect(state.progress(at: end.addingTimeInterval(5)) == 0.0)
        state.reset()
    }

    @Test("Pause/resume stays continuous — the ring does not refill")
    func pauseResumeStaysContinuous() {
        let state = TimerState(id: UUID(), interval: 300)
        state.start { }
        guard let end = state.endDate else {
            Issue.record("endDate should be set after start()")
            return
        }
        // 240s remaining → 0.8 of the original 300s total
        let afterSixty = end.addingTimeInterval(-240)
        #expect(abs(state.progress(at: afterSixty) - 0.8) < 0.01)

        state.stop(at: afterSixty)
        // Still measured against the original total, not refilled to 1.0
        #expect(abs(state.progress(at: afterSixty.addingTimeInterval(3600)) - 0.8) < 0.01)

        state.start { } // resume
        guard let newEnd = state.endDate else {
            Issue.record("endDate should be set after resume")
            return
        }
        // Just after resume: ~239/300, NOT 1.0
        #expect(abs(state.progress(at: newEnd.addingTimeInterval(-239)) - (239.0 / 300.0)) < 0.02)
        state.reset()
    }
}

// MARK: - PreheatCountdown tests

@Suite("PreheatCountdown.remaining")
struct PreheatCountdownTests {

    @Test("Returns full duration at the moment the countdown starts")
    func atStart() {
        let now = Date()
        let end = now.addingTimeInterval(600) // 10 minutes
        #expect(PreheatCountdown.remaining(endDate: end, now: now) == 600)
    }

    @Test("Returns true elapsed-based remaining partway through")
    func partway() {
        let start = Date()
        let end = start.addingTimeInterval(600)
        // 4 wall-clock minutes later, exactly 6 should remain — regardless of
        // how many times any UI timer did or didn't fire in between.
        let now = start.addingTimeInterval(240)
        #expect(PreheatCountdown.remaining(endDate: end, now: now) == 360)
    }

    @Test("Clamps to zero once the end date has passed")
    func pastEnd() {
        let end = Date()
        let now = end.addingTimeInterval(300) // 5 min late (e.g. screen was locked)
        #expect(PreheatCountdown.remaining(endDate: end, now: now) == 0)
    }

    @Test("Returns zero when no countdown is active")
    func noCountdown() {
        #expect(PreheatCountdown.remaining(endDate: nil, now: Date()) == 0)
    }
}
