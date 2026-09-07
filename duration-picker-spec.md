# Spec: one duration picker — tap the number, spin a wheel

**Decision (2026-09-07).** Jim compared four ways of setting a cook duration on
a throwaway screen (`DurationEntryOptionsPreview`, built for this decision) and
picked **Option 2: tap the number, get a wheel.** "Simple and elegant."

**Problem:** every duration in Settings is a `+` / `−` stepper. Flip Time steps
30 seconds up to an hour — 120 taps to reach the top. The pain gets worse with
Total Time (`total-time-spec.md`), which reaches 6 hours.

**Goal:** one shared control, used by every duration field. Tap the value, spin
two wheels, Done. Any duration in three moves.

**Explicitly agreed:** the steppers are **removed**, not kept alongside. Option
2 as Jim chose it has no `+` / `−`. One way to set a time, everywhere.

> This is a live-app behaviour change: Flip Time and Extend Cook Time ship
> today with steppers and existing users will find them gone. Jim was told and
> chose it anyway — the wheel handles a one-minute nudge fine.

**Ships before `total-time-spec.md`.** Total Time then adopts this control
rather than adding a fifth stepper. One concern per PR.

---

## The control

New file `JF BBQ Timer/DurationPicker.swift`.

```swift
/// Which two wheels a field shows. Every duration in the app is either
/// "under an hour, seconds matter" or "hours long, seconds do not".
enum DurationPickerStyle {
    case minutesSeconds   // 0…59 min + 0…59 sec, second wheel steps by 5 s
    case hoursMinutes     // 0…6 hr  + 0…59 min
}

/// A tappable duration row: label on the left, the value on the right in the
/// accent colour with a chevron, opening a wheel sheet.
struct DurationRow: View {
    let label: String
    let style: DurationPickerStyle
    @Binding var seconds: Int
    /// Called after Done commits a new value. Used for `settings.save()`.
    var onCommit: () -> Void = {}
}
```

### The row

```
Flip Time                      05:00  ›
```

- Label left, `Spacer()`, value right.
- Value in `Color("TimerAccent")` with a trailing `chevron.right`
  (`.caption`, same colour). **Accent means tappable in this app** — that rule
  is why this reads as a control without extra chrome. It also means the value
  must never be accent when it is not tappable.
- Whole row is the tap target (`.contentShape(Rectangle())`), not just the text.
- Formatting: `TimeFormatter.compactTimeString` for `.minutesSeconds` (gives
  `MM:SS`), `TimeFormatter.timeString` for `.hoursMinutes` (gives `HH:mm:ss`).
  Both already exist in `TimeFormatting.swift`; do not add a third formatter.

### The sheet

Adapt `DurationWheelSheet` from `DurationEntryOptionsPreview.swift` — it is
already the right shape; it just needs the style switch and a title.

- Header row: `Cancel` (discards) · title (the field's label) · `Done`
  (commits, `.semibold`).
- Two `.wheel` pickers side by side with `.caption` captions underneath:
  - `.minutesSeconds` → `min` `0..<60`, `sec` `0, 5, 10 … 55`.
    **Seconds step by 5.** A 60-item second wheel is a lot of spinning for a
    value nobody sets to 37.
  - `.hoursMinutes` → `hr` `0..<7`, `min` `0..<60`.
- Edits a scratch value seeded in `.onAppear` from `seconds`. **Cancel must not
  write.** Done writes `seconds` then calls `onCommit()`.
- `.presentationDetents([.height(320)])`.
- Sheet content gets `.immersiveGlassBackground()` (`ButtonStyles.swift`) so it
  matches the Settings stack on iOS 26. Already gated internally; no-op below.

### Rounding

If an existing stored value does not sit on a wheel stop (e.g. 37 seconds from
some earlier state), the sheet seeds to the **nearest** valid stop. It must not
silently rewrite the stored value on open — only Done writes.

---

## Where it is used

Four sites, all in `JF BBQ Timer/SettingsViews.swift`. Each stepper is replaced
outright — delete the `Stepper`, keep the surrounding `HStack`/padding so the
rows keep their spacing.

| # | Field | Line (approx) | Binding | Style |
|---|---|---|---|---|
| 1 | Preheat Duration | ~149 | `$settings.preheatDuration` | `.minutesSeconds` |
| 2 | Flip Time | ~743 | `timer.preset1` via the legacy/additional branch | `.minutesSeconds` |
| 3 | Extend Cook Time | ~772 | `timer.preset2` via the same branch | `.minutesSeconds` |
| 4 | Add-timer sheet | ~836, ~849 | `$tempPreset1`, `$tempPreset2` | `.minutesSeconds` |

Notes per site:

- **Preheat Duration** keeps its existing "Reset to Default" button below the
  row, unchanged.
- **Flip Time / Extend Cook Time** in the edit-existing-timer form use a
  `Binding` whose setter branches on `isLegacy` / `legacyIndex` / `index` and
  then calls `settings.save()`. Keep that setter exactly as it is and hand it
  to `DurationRow` as the binding; pass the `settings.save()` call as
  `onCommit` **or** leave it in the setter, whichever avoids saving twice — do
  not do both.
- **Add-timer sheet** writes to local `@State` and saves on the sheet's own
  Done, so `onCommit` is not needed there.

Ranges stay as they are (`0...3600` for all four). The wheels enforce this
naturally: `.minutesSeconds` maxes at `59:55`, close enough to today's `60:00`
cap that no clamp is needed — but clamp on commit anyway, cheaply, so a future
style change cannot write an out-of-range value.

---

## Pure logic (unit-tested — house rule for time math)

In `DurationPicker.swift`:

```swift
enum DurationPickerMath {
    /// Split seconds into the two wheel values for a style, snapping to the
    /// nearest valid stop (seconds round to the nearest 5).
    static func components(seconds: Int, style: DurationPickerStyle) -> (Int, Int)

    /// Recombine two wheel values back into seconds, clamped to 0...max.
    static func seconds(from components: (Int, Int), style: DurationPickerStyle) -> Int
}
```

Tests (`JF BBQ TimerTests/DurationPickerMathTests.swift`, Swift Testing):

- `.minutesSeconds`: `300 → (5, 0)`; `330 → (5, 30)`; `0 → (0, 0)`;
  `3600 → (59, 55)` (clamped, the wheel cannot express 60:00);
  `37 → (0, 35)` and `38 → (0, 40)` (nearest-5 rounding, both directions).
- `.hoursMinutes`: `720 → (0, 12)`; `3600 → (1, 0)`; `21600 → (6, 0)`;
  `90 → (0, 2)` (rounds to nearest minute, not truncating to 1).
- Round trip: `seconds(from: components(s)) == s` for every value already on a
  valid stop, both styles.
- Negative input clamps to `(0, 0)`.
- Recombine clamps above the style's maximum.

---

## Cleanup, in the same PR

- **Delete `JF BBQ Timer/DurationEntryOptionsPreview.swift`** and the
  `NavigationLink("Duration Entry Options")` line added to the Debug section.
  It was built only to make this decision and says so at the top of the file.
- **Delete `TimerPresetStylesPreview`** and its helper `TimeTextField` from
  `SettingsViews.swift` (~lines 1020–1165). It is an older five-option
  exploration of this same question, is referenced nowhere, and this spec
  settles the question it was asking.

---

## Verification

- Unit tests above, green.
- Simulator, iOS 26.5: open Settings and confirm all four rows show the accent
  value + chevron, the sheet opens, Cancel discards, Done commits.
- Confirm the committed value **persists** — reopen Settings and, for Flip
  Time, confirm the timer card's preset button shows the new value.
- Confirm the legacy branch works for **both** built-in timers and for an
  additional timer (three separate storage paths behind one binding).
- Confirm Preheat's "Reset to Default" still returns it to 10:00.
- Check the pre-26 fallback still renders (the app targets iOS 16.6): boot an
  iOS 18 simulator and confirm the rows and sheet are usable without glass.

## Out of scope

- Quick chips (`5m 15m 30m 1h`). They tested well and are worth revisiting
  after launch, but Jim chose the wheel alone for its simplicity.
- Typing a duration on a keypad.
- Any change to the timer cards. This is Settings only.
