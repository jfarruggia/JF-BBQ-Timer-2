# Notched-Button Large Card Layout — Spec

Approved by Jim 2026-08-08 after live prototype tuning (throwaway `NotchProto.swiftpm`
app, iPhone 17 Pro Max sim). Replaces the large glass card's stacked arrangement
(ring above two pill buttons) with an interlocking one: a bigger ring whose circle
carves concave notches out of two squarer preset buttons flanking it below.

## Scope

- **Only `GlassLargeTimerContent`** (the iOS 26 glass large card in `TimerViews.swift`).
- Compact layout: **untouched**.
- Pre-iOS 26 users: **untouched** — they already get the legacy stacked card via the
  existing `if #available(iOS 26, *)` gate in `ContentView.largeTimerView`. Since the
  glass card is 26-only, the iOS 17 `Path.subtracting` requirement is automatically
  satisfied; no new version gating is needed. (This is "Option A" from the discussion.)
- Watch app: untouched (no wire/protocol changes).

## Geometry (Jim's tuned values, in card-content coordinates)

Card content = card minus the existing 18pt horizontal / 16pt vertical padding.
All constants live in one pure layout struct so the notch always tracks the ring.

| Constant | Value |
|---|---|
| Ring outer diameter | 200 (was 155) |
| Ring center Y from content top | 125 |
| Moat (ring edge → button notch edge) | 12 |
| Button height | 124 |
| Center gap between buttons | 92 |
| Overlap (buttons' top above circle bottom) | 69 |
| Button corner radius | 16 |

Derived: circle bottom = 225; buttons top = 156; interlock region height = 280;
notch cut radius = 112; button width = (contentW − 92) / 2.

## Elements

- **Title** — unchanged, top-leading.
- **Ring** — existing `CircularTimerRing` + inner content ("Flip in", time, "Lit
  elapsed"), now 200pt, centered at (contentW/2, 125).
- **Preset buttons** — notched shapes (rounded rect minus the ring circle + moat,
  via `Path.subtracting`). Left = primary (solid `TimerAccent` fill, dark label,
  play icon — same actions as today's preset 1). Right = secondary (translucent
  white fill + hairline stroke, same as today's secondary pill styling — **not**
  glass, per the no-glass-on-glass rule). Labels bottom-centered, large rounded
  monospaced digits. Tap target clipped to the notched shape so taps in the moat
  don't press the button.
- **Stop / Reset** — move into the channel between the buttons, below the circle:
  Reset alone (centered) when idle; Stop (red) beside Reset when running. Identical
  actions to today's row.
- **Probe strip** — unchanged, divider + strip below the interlock region; card
  grows when a probe is attached.
- Completion flash / adaptive container behavior via `timerContainerAppearance`:
  unchanged.

## Out of scope / accepted

- No smooth fillets where the notch arc meets button edges (sharp junctions
  accepted from the prototype).
- Long `h:mm:ss` presets not optimized for (Jim: not a smoker app).
- On narrow devices (SE-class) buttons simply get proportionally narrower; the
  geometry derives from content width so nothing clips.
