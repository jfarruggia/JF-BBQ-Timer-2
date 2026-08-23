# Spec: Preset target also renames the timer

**Goal:** When the user picks a **Common target** preset (e.g. "Chicken") in the
probe target sheet, the timer that cook belongs to is renamed to the preset's
name. The card, alerts, voice announcements, and the watch then all say
"Chicken" — no more mismatch between a stale timer name and the food actually
cooking.

## Rules

1. **Only preset taps rename.** Typing a custom temperature never renames.
   "Clear target" never renames. Editing a preset in the editor never renames.
2. **Tell the user in the sheet.** The "Common targets" section footer reads:
   *"Choosing a common target also renames this timer to match."*
   No extra confirmation step (Jim's "option 1").
3. **Same name → no-op.** If the timer is already named that, nothing changes
   (no save, no sync churn).
4. **Works for all timers.** The first two timers are legacy
   (`timer1Name` / `timer2Name` in Settings); the rest live in
   `additionalTimers`. A new `Settings.renameTimer(id:to:)` helper resolves the
   id to whichever storage owns it. Unknown id → no-op.
5. **Watch needs no changes.** Timer names already ride in the phone→watch
   snapshot; the rename flows through the existing sync.

## Implementation

- `ProbeTargetSheet`: `onSave` gains the preset name —
  `onSave: (Double?, String?) -> Void`. Custom entry and Clear pass `nil` for
  the name; a preset row passes `preset.name`. Add the footer text (rule 2).
- `ContentView` (sheet presentation, ~line 901): set the target as today; when
  a preset name arrives, call `settings.renameTimer(id: cook.id, to: name)`.
- `Settings.renameTimer(id:to:)`: legacy ids → `timer1Name`/`timer2Name`;
  otherwise find the index in `additionalTimers` and reuse
  `updateTimer(at:name:)`. Trim whitespace; ignore empty; no-op on same name.

## Tests

- Unit tests for `renameTimer`: renames legacy timer 1, legacy timer 2, an
  additional timer; unknown id is a no-op; same-name is a no-op (no dirty save).
- UI behavior (preset tap renames, custom entry doesn't) verified by Jim in
  the sim — the view wiring is thin.

## Out of scope

- No rename when attaching the probe, starting a timer, or from any other path.
- No undo UI — Manage All Timers already lets the user rename back.
