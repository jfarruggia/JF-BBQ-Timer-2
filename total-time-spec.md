# Spec: Total Time — an optional "this is done" alert per timer

**Decision (2026-09-07).** Jim raised this while making the help videos: the app's
method is flip-timer-only, and some people will look for a *total* cook time
("grill 12 minutes, turning once"). His expert tester was fine without it; a
beginner may not be. This adds the smallest honest version.

**Problem:** a timer answers "when do I flip?" There is no way to say "and it's
done after 12 minutes total", and no alert for it.

**Goal:** an optional per-timer Total Time. When Lit passes it, one alert fires.
Nothing stops. Lit keeps running so the cook can continue.

**Not this build:** no watch display, no watch alert, no second countdown ring,
no auto-stop. Total Time is a **free** feature.

## Decisions already made (do not re-open)

| | |
|---|---|
| Name shown to users | **Total Time** (not "Cook Time" — "Extend Cook Time" already exists) |
| Where it is set | Settings, beside Flip Time / Extend Cook Time |
| Price | **Free.** It exists to remove confusion; gating that is backwards |
| On firing | Alert only. The flip timer keeps running. Nothing is reset |
| Alert wording | "Ribeye is done" — deliberately different from "Ribeye timer is complete" |
| Past the target | Lit keeps counting. The card shows how far over |
| Fires | Exactly once per cook. Re-arms on Reset |
| Off by default | A timer with no Total Time behaves exactly as it does today |

---

## The clock it measures

**Total Time is measured against Lit (`TimerState.elapsed(at:)`), not the flip
countdown.** Lit is wall-clock since the timer first started
(`elapsedStartDate`), it keeps running while the flip timer is paused, and it
only returns to zero on **Reset**.

That is deliberate and is what Jim asked for: the food has been on the grill
that long regardless of what the flip timer is doing.

Two consequences that make this cheap:

- `doneAt = elapsedStartDate + totalTime` is an **absolute date**, fixed the
  moment the cook starts. It never moves. So the alert can be booked with iOS
  ahead of time and fires with the phone locked in a pocket — the same
  mechanism as `scheduleCompletionNotification(at:)` in `TimerState`.
- Nothing needs to poll. The in-app path only needs a check on the existing
  refresh tick; the background path is the scheduled notification.

---

## Storage

Follow the existing per-timer-value pattern, **not** a new field on `BBQTimer`.

`BBQTimer` is `Codable` and split across two homes: timers 1 and 2 live in
loose `@AppStorage` keys (`timer1Preset1`, …) and are rebuilt on the fly by
`legacyTimersAsBBQTimers`; the rest live in the `additionalTimers` JSON array.
A new field would need writing in both places.

Instead, in `Settings.swift`, mirror `probeTargetsByCookID`:

```swift
/// Optional per-timer total cook time in seconds. Timer ids are stable
/// (the two built-in timers use fixed UUIDs), so one dictionary covers both
/// storage homes with one code path — same reason probeTargetsByCookID exists.
/// Absent id == no Total Time set, which is the default.
@Published var totalTimeByTimerID: [UUID: Int] = [:]
```

- Load in `init` from `UserDefaults` key `"totalTimeByTimerID"`, JSON-decoded,
  defaulting to `[:]`, exactly like `probeTargetsByCookID` (~line 236).
- Persist in `save()` alongside it.
- Add `func totalTime(for id: UUID) -> Int?` and
  `func setTotalTime(_ seconds: Int?, for id: UUID)`. Setting `nil` (or `0`)
  **removes** the key — "off" is absence, not zero.
- Deleting a timer must remove its entry (`removeTimer(at:)`).

---

## Pure logic (unit-tested — house rule for time math)

New file `JF BBQ Timer/TotalTimeTarget.swift`, iOS-only (not needed on the
watch this build).

```swift
enum TotalTimeTarget {
    /// The absolute instant the cook hits its total time.
    /// Nil when no target is set or the cook has not started (no Lit start).
    static func doneAt(elapsedStart: Date?, totalTime: Int?) -> Date?

    /// Seconds past the target at `now`, or nil when not yet past / not set.
    /// Drives the card's "+1:20".
    static func overtime(elapsed: TimeInterval, totalTime: Int?) -> TimeInterval?
}
```

Plus a fire-once latch in the same file, modelled on `TargetCrossingLatch`:

```swift
struct TotalTimeLatch: Equatable {
    /// Feed elapsed on each tick. Returns true exactly once, when elapsed
    /// first reaches the target. Stays latched after that so a cook that
    /// runs long does not nag.
    mutating func update(elapsed: TimeInterval, totalTime: Int?) -> Bool
    /// Re-arm. Called on Reset and whenever the target value changes.
    mutating func reset()
}
```

Rules for the latch:

- No target ⇒ never fires, and the latch resets (so setting a target mid-cook
  arms cleanly).
- Must observe elapsed **below** the target at least once before it can fire —
  the same guard `TargetCrossingLatch` uses. This stops a target set *below*
  the current Lit from firing an instant, confusing alert. (Setting Total Time
  to 5:00 when Lit is already 9:00 simply never fires this cook. The card still
  shows the overtime.)
- Once latched, only `reset()` re-arms it. Elapsed never decreases except on
  Reset, so no hysteresis band is needed.

**Tests** (`JF BBQ TimerTests/TotalTimeTargetTests.swift`, Swift Testing,
injectable `now` — never wall-clock):

- `doneAt` — nil with no target; nil with no elapsed start; `start + 720` for
  a 12-minute target; unaffected by pause (there is no pause input).
- `overtime` — nil before the target; nil exactly at it; `+80` at 13:20 against
  12:00; nil when no target.
- Latch — fires once at the boundary and not again on later ticks; never fires
  when the target is nil; never fires when the first observed elapsed is
  already past the target; `reset()` re-arms; changing the target re-arms.
- Boundary: fires at exactly `elapsed == totalTime`, not one tick late.

---

## Wiring

### Arming and the background alert

Own the latch and the scheduled notification next to the existing flip-timer
notification logic in `TimerState`, so both live in one place:

- `TimerState` gains `totalTime: Int?` (pushed in from `Settings` when states
  are built/refreshed — `initializeTimerStates()` in `ContentView` is the
  existing choke point) and a `TotalTimeLatch`.
- On `start()` — book a second local notification with identifier
  `"done-\(id.uuidString)"` at `doneAt`, if a target is set and `doneAt` is in
  the future. Content: title `"Cook Complete"`, body `"\(displayName()) is
  done."`, the user's alert sound, `.timeSensitive`. Do **not** disturb the
  existing `"timer-\(id)"` notification.
- Re-booking must be idempotent: cancel `"done-\(id)"` before scheduling. The
  target date does not move, but `start()` runs again on every preset restart.
- On `reset()` — cancel `"done-\(id)"` and `latch.reset()`.
- When the target value changes in Settings — cancel, re-book, `latch.reset()`.
- Do **not** cancel it in `stop()`. Lit keeps running while paused, so the cook
  is still heading for its total time.

### The in-app alert

On the existing refresh tick, feed `latch.update(elapsed:totalTime:)`. When it
returns true, fire the same completion treatment the flip timer uses, with the
Total Time wording:

- Looping alert sound via the existing `Settings` sound path, and the alert
  overlay (`alertState.isPresented`) when haptics are on — matching what
  `onComplete` does today at `ContentView` ~274.
- If Voice Announcements are on, speak the Total Time phrase. Add a sibling to
  `AnnouncementMessage` — `static func spokenDone(timerName:) -> String`
  returning `"\(timerName) is done."` — and unit-test it beside the existing
  `AnnouncementMessage` tests. Do not change the flip-completion phrase.
- **Do not** call `stop()`, `reset()`, or touch `isCompleted`. The flip timer's
  own completion state is separate and must be unaffected.
- The alert overlay's dismiss/ack path must clear this alert the same way it
  clears a flip completion, including the `ackAlert` command from the wrist.

### No double alert

If a flip completion and the Total Time alert land on the same tick, the user
gets one sound, not two stacked loops. Suppress the Total Time sound when a
flip completion is already sounding on that timer; the notification and the
card's overtime still tell the story.

---

## Card display

Four places render the Lit line. All four change; the notched large card and
the compact card are the ones users see on iOS 26.

| View | File / line | Today |
|---|---|---|
| `GlassLargeTimerContent` (notched, iOS 26) | `TimerViews.swift` ~818 | `Lit 4:32` |
| `GlassCompactTimerContent` (iOS 26) | `TimerViews.swift` ~1003 | `Lit 4:32` |
| `ElapsedTimerView` (pre-26 large) | `TimerViews.swift` ~187/213 | big `LIT TIME` block |
| `CompactTimerView` (pre-26 compact) | `TimerViews.swift` ~351 | `Lit Time` panel |

Rules, same in all four:

- **No target set:** unchanged. Exactly today's output. This is the common case
  and must not shift by a pixel.
- **Target set, not reached:** `Lit 4:32 / 12:00`
- **Target passed:** `Lit 13:20 / 12:00  +1:20`

The `+1:20` ticks up with Lit. Reuse each view's existing `timeLabel` /
`TimeFormatter` helper so formatting matches its neighbours.

**Colour:** the whole line keeps its current styling. Do **not** tint the
overtime with the accent — accent orange means "tappable" in this app and this
line is read-only. If the overtime needs to stand apart, give it the same
colour at reduced opacity, nothing more.

On the two glass cards the line must stay on **one line** and keep
`.monospacedDigit()`, `minimumScaleFactor`, and `lineLimit(1)`. The notched
large card's geometry is spec'd in `notched-card-layout-spec.md` — the Lit line
sits in fixed space, so verify the longest realistic string
(`Lit 1:03:20 / 1:00:00  +3:20`) does not push the layout.

---

## Settings UI

> **Updated 2026-09-07,** after `duration-picker-spec.md` shipped. Total Time
> uses the new `DurationRow`, not a stepper — the steppers no longer exist.

Add a **Total Time** row directly below "Extend Cook Time" in **both** editor
sites in `SettingsViews.swift`:

- the edit-existing-timer form (`timerRow(for:isLegacy:legacyIndex:at:)`),
- the `addTimerSheet`.

Use `DurationRow` with `style: .hoursMinutes` — hours and minutes, matching the
table in `duration-picker-spec.md`. Minutes give the resolution quick items
need (shrimp at 6 minutes cannot round to 5 or 10) and hours make a brisket
reachable.

### "Off" needs a new capability on DurationRow

Total Time is the first **optional** duration in the app: absent means the
feature is off for that timer. `DurationRow` currently always renders a
formatted time, so `0` would read as `00:00:00`.

Add one parameter to `DurationRow` in `DurationPicker.swift`:

```swift
/// Shown in place of the formatted value when `seconds == 0`. Nil (the
/// default) keeps today's behaviour for every existing caller — a zero
/// duration renders as a normal time.
var offLabel: String? = nil
```

- When `offLabel != nil` and `seconds == 0`, the row shows that text instead of
  the time. Total Time passes `offLabel: "Off"`.
- Still accent-coloured with the chevron: the row is still tappable, and "Off"
  is still a value you change by tapping.
- The wheel sheet is unchanged. Spinning both wheels to zero **is** how you turn
  it off; there is no separate switch to forget about.
- Every existing caller keeps today's behaviour untouched — this is additive.

### Binding

- **Edit-existing-timer form:** unlike Flip Time and Extend Cook Time, Total
  Time does **not** need the `isLegacy` / `legacyIndex` / `index` branch. It
  writes to `settings.setTotalTime(_:for: timer.id)` for every timer, built-in
  or additional, because the storage is one dictionary keyed by timer id.
  Getter: `settings.totalTime(for: timer.id) ?? 0`.
- **Add-timer sheet:** the timer does not exist yet, so there is no id to key
  on. Hold the value in local `@State` alongside `tempPreset1` / `tempPreset2`,
  and write it with `settings.setTotalTime(_:for:)` **immediately after** the
  new `BBQTimer` is appended, using that new timer's id. Write nothing when the
  value is `0`.

### Copy

Footer under the section:

*"Optional. Alerts you once when the total cook time is reached. The timer
keeps running so you can carry on cooking."*

---

## Verification

- Unit tests above, all green.
- Simulator, iOS 26.5: a timer with no Total Time is pixel-unchanged; one with
  a target shows `/ 12:00`; past the target shows `+1:20`; check both the
  notched large card and the compact card.
- Set Total Time to 1 minute, start, background the app, confirm the
  notification fires with the phone locked and reads "… is done."
- Confirm the flip timer keeps counting and can still be restarted from a
  preset after the Total Time alert has fired.
- Confirm Reset clears the target's armed state — starting again re-arms and
  the alert can fire a second time.
- Confirm a target set *below* current Lit does not fire an instant alert.

## Out of scope (log, do not build)

- Watch display and watch alert for Total Time.
- A second ring or progress bar for the total.
- Auto-stopping or auto-resetting when the total is reached.
- Per-cook Total Time set from the card (it lives in Settings, like Flip Time).
  Revisit only if users report changing it every cook.
