# TODO — Grill Time Pro

Working backlog. Claude Code reads and updates this; Jim edits freely. Check
items off (`- [x]`) as they land. Git history is the source of truth for what
actually shipped — this file is just the running plan.

## Working V2 order (adjustable)
All items below are **Version 2**. Planned sequence:
1. [x] DEBUG-only free⇄paid toggle (`4ec2ca8`)
2. [x] **Combustion probe** — BLE foundation 2A–2D done + on-device connect/stream verified
3. [x] **Main-screen layout pass** — header + preheat + ember-glow + probe UI + glass redesign
4. [ ] Design-consistency sweep (Settings, paywall, alerts, custom sounds, watch UI)
5. [ ] Onboarding review
6. [ ] Reconcile branch → ship (App Store)

Isolated quick wins (voice announcements, preheat→`endDate`, the two bugs) slot in anytime.

## Main-screen layout + glass redesign — DONE & refined on device (2026-06-25/27)
Built as steps 1–6, then refined live with Jim from device screenshots. All on `Apple-Watch-Suport`:
- Steps: app-wide probe manager (`19bba7c`); probe↔cook attach + pick-on-connect (`129c71e`);
  probe strip on the cook card, large+compact (`ab87de0`); beefier header + connect button
  (`03a30e2`); fixed bottom Preheat bar (`69aad43`); ember-glow background (`8a0eee2`).
- **Cook card model:** probe attaches to a chosen cook (not a global readout); card shows
  three labeled facets — `lit` elapsed (kept on every card), the `flip in` ring (hero), and a
  `ready` probe strip (core temp + predicted-ready) when a probe is attached. `—` for no-reading.
- **Unified glass treatment (cards + header + preheat):** `.clear` glass + `grillCardBody`
  top→bottom gradient + beveled rim (white top / black bottom) + deep shadow, over a
  **charcoal-bed background** (many small `emberSpots`). New ButtonStyles tokens:
  `grillCardTint` (0.12), `grillCardBodyTop/Bottom`. (`589e13e`,`6421597`,`8845646`,`945bb81`,`c643f5f`)
- **Header:** ~1/3 taller, 22pt title, 12pt gap above the first card (`99018fd`).
- **Probe entry point:** a visible **"Probe" chip** in the header (thermometer + label, orange
  when connected) opens the picker — replaced the invisible bad-SF-symbol button (`91170e1`).

**Still pending on the probe (device-only; code is done & test-verified):**
- On-**watch** probe section visual + a real **long-cook** on-device pass.
- Tidy-up: remove the now-redundant DEBUG "Connect Probe (debug)" Settings entry (header chip
  supersedes it); decide **°F vs °C** for probe temps (currently °C).
- Fine-tune knobs if desired: ember intensity (`emberSpots` opacities), card body opacity
  (`grillCardBodyTop/Bottom`), bevel/shadow strength.

## Up next
- [ ] **Design-consistency sweep (V2 step 4)** — extend the glass language to Settings,
      paywall/premium, custom sounds, the alert overlays, and the watch UI (details below).
- Quick wins anytime: voice announcements, preheat→`endDate`, the two device bugs.

## Features
- **Combustion Bluetooth probe support** — see `combustion-probe-ble-spec.md`.
  Decision made: **raw CoreBluetooth + our own parser** (not the SDK; SDK is dormant
  since 2023 + drags in a DFU lib). Phased:
  - [x] **2A — domain models + Probe Status decoders + unit tests** (`9f7bc42`). Pure
        Swift, 49 tests, bit layouts transcribed from combustion-ios-ble.
  - [x] **2B — CoreBluetooth central (foreground):** DONE. `ProbeBLEManager`
        (scan/connect/notify/decode) + thin real `CoreBluetoothProbeCentral` +
        `ProbePickerView` behind a DEBUG Settings entry (`f853f87`); Info.plist
        config — usage string + `bluetooth-central` on iOS, none on watch (`b2236e7`).
        **On-device verified:** connects to a real probe & streams. Caught + fixed a
        temp byte-order bug (block must be reversed before unpacking) and pinned 4
        real-probe payloads as fixtures (`f20d70a`); room-temp probe now decodes to
        ~27 °C. Jim to rebuild and eyeball the corrected temps.
  - [~] **2C — forward compact reading to watch** over existing `WCSession`: DONE in code
        (`4d2b6ef`/`19290c9`). Additive `sendProbeReading` + `"probe"` routing; shared wire
        types live once in WCSessionManager; iOS `ProbeWatchForwarder` (throttled ~1/s)
        wired in the DEBUG Settings screen; watch shows a probe section (core temp +
        predicted countdown + status). 9 mapping/throttle tests; iOS+watch builds green.
        **Deferred:** on-watch visual check — Apple Watch dev tooling was uncooperative
        (couldn't get the fresh watch build on device). Code is test-verified + builds;
        confirm the watch probe section later (fresh watch build, or naturally during a cook).
  - [x] **2D — background state restoration + reconnection** (`50d6160`): restore
        identifier + willRestoreState recovers the connection after suspend/relaunch;
        auto-reconnect on unexpected disconnect (intent in manager, mechanism in central);
        `.reconnecting` state in the picker. 4 reconnect tests; iOS+watch builds green.
        **Deferred (with 2C):** on-device verification during a real long cook.
  - [x] **2E — on-screen probe UI** — done in the layout pass: probe strip on the attached
        cook's card + a header "Probe" chip entry point (`ab87de0`, `91170e1`). Watch display
        done in 2C (on-watch visual check still pending).
  - [ ] **2F (later) — UART commands** (alarms, set-prediction): separate spec, out of scope.
- [x] **Dev-only free⇄paid toggle** for testing premium gating — shipped `4ec2ca8`.
      `#if DEBUG`-only "Debug" section at the bottom of Settings: "Override Premium"
      switch + Free/Paid segmented picker. Overrides `isPremiumUser` locally; both
      RevenueCat sync points back off while it's on; turning it off re-syncs the real
      entitlement. Release build verified to strip it. Never calls purchase/restore.

## UX / layout
- [x] **Reposition the Preheat grill button** → now a fixed bottom bar (`69aad43`).
- [x] **Beef up the "GrillTime Pro" header** → taller + 22pt title + glass treatment (`99018fd`, `c643f5f`).
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
- [x] **Lit time froze when the flip countdown completed** — fixed: `handleCompletion()`
      no longer stops the refresh timer, so "Lit" keeps counting until Reset; resync restarts
      it after backgrounding. Regression test added. (`ce907cb`)
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
- [x] **Command allowlist** added to `.claude/settings.json` (`b33b04a`) so the build
      chain runs without approval prompts (git/xcodebuild/pgrep/caffeinate/etc.); destructive
      git stays denied. Fixed the overnight runs stalling on permission dialogs.
- [ ] **Final ship merge `Apple-Watch-Suport` → `main`** once V2 is done — then tag +
      release. (Optional pre-merge tidy: drop now-unreferenced `Icon-60@2x/3x.png`.)
- [ ] App Store submission once the watch features are ready.

## Recently shipped (2026-06-14)
- [x] Large timer card Liquid Glass redesign (`f9b4117`)
- [x] Compact card redesign + countdown progress ring (`3486613`)
- [x] CLAUDE.md architecture facts filled in (`a1c975e`)
- [x] Trimmed the stale "‹TODO›" note at the top of CLAUDE.md
- [x] Added this TODO.md backlog + CLAUDE.md pointer (`65f735f`)
