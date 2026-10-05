# Spec: Probe "Out of range" state

Status: **approved by Jim** (2026-10-04)

## Problem

When the phone loses the probe's Bluetooth signal (too far away, metal grill
lid, walls), the temperature on the phone card and the watch goes **blank**.
The user cannot tell why. They also lose the last temperature they saw.

Today's code: `ProbeBLEManager.handleDisconnected` sets `latestReading = nil`
and enters `.reconnecting`. The card strip then shows "—". On the watch, the
timer-page temp line hides and the probe page is removed (both need
`connected == true`).

Auto-reconnect already works. **This spec changes only what the user sees.**

## Goal

While the probe is out of range, show:

- that the signal is lost: **"Out of range"**
- the **last temperature** we got, dimmed
- **how old** it is: "just now" / "3 min ago" / "1 h 5 min ago"

When the signal comes back, live readings replace it at once. The label goes
away.

## Definitions

- **Out of range** = connection state is `.reconnecting` (the user did not
  choose to disconnect) **and** we have a last-known reading for this session.
- **User disconnect** (the Disconnect button, or picking another probe) is
  **not** out of range. It clears everything, as today.

## Behaviour rules

1. `latestReading` is still cleared on disconnect. Alerts, the cook-phase
   engine, and the target latch keep working only from live data. **No
   change to alert logic.**
2. New in `ProbeBLEManager`: `lastKnownReading: ProbeReading?` and
   `lastReadingAt: Date?`. Both are set on every valid status notification.
   Kept on an unexpected disconnect. Cleared on user disconnect, on a new
   probe, and when the app starts fresh. (Do not persist them to disk.)
3. While out of range, show **core temp only** (dimmed). Hide the surface
   temp, the ambient temp, and the predicted-ready countdown. Old predictions
   would mislead.
4. The target arrow ("→ 96°") stays. It is the user's setting, not probe data.
5. The age updates live (at least once a minute). It counts from
   `lastReadingAt`, an absolute date — not a counter. The watch must stay
   right after it wakes from sleep.
6. No time limit. "Out of range" stays until the probe comes back or the
   user disconnects.

## Age text — pure, unit-tested

New pure function (in `WCSessionManager.swift`, so both targets compile it):

```
probeReadingAgeText(lastReadingAt: Date, now: Date) -> String
```

| Age            | Text            |
|----------------|-----------------|
| < 60 s         | "just now"      |
| 1–59 min       | "N min ago"     |
| ≥ 60 min       | "N h M min ago" (drop "M min" when 0) |
| negative (clock skew) | "just now" |

Tests use an injected `now`. Cover each row plus the edges (59 s, 60 s,
59 min 59 s, 60 min, 65 min).

## Phone — card probe strip

`ContentView.probeInfo(for:)` + `CardProbeInfo` (`TimerViews.swift`):

- Add `CardProbeInfo.outOfRangeAgeText: String?`. Non-nil = out of range.
- Out of range: `coreText` = the last known core temp. The strip draws it at
  reduced opacity. Surface, ambient, and the ready slot (label + countdown)
  are hidden.
- **Second line (approved by Jim 2026-10-04):** the one-row strip has no room
  for the full text (~150–175 pt needed, ~150 pt free on a large card on an
  iPhone 16, less on compact/smaller phones). So while out of range, add a
  small line **under** the strip row:
  **"Out of range · last reading 3 min ago"**, leading-aligned, secondary
  color, same small font size as that strip's "ready" caption, with an
  `antenna.radiowaves.left.and.right.slash` icon in front. `lineLimit(1)` +
  `minimumScaleFactor` so it never wraps. The line exists only while out of
  range; the card grows a little and returns to normal when the signal
  comes back.
- Applies to all three strips (glass large, glass compact, pre-26). The
  existing row layout is unchanged. No new glass.
- Reconnecting with **no** last reading (e.g. right after a relaunch): no
  change from today ("—").

## Watch

Wire (additive, older builds ignore new keys) — add to
`probeReadingWireDict` and `WatchProbeReading`:

- `outOfRange: Bool` (default false)
- `lastCoreC: Double?`
- `lastReadingEpoch: Double?` (seconds since 1970)

The watch works out the age itself from `lastReadingEpoch` with
`probeReadingAgeText`. The phone does not send the age text.

The forwarder sends at once when `outOfRange` changes. While out of range
it does not need to resend (nothing changes on the phone side).

**Timer page** (name + temp line under the ring): when out of range and the
probe is attached to this cook, show the last core temp dimmed + a small
`antenna.radiowaves.left.and.right.slash` icon. No age text here (no room).

**Probe page**: stays in the pager while out of range (today it is removed).
Hero = last core temp, dimmed. Status line = "Out of range · 3 min ago".
Surface, ambient, and countdown are hidden.

## Out of scope

- An alert or haptic when the signal is lost. (Possible later.)
- Extending range or Booster/Display support.
- Header "Probe" chip changes.

## Done when

- Unit tests for `probeReadingAgeText` and the wire encode/decode of the new
  keys pass.
- Simulator check of the card strip in all three states: live, out of range,
  reconnecting with no reading. Check the second line fits without cutting
  off on the large and compact cards, with "1 h 5 min ago" (the longest
  text), on an iPhone 17 iOS 26.5 sim and on the smallest installed iPhone. (Use a debug-only way to force the state;
  remove it or keep it `#if DEBUG`.)
- iOS + watch builds pass.
- Jim checks on real devices: walk away until it drops, check phone + watch,
  walk back, check live temps return.
