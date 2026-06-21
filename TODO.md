# TODO — Grill Time Pro

Working backlog. Claude Code reads and updates this; Jim edits freely. Check
items off (`- [x]`) as they land. Git history is the source of truth for what
actually shipped — this file is just the running plan.

## Working V2 order (adjustable)
All items below are **Version 2**. Planned sequence:
1. DEBUG-only free⇄paid toggle (unblocks premium testing)
2. **Combustion probe** — the headliner / only user-requested feature
3. Main-screen layout pass — beefier header + reposition preheat + **ember-glow
   background** + slot in the probe's temp/prediction display, as one redesign
   (done after the probe so the screen is laid out once)
4. Design-consistency sweep (Settings, paywall, alerts, custom sounds, watch UI)
5. Onboarding review
6. Reconcile branch → ship (App Store)

Isolated quick wins (voice announcements, preheat→`endDate`, the two bugs) slot in anytime.

## Up next
- [ ] **Combustion Bluetooth probe** (details under Features) — V2 step 2, the headliner.

_Ember-glow note (lands in step 3):_ deep warm base + soft orange/red radial
pools, iOS 26-gated; when it's in, dial `Color.grillGlassTint` back down so the
background shows through the glass.

## Features
- **Combustion Bluetooth probe support** — see `combustion-probe-ble-spec.md`.
  Decision made: **raw CoreBluetooth + our own parser** (not the SDK; SDK is dormant
  since 2023 + drags in a DFU lib). Phased:
  - [x] **2A — domain models + Probe Status decoders + unit tests** (`9f7bc42`). Pure
        Swift, 49 tests, bit layouts transcribed from combustion-ios-ble.
  - [~] **2B — CoreBluetooth central (foreground):** code complete (`f853f87`) —
        `ProbeBLEManager` (scan/connect/notify/decode, 16 tests via fake central),
        thin real `CoreBluetoothProbeCentral`, minimal `ProbePickerView` behind a
        DEBUG Settings entry. Info.plist/capability config done (`b2236e7`):
        usage string + `bluetooth-central` on iOS target; watch declares no BT.
        DEBUG hex-logging of raw payloads added (`116f59f`). **Still pending:**
        on-device verification with the physical probe + capture real payloads
        as test fixtures to pin against the 2A decoder.
  - [ ] **2C — forward compact reading to watch** over existing `WCSession`; render core
        temp + drifting predicted-ready countdown on phone + watch.
  - [ ] **2D — background state restoration + reconnection** for long cooks.
  - [ ] **2E — on-screen probe UI** (folds into the main-screen layout pass, step 3).
  - [ ] **2F (later) — UART commands** (alarms, set-prediction): separate spec, out of scope.
- [x] **Dev-only free⇄paid toggle** for testing premium gating — shipped `4ec2ca8`.
      `#if DEBUG`-only "Debug" section at the bottom of Settings: "Override Premium"
      switch + Free/Paid segmented picker. Overrides `isPremiumUser` locally; both
      RevenueCat sync points back off while it's on; turning it off re-syncs the real
      entitlement. Release build verified to strip it. Never calls purchase/restore.

## UX / layout
- [ ] **Reposition the Preheat grill button** — bottom placement is easy to miss.
- [ ] **Beef up the "GrillTime Pro" header** (title + gear) — make it more substantial.
- [ ] **Detailed onboarding review** — simplify the flow and improve the look
      (`CarouselOnboardingView` / `OnboardingView`).

## Audio
- [ ] **Voice announcements sound bad** — investigate + improve quality
      (`AnnouncementRepeater` / voice settings in `SettingsExtension.swift`).

## Design consistency (extend the glass language to the rest of the app)
- [ ] Settings, paywall/premium (`CustomPaywallView` / `PremiumUpgradeView`),
      custom sounds (`CustomSoundsView`) screens.
- [ ] Completion alert overlays (`AlertView` / `PreheatAlertView`).
- [ ] Watch app UI refresh (only the iPhone has been redesigned).

## Mechanics / consistency
- [ ] **Preheat timer → `endDate` model** — currently a decrement counter
      (`preheatTimeRemaining -= 1`), which can drift; align it with the main timers.
- [ ] Watch schedules its own local notification at `endDate` so alerts fire even
      when the watch app is asleep (lets it lean less on the extended-runtime
      keep-alive). Carefully verify — touches the working alert path.

## Bugs / verify on device
- [ ] Does **compact mode persist** across a cold relaunch? The Settings toggle
      binds straight to the published property; no save-on-change was spotted.
- [ ] **Watch long-preset formatting:** watch `format(seconds:)` shows e.g. `90:00`
      instead of `1:30:00` (iPhone already handles this via `timeLabel`).

## Parked
- [x] **Cloud sync — parked** (no user demand, low value for a single-device grill
      timer, high cost). Revisit only if users ask; if so, prefer lightweight
      iCloud Key-Value preset sync over full CloudKit live-sync.

## Release / process
- [x] **Absorb `main` → `Apple-Watch-Suport`** (2026-06-17, merge `1009263`,
      build-verified + pushed). Brought in main's app-icon restructure; our `1.3.0`
      kept over main's `1.2.2`. Xcode 26.5's merge dialog bugged out, so finished via
      terminal whole-file `--ours/--theirs` (see branch-reconciliation memory).
- [ ] **Final ship merge `Apple-Watch-Suport` → `main`** once V2 is done — then tag +
      release. (Optional pre-merge tidy: drop now-unreferenced `Icon-60@2x/3x.png`.)
- [ ] App Store submission once the watch features are ready.

## Recently shipped (2026-06-14)
- [x] Large timer card Liquid Glass redesign (`f9b4117`)
- [x] Compact card redesign + countdown progress ring (`3486613`)
- [x] CLAUDE.md architecture facts filled in (`a1c975e`)
- [x] Trimmed the stale "‹TODO›" note at the top of CLAUDE.md
- [x] Added this TODO.md backlog + CLAUDE.md pointer (`65f735f`)
