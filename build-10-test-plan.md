# Build 10 test plan — PRs #35–#43 (2026-08-08 session)

Everything merged to `Apple-Watch-Suport` since build 9. Test on iPhone
(TestFlight .dev app) + paired watch. Items marked 📱 phone, ⌚️ watch.

## Notched card layout (PR #35) 📱
- [ ] Cards show the big ring (200pt) with notched preset buttons interlocking it;
      two cards + preheat bar fit on one screen.
- [ ] Left orange button starts preset 1; ring counts down; **red Stop** appears
      beside Reset in the channel between the buttons.
- [ ] Stop freezes the countdown (Lit keeps counting); Reset re-centers and
      returns the card to idle.
- [ ] Tapping the **moat** (the clear gap between ring and a button's curved
      notch) does NOT press the button.
- [ ] Probe attached to a cook → temp strip still appears below the buttons.
- [ ] Compact Display Mode → old compact layout, unchanged.
- [ ] (TimerRed fix, same PR) The Stop control is clearly red — previously that
      color silently rendered invisible everywhere in the iOS app.

## Watch ring layout (PR #36) ⌚️
- [ ] Timer pages show the ring (Flip in + countdown + Lit inside), name below
      the ring, preset buttons at the bottom; system clock alone top-right.
- [ ] Start from a watch preset → ring starts full and depletes; digits tick.
- [ ] Start from the iPhone → watch page updates and auto-focuses that timer.
- [ ] Wrist down (Always-On): digits keep ticking while dimmed; ring catches up
      on wrist-raise (expected: ring may briefly lag — by design).
- [ ] Labels match the phone style: "5:00" (no leading zero), preset 2 shows
      "1:00" (no "+" prefix).
- [ ] Probe attached → core temp next to the name on the attached cook's page
      only; probe page + "Pull now!" phase lines unchanged.
- [ ] Buttons/name clear the rounded corners on your watch size.

## Free Featured sounds (PR #37) 📱
- [ ] Settings ▸ Debug ▸ Override Premium → **Free**. Then Alert Sounds:
      Dinner Triangle + Chimes show normal text + play buttons (no crowns),
      and tapping selects them (checkmark, no paywall).
- [ ] Premium Sounds section still locked with the upgrade row.
- [ ] Flip Debug back to **Paid** when done.

## Settings reorder (PR #38) 📱
- [ ] Settings order: Timers → Display & Accessibility (Compact Display Mode)
      → Alerts & Sounds.

## Preheat disabled state (PR #39) 📱
- [ ] Start any cook timer → Preheat bar visibly dims (whole pane) and taps on
      it do nothing.
- [ ] Stop/Reset the timer → bar returns to full brightness and works.

## Preheat haptic (PR #40) 📱
- [ ] With no timers running and Haptic Feedback on, tap Preheat → double
      heavy "thump-thump" haptic. (This was silently broken.)

## Real paywall from Probe chip (PR #41) 📱
- [ ] In Debug **Free** mode, tap the header Probe chip → the full "Unlock
      Grill Time Pro" paywall appears (feature list, Purchase Now, Restore
      Purchases) showing the real **$3.99** price — not the old $4.99 card.
- [ ] Do NOT purchase — "Skip for now" dismisses.
- [ ] Settings ▸ Manage All Timers (still Free): upgrade row also shows $3.99.

## Name-first announcements (PR #42) 📱
- [ ] Voice Announcement Settings: message field shows "timer is complete"
      (your old default was migrated automatically).
- [ ] Test Voice Announcement → "Ribeye timer is complete" (name first).
- [ ] Complete a real timer with voice on → says exactly the same phrase.
- [ ] Optional: put `{timer}` in a custom message and confirm the name lands
      where you placed it; Reset to Default Message restores "timer is complete".

## Voice replaces the alarm (PR #43) 📱
- [ ] Sound Alerts ON + Voice Announcements ON → complete a timer: you hear
      ONLY the spoken announcement (repeating until dismissed) — no alarm
      underneath it.
- [ ] Voice OFF → alarm sound alerts exactly as before.
- [ ] Lock the phone, let a timer complete → notification arrives with its
      sound (background path unchanged).

## Regression sweep (quick)
- [ ] Phone↔watch sync still solid: start/stop/reset from each side reflects
      on the other.
- [ ] Timer completion alert screen, haptics, and completion flash unchanged.
- [ ] Probe connect/stream + target sheet unchanged (if probe handy).
- [ ] Force-quit the app mid-countdown, relaunch → timer resumes correctly
      from absolute time. (I saw one unreproducible oddity here in a crashed
      simulator — worth one deliberate check on device.)
