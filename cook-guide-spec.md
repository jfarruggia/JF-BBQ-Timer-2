# Spec: Cook Guide — "what do I set?" (2.1)

**Decision (2026-09-20).** Top customer request. From the 26 Aug 2026 support
email: the app is "just a timer" and "pretty useless unless you know the
correct settings." A competitor gives target temperatures and times by cut and
thickness. Jim chose to **ship V2 first** and build this as **2.1**.

**Problem:** the app answers *when*. It never answers *what to set*. A new
griller opens it, sees "Flip Time 5:00", and has no idea if that is right for
a 1½" ribeye.

**Goal:** a Cook Guide that says, for a given food / cut / thickness / doneness:
pull temp, final temp, flip time, total time — and a **one-tap "Use these
settings"** that fills a timer with them. The three slots already exist
(Flip Time = `preset1`, Total Time, probe target). The guide only fills them.

**Not this build:** no recipes, no sauces, no step-by-step method, no photos,
no server, no user-submitted entries, no watch UI, no smoker-style multi-stage
cooks (wrap at 165, pull at 203). Those can follow once the lookup exists.

## Decisions already made (do not re-open)

| | |
|---|---|
| Name shown to users | **Cook Guide** |
| Price | **Free.** It is the reason to open the app. Premium stays Watch / probe / more timers / sounds. The guide makes the probe worth buying, which sells Premium |
| Where it lives | A **"Guide" chip** in the header next to "Probe", and a **"Cook Guide…"** row on each timer's edit screen (Settings ▸ Manage Timers ▸ that timer) |
| Data source | A **bundled JSON file** in the app. Pure, unit-tested lookups. No network. A number can be fixed without touching a view |
| Safety floor | **USDA safe minimum internal temperatures** are the floor for every entry. The guide never shows a *final* temp below the USDA minimum for that food. Beef/lamb "rare" is shown with an explicit "below USDA minimum" note, not hidden |
| Two temperatures, always | **Pull** (take it off) and **Final** (after rest). Carryover is real; showing one number gets people to overcook or undercook |
| Units | Follow the existing probe setting (`TemperatureUnit`, Fahrenheit default). Data is stored in °C like `ProbeTargetPreset.celsius`; display converts |
| Times are guidance | Every time is a range, shown as a range ("4–5 min per side"). The value written into the timer is the **low end** — an early flip alert is safer than a late one |
| Apply writes, never runs | "Use these settings" fills the timer's name, Flip Time, Total Time and probe target. It does **not** start the timer |
| Overwrite is explicit | If the timer already has a custom name or a Total Time, the apply sheet says what will change. One confirm. No silent overwrite |
| Disclaimer | One line at the bottom of the guide: "Times are a starting point. Always check doneness with a thermometer." Not a modal, not repeated |

---

## The data

One file: `JF BBQ Timer/CookGuide.json`, bundled in the iOS target (**Jim adds
it in Xcode** — file-system-synchronized group, so dropping it in the folder is
enough; verify it shows under the target's resources).

```json
{
  "version": 1,
  "foods": [
    {
      "id": "beef-steak",
      "name": "Steak",
      "category": "Beef",
      "method": "Direct, high heat",
      "usdaMinimumC": 62.8,
      "thicknesses": [
        { "id": "1in",  "label": "1\" (2.5 cm)" },
        { "id": "1.5in","label": "1½\" (4 cm)" },
        { "id": "2in",  "label": "2\" (5 cm)" }
      ],
      "doneness": [
        {
          "id": "rare", "name": "Rare",
          "pullC": 48.9, "finalC": 51.7,
          "belowUsdaMinimum": true,
          "times": {
            "1in":   { "perSideMinSec": 150, "perSideMaxSec": 180, "flips": 1 },
            "1.5in": { "perSideMinSec": 240, "perSideMaxSec": 300, "flips": 1 },
            "2in":   { "perSideMinSec": 330, "perSideMaxSec": 420, "flips": 1 }
          }
        }
      ]
    }
  ]
}
```

Rules the decoder enforces (unit-tested):

- `pullC < finalC`, both inside `ProbeTargetPresets.validCelsiusRange`.
- `finalC >= usdaMinimumC` **unless** `belowUsdaMinimum == true`. Missing flag
  with a low temp is a decode error, so a data mistake cannot ship silently.
- `perSideMinSec <= perSideMaxSec`, both > 0.
- Every `thicknesses.id` referenced in `times` exists, and every thickness has
  a `times` entry for every doneness (no holes — the UI never shows "—").
- Foods without a thickness axis (burgers, sausages, whole chicken) use one
  thickness entry with `label` = "" and the picker step is skipped.
- Foods without a doneness axis (chicken, pork, fish) use one doneness entry
  named "Done" (`finalC` = USDA minimum or the customary target).

**Derived numbers** (pure functions in `CookGuide.swift`, `#if os(iOS)` not
needed — it is plain Swift, so it can compile into the watch target later):

| Slot | Formula |
|---|---|
| Flip Time (`preset1`) | `perSideMinSec` |
| Extend (`preset2`) | unchanged — the user's quick-add stays theirs |
| Total Time | `perSideMinSec × (flips + 1)` |
| Probe target | `pullC` |
| Timer name | the food name, or "Steak · Med-rare" when there is a doneness axis |

### Starter data — Jim reviews every number before it ships

Jim is the grill expert; Claude is not. This table is a **starting point** in
°F for review. Final values go in the JSON in °C. USDA minimums: whole cuts of
beef / pork / lamb 145 °F + 3 min rest; ground meat 160 °F; poultry 165 °F;
fish 145 °F.

| Food | Doneness | Pull | Final | 1" per side | 1½" per side | Flips | Notes |
|---|---|---|---|---|---|---|---|
| Steak (beef) | Rare | 120 | 125 | 2½–3 | 4–5 | 1 | below USDA |
| | Medium-rare | 130 | 135 | 3–4 | 5–6 | 1 | below USDA |
| | Medium | 140 | 145 | 4–5 | 6–7 | 1 | meets USDA |
| | Medium-well | 150 | 155 | 5–6 | 7–8 | 1 | |
| | Well | 160 | 165 | 6–7 | 8–10 | 1 | |
| Burgers (ground beef) | Done | 155 | 160 | 4–5 | — | 1 | USDA 160, no rare option |
| Chicken breast, boneless | Done | 160 | 165 | 6–8 | — | 1 | USDA 165 |
| Chicken thighs, bone-in | Done | 170 | 175 | 10–12 | — | 1 | indirect heat, customary 175 |
| Pork chops | Done | 140 | 145 | 4–6 | 6–8 | 1 | USDA 145 |
| Pork tenderloin | Done | 140 | 145 | 5–6 | — | 3 | turn a quarter each time |
| Salmon fillet | Done | 125–130 | 135–145 | 4–6 | — | 1 | USDA 145; many cook to 130 — show as below USDA |
| Shrimp | Done | — | 120 | 2–3 | — | 1 | no probe target |
| Hot dogs / sausages | Done | — | 160 | 2–3 | — | 3 | |
| Veggies (asparagus, corn, peppers) | Done | — | — | 3–5 | — | 1 | time only |

Open for Jim: heat level per food (high / medium / indirect) — shown as one
line in the guide, not used by the timer. Add lamb chops? Ribs and brisket are
**out** for 2.1 (multi-stage; a flip timer is the wrong tool).

---

## The screens

### 1. Guide chip (header) → Cook Guide list

A "Guide" chip beside "Probe" (same `GlassActionButtonStyle .secondary` chip,
book icon). Opens a sheet:

- A grouped list by category: Beef, Poultry, Pork, Seafood, Veggies.
- Each row: food name + method line ("Direct, high heat"). Tap → detail.
- Search field at the top (iOS 16 `.searchable`).
- Footer: the one-line disclaimer.
- Styled with `.immersiveGlassList()` like Settings.

### 2. Food detail

- Segmented pickers, only the axes that exist: **Thickness**, **Doneness**.
- A result card (`.grillGlassPane`):
  - **Pull** `130 °F` · **Final** `135 °F` (unit from settings)
  - "Below USDA minimum (145 °F)" in a small amber line when flagged.
  - **Flip after** `3–4 min` · **Total** `6–8 min` · `1 flip`
- Primary button: **Use these settings** (`GlassActionButtonStyle .primary`).
- Secondary text link: **Set a probe target only** (Premium — opens the paywall
  when locked, same as the Probe chip).

### 3. Apply sheet

Tap "Use these settings" →
- If exactly one timer is idle: apply to it, then a short confirmation toast
  ("Set Timer 1 to Steak · Med-rare — Flip 3:00, Total 6:00, Pull 130 °F").
- Otherwise a picker of timers (name, current Flip Time, running state).
  Running timers are listed but disabled ("running").
- If the chosen timer already has a custom name or Total Time, one line:
  "This replaces the name and Total Time on Ribeye." Confirm / Cancel.
- Apply = `Settings.renameTimer`, `updateTimer(preset1:)`, `setTotalTime`,
  and `setProbeTarget` (probe target only when Premium; otherwise skipped
  silently — the free user still gets the times).
- Dismiss the guide; land on the main screen with that card visible.

### 4. Timer edit screen → "Cook Guide…" row

Settings ▸ Manage Timers ▸ timer: a row **Cook Guide…** under Total Time.
Opens the same list; apply targets *that* timer with no picker.

### 5. On the card (only when a probe is attached)

The probe strip already shows the target. Add nothing new for 2.1.

---

## Storage

Nothing new persists except what the apply writes into existing fields.
No per-timer memory of "which guide entry" — deliberately. The user may tweak
the numbers afterwards and the guide must not fight them.

`CookGuide.json` `version` is checked on load; an unknown version falls back to
"guide unavailable" rather than crashing.

---

## Unit tests (Swift Testing, `JF BBQ TimerTests`)

- `CookGuideDecodingTests` — the bundled file decodes; every invariant above
  holds for every entry (this is the test that catches a bad number).
- `CookGuideDerivationTests` — Flip / Total / target / name from a fixture
  entry, incl. the 3-flip tenderloin case (`Total = min × 4`).
- `CookGuideUnitTests` — °C → displayed °F rounding matches the probe sheet
  (reuse whatever it uses; do not write a second converter).
- `CookGuideApplyTests` — apply to a timer with existing name/Total Time
  yields the "will replace" prompt; apply to a bare timer does not. Free vs
  Premium: probe target written only when Premium.

---

## Out of scope / later

- Watch: show "Pull at 130 °" on the timer page. (Wire type change → lives in
  `WCSessionManager.swift`.)
- Multi-stage cooks (ribs, brisket, pulled pork) with wrap/pull temps.
- "Remember my last pick per food."
- Localized cuts (UK/AU names) — the label strings are in the JSON, so this is
  data work when it comes.

---

## Order of work

1. JSON + decoder + invariant tests (no UI). Jim reviews the data table above
   first and returns corrected numbers.
2. Derivation + apply logic + tests.
3. Guide list + detail screens.
4. Apply sheet + the two entry points.
5. Simulator pass on iOS 27 (glass) and an iOS 18 device (fallback).
6. Store text: one What's New line and a screenshot of the guide.
