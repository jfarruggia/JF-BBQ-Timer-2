# Watch Ring Layout — Spec

Approved by Jim 2026-08-08 after live prototype tuning (throwaway `WatchProto.swiftpm`
mock at exact watch dimensions). Brings the watch timer pages in line with the
phone's visual identity: countdown ring as hero, warm ember styling, orange accent.

## Scope

- Watch app **UI only** (per-timer page in the watch `ContentView.swift`).
- **No sync restructuring.** One additive change to the phone snapshot: each timer
  row gains `"runDuration"` (seconds, from `TimerState.runDuration`) so the watch
  can compute ring fill. Additive key only — existing keys and flow untouched.
- Complications, alerts, phase lines ("Pull now!", "Ready to serve"), commands:
  unchanged.

## Layout (per timer page, tuned on 42mm — scales to 46mm)

Top-to-bottom, vertically centered as a group (leftover space splits above ring /
below buttons; system clock owns the top-right — nothing else on that row):

1. **Ring** — 118pt outer diameter, 9pt line. Track white 14%, fill `TimerAccent`
   orange, round caps, starts at 12 o'clock. Inside: "Flip in" (11pt, 60% white),
   countdown (32pt rounded semibold, monospaced digits), "Lit m:ss" line (11pt,
   flame icon in accent).
2. **Name + probe line** — 2pt below ring: timer name (13pt rounded semibold,
   90% white) + thermometer icon + core temp (13pt, accent). Temp only when a
   probe is attached to this cook. Name truncates first; temp always wins.
3. **Preset buttons** — 3pt below the name line: side-by-side, 39pt tall,
   corner 11, 24pt side inset, 11pt minimum bottom clearance. Left = primary
   (solid `TimerAccent`, dark label, play icon, preset 1); right = secondary
   (white 18% fill + hairline stroke, white label, preset 2). Same actions as
   today's buttons (optimistic start + `applyPreset1/2` command).

## Correctness rules (watch gotchas)

- **Digits**: `Text(timerInterval:)` (system-managed) — stays live on Always-On
  Display while the app is suspended. Same fallback as today when not running.
- **Ring fill**: computed from absolute dates each tick — `progress =
  remaining(now) / runDuration` clamped to [0,1], remaining derived from
  `endDate` when running. Never a decremented counter. Ring may lag on AOD
  (can't redraw while suspended); catches up on wrist-raise. Accepted.
- Progress math is a **pure function with injectable now** (lives in
  `WCSessionManager.swift` so the iOS test target can unit-test it).
- `runDuration` missing (old phone app): fall back to `max(remaining, preset1)`
  so the ring still renders sensibly.

## Out of scope

- Notched buttons on watch (no room at 40–46mm; rejected in discussion).
- Complication redesign, watch alert screen, timers list styling.
