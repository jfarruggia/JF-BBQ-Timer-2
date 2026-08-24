# Spec: Distinct in-app probe alert (green temp card)

**Problem:** probe cook moments only fire a system notification banner — visually
identical to the timer alerts. Jim wants the probe alert unmistakable.

**Design (approved 2026-08-23):** a full-screen in-app overlay in the app's
glass language, mirroring the timer's red pulsing card but **green** — green
reads "food is ready" and is the visual opposite of the timer red.

## When it shows

- Probe cook events **pullNow**, **targetReached**, **restingDone** — the
  "act now" moments — while the app is in the foreground.
- **batteryLow / overheating do NOT get the overlay** (they stay quiet
  notification banners; they're warnings, not "drop everything").
- The existing local-notification + haptic path is **unchanged** (still fires
  for every event — it remains the lock-screen/background record).

## Card content (top to bottom)

1. Thermometer SF symbol (`thermometer.high`), bold, white.
2. The attached cook's name, if known (e.g. "Chicken") — omit the line if not.
3. The probe's current core temp, huge (e.g. "135°F") — formatted in the
   user's `settings.temperatureUnit`; if no reading is available, show the
   event title alone (never "nil" or "—").
4. Event line: pullNow → "Pull the food now" · targetReached → "Target
   temperature reached" · restingDone → "Food is ready".

Content mapping lives in a small **pure builder** (event + optional temp text +
optional cook name → title/lines), unit-tested. No new files — builder + view
go in `AlertViews.swift`, tests in an existing probe test file.

## Style

- Mirror `AlertGlassCardStyle` exactly but green: iOS 26 `.glassEffect(.clear
  .tint(green 0.45))`, pulsing green stroke + green glow shadow, same 240pt-ish
  card, same pulse cadence. Pre-26 fallback: solid green card (like the red one).
- Tap anywhere dismisses (same interaction as the timer alert). No new sound.

## Wiring

- New lightweight presented-state in `ContentView` (event + captured temp/name
  at fire time), set inside `handleProbeCookEvent` for the three events; the
  overlay renders in the same ZStack layer as the timer `AlertView`.
- If a second probe event fires while the card is up, replace the content.
- Timer alert and probe alert may theoretically coexist; timer alert wins
  (renders on top) — do not build coordination logic beyond z-order.

## Out of scope

- Watch changes, sounds, battery/overheat overlays, notification changes.
