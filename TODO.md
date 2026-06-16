# TODO — Grill Time Pro

Working backlog. Claude Code reads and updates this; Jim edits freely. Check
items off (`- [x]`) as they land. Git history is the source of truth for what
actually shipped — this file is just the running plan.

## Up next
- [ ] **Ember-glow background** behind the glass cards — deep warm base with soft
      orange/red radial glow pools (gated to iOS 26). Direction already chosen
      from the 3 mockups. When it's in, dial `Color.grillGlassTint` back down so
      the background shows through the glass.

## Verify on device
- [ ] Does **compact mode persist** across a cold relaunch? The Settings toggle
      binds straight to the published property; no save-on-change was spotted, so
      it may reset to large each launch.
- [ ] **Watch long-preset formatting:** the watch `format(seconds:)` shows e.g.
      `90:00` instead of `1:30:00` for hour-plus presets (iPhone already handles
      this via `timeLabel`).

## Someday / maybe
- [ ] Let the watch schedule its own local notification at `endDate` so completion
      alerts fire even when the watch app is asleep (would let it lean less on the
      extended-runtime keep-alive). Carefully verify — touches the working alert path.

## Recently shipped (2026-06-14)
- [x] Large timer card Liquid Glass redesign (`f9b4117`)
- [x] Compact card redesign + countdown progress ring (`3486613`)
- [x] CLAUDE.md architecture facts filled in (`a1c975e`)
- [x] Trimmed the stale "‹TODO›" note at the top of CLAUDE.md
