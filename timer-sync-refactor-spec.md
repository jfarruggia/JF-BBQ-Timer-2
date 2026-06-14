# Spec: Timer Sync Refactor (date-based countdown)

**Status:** Ready for implementation
**Scope:** Logic refactor only — no UI redesign, no Liquid Glass work, no Bluetooth. Those are separate specs.

---

## Problem

Grill timers drift, freeze, or show stale values when the Apple Watch sleeps (wrist down) or either app is suspended/backgrounded. On wake, the displayed time is wrong.

## Root cause (to confirm)

The countdown is almost certainly driven by a **ticking `Timer`** that decrements a stored seconds value every second. When the OS suspends the app, the timer stops firing, so the counter no longer reflects real elapsed time. **First, confirm this** by inspecting how timers are currently modeled and stored, and report the actual implementation before changing it.

## The fix in one sentence

Stop counting down; start computing. The **source of truth becomes the timer's absolute end `Date`**, remaining time is derived on demand (`endDate.timeIntervalSinceNow`), the on-screen ticking becomes a pure UI refresh, and completion alerts are delivered by **scheduled local notifications** that fire regardless of app state.

## Success criteria

1. Start a 20-minute timer, lock the phone / drop the wrist for several minutes, return → the remaining time is **immediately correct**, with no catch-up animation or drift.
2. A timer that reaches zero while the app is backgrounded/suspended **still alerts** the user (local notification).
3. Pausing and resuming a timer preserves the correct remaining time across suspension.
4. The same timer shows a consistent remaining time on phone and watch (within normal sync latency).
5. Timer logic is covered by unit tests with an **injectable "now"** — no test depends on real elapsed wall-clock time.

---

## Design

### 1. Model: end date as source of truth

A running timer stores its **`endDate: Date`** (absolute). Remaining time is always derived, never stored as a decrementing value:

```swift
var remaining: TimeInterval { max(0, endDate.timeIntervalSinceNow) }
var isFinished: Bool { remaining <= 0 }
```

Because `Date` is absolute, this is correct after any amount of suspension, and is robust to the device sleeping. Make the derivation a **pure function** that takes `now` as a parameter so it can be unit-tested:

```swift
func remaining(at now: Date) -> TimeInterval { max(0, endDate.timeIntervalSince(now)) }
```

### 2. UI refresh is separate from truth

The visible ticking is *only* a display concern. Two options, prefer (a) where it fits:

- **(a) System-managed live text** for anything that must stay live on the watch (including Always-On Display):
  ```swift
  Text(timerInterval: Date.now...endDate, countsDown: true)
  ```
  This updates itself without your code running.
- **(b)** A lightweight foreground refresh (e.g. a SwiftUI `TimelineView` or a 1 Hz timer **used only to re-render**) that reads `remaining(at:)`. This must never be the source of truth — if it stops, the displayed value is still recomputed correctly on next read.

### 3. Completion alerts via local notifications

When a timer starts (or resumes), schedule a `UNUserNotificationCenter` local notification for `endDate`. This fires even if the app is suspended or the watch is asleep.

- Cancel/reschedule the pending notification whenever the timer is **paused, resumed, edited, or canceled** (track it by a stable identifier per timer).
- **Decision point for Jim:** in a companion setup, both phone and watch could schedule notifications for the same end time, risking a double alert. Options: (i) only the iPhone schedules and presents, (ii) coordinate so whichever device is "active on the wrist/in hand" alerts. Pick based on the intended UX — a griller may be away from the phone with the watch on. Flag this and implement the chosen approach; don't silently pick one.

### 4. Pause / resume

You cannot keep an `endDate` while paused (time keeps moving). On pause, snapshot the remaining interval and drop the end date; on resume, rebuild it:

```swift
// Pause
remainingWhilePaused = endDate.timeIntervalSinceNow
endDate = nil
// cancel the pending notification

// Resume
endDate = Date.now.addingTimeInterval(remainingWhilePaused)
remainingWhilePaused = nil
// reschedule the notification for the new endDate
```

### 5. Phone ↔ Watch sync (WatchConnectivity)

The **iPhone is the source of truth.** Sync the **`endDate` (and paused-remaining), never the running count.** Syncing an absolute end date means both devices compute the same remaining time independently and stay correct even if a message is briefly delayed.

- On start/pause/resume/edit/cancel, send the timer's authoritative state (id, endDate or paused-remaining, status) over `WCSession`.
- If a timer can be **started from the watch**, send that intent to the phone, let the phone establish the authoritative `endDate`, and echo it back. Avoid both sides independently inventing end dates.
- Use an appropriate transfer method for reliability (e.g. application context / user info transfer for state that must survive reachability gaps, rather than only live messages). Confirm what the current `WCSession` setup uses and keep it consistent.

### 6. Persistence & relaunch

Persist running timers (their `endDate` / paused-remaining / status) so a timer survives app relaunch and is rehydrated correctly. Use the project's existing persistence layer — **identify it first** (see CLAUDE.md "First Run") rather than introducing a new one.

---

## Edge cases to handle

- Timer completes while suspended → notification fires; on next launch the UI shows finished state (don't "resurrect" it as still running).
- Multiple simultaneous timers (multiple grill items) → each has its own id, endDate, and notification. Confirm whether the app supports concurrent timers and handle accordingly.
- Manual clock change / time zone change → using absolute `Date` handles this naturally; verify nothing reintroduces local elapsed-counting.
- App force-quit then relaunched → rehydrate from persistence; reconcile against any already-fired notification.

## Testing requirements

- Unit-test `remaining(at:)` and the pause/resume math with **injected `now`** values — finished, partway, just-started, paused-then-resumed.
- Test that scheduling/canceling notifications happens on the right state transitions (can use a protocol-wrapped notification scheduler with a test double).
- Run `xcodebuild test` and confirm green before opening the PR.

## Explicitly out of scope

Watch UI redesign, full-screen layout, Liquid Glass adoption, onboarding changes, Bluetooth probe. Keep this PR to the timer/sync logic and its tests.

## Suggested implementation order

1. Confirm current timer implementation + persistence layer; report findings.
2. Introduce end-date model + pure `remaining(at:)` function with unit tests.
3. Migrate the iOS app's timer logic to the new model; keep existing UI wired to the derived value.
4. Add/repair local notification scheduling with pause/resume/cancel handling.
5. Update `WCSession` sync to send authoritative end-date state.
6. Migrate the watch app to read derived remaining time (+ `Text(timerInterval:)` where live display is needed).
7. Persist & rehydrate running timers.
8. Full test pass; summarize what to verify manually in Xcode (the suspension scenarios above).
