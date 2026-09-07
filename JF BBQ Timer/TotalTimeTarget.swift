// TotalTimeTarget.swift
// Grill Time Pro
//
// Pure math for the optional per-timer "Total Time" alert (total-time-spec.md).
// Total Time is measured against Lit (TimerState.elapsed(at:)), NOT the flip
// countdown: Lit is wall-clock since the cook first started and keeps running
// while the flip timer is paused, so `doneAt` is a fixed absolute date the
// moment the cook starts — the same reason the background alert can be a
// scheduled local notification, same as `scheduleCompletionNotification(at:)`.
//
// iOS-only (not needed on the watch this build).

import Foundation

enum TotalTimeTarget {
    /// The absolute instant the cook hits its total time.
    /// Nil when no target is set or the cook has not started (no Lit start).
    static func doneAt(elapsedStart: Date?, totalTime: Int?) -> Date? {
        guard let start = elapsedStart, let total = totalTime, total > 0 else { return nil }
        return start.addingTimeInterval(TimeInterval(total))
    }

    /// Seconds past the target at `now` (well, at the elapsed value passed
    /// in), or nil when not yet past / not set. Drives the card's "+1:20".
    /// Nil (not zero) exactly at the boundary — the card shows the plain
    /// "/ 12:00" form until Lit is genuinely past it.
    static func overtime(elapsed: TimeInterval, totalTime: Int?) -> TimeInterval? {
        guard let total = totalTime, total > 0 else { return nil }
        let diff = elapsed - TimeInterval(total)
        return diff > 0 ? diff : nil
    }
}

/// Fire-once latch for the Total Time "done" alert. Modelled on
/// `TargetCrossingLatch` (same shape, same reason): must observe elapsed
/// BELOW the target at least once before it can fire, so a target set below
/// the current Lit value never fires an instant, confusing alert — it simply
/// never fires for that cook. Elapsed never decreases except on Reset, so
/// unlike `TargetCrossingLatch` there is no re-arm hysteresis band: once
/// latched, only `reset()` re-arms it.
struct TotalTimeLatch: Equatable {

    private enum State: Equatable {
        /// Waiting to see elapsed below the target.
        case waitingForBelow
        /// Seen below; the next elapsed at/above the target fires.
        case armed
        /// Fired; quiet until reset().
        case latched
    }

    private var state: State = .waitingForBelow

    /// Re-arm from scratch — call on Reset and whenever the target value changes.
    mutating func reset() {
        state = .waitingForBelow
    }

    /// Feed elapsed on each tick. Returns true exactly once, when elapsed
    /// first reaches the target.
    mutating func update(elapsed: TimeInterval, totalTime: Int?) -> Bool {
        guard let total = totalTime, total > 0 else {
            state = .waitingForBelow
            return false
        }
        let target = TimeInterval(total)

        switch state {
        case .waitingForBelow:
            if elapsed < target { state = .armed }
            return false
        case .armed:
            if elapsed >= target {
                state = .latched
                return true
            }
            return false
        case .latched:
            return false
        }
    }
}
