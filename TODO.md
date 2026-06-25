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

## Up next — Main-screen layout pass (V2 step 3), design AGREED (2026-06-24)
Design decided with Jim (mockups reviewed). Build in focused, one-concern steps:
- **Probe attaches to a cook**, not a global readout. Pick which cook/timer when
  connecting. The flip-interval timer and the probe's doneness prediction stay separate
  mechanisms (per spec) but are **co-located on that cook's card**.
- **Cook card shows three labeled time facets:** `lit` elapsed (demoted line up top —
  KEEP THIS on every card, Jim explicitly wants it), the `flip in` countdown ring (hero),
  and a `ready` probe strip (core temp + predicted-ready) shown only when a probe is attached.
- **Header:** beefier (flame mark + title + a connect-probe/Bluetooth button + gear). No
  global probe status line. No-reading sensors render `—` (not −20 °C).
- **Preheat:** fixed bottom bar, always visible (flips to live countdown + stop while running).
- **Ember-glow background:** deep warm base + soft orange/red radial pools, iOS 26-gated;
  dial `grillGlassTint` DOWN so it shows through the glass.
- Multi-probe is out of V2 scope (single probe; design extends to a primary+list later).
- **Compact mode:** same header / ember-glow / bottom Preheat bar; only the cards densify
  to a single row (small ring + name + `flip in · lit` line + compact buttons). `lit` stays
  on every compact card; the probe card adds ONE slim line (`Core · ready`), others stay tight.
  (Both large + compact card layouts need the probe strip — build step 3 covers both.)

Build order (each its own commit, verify on device as we go):
1. [ ] App-wide probe manager (move ownership out of the DEBUG Settings entry).
2. [ ] Probe↔cook attachment model + "pick a cook on connect" flow (lightweight data-model add).
3. [ ] Probe strip on the cook card (core temp + predicted-ready), iOS 26 glass.
4. [ ] Header beef-up + connect button.
5. [ ] Fixed bottom Preheat bar.
6. [ ] Ember-glow background + dial down `grillGlassTint`.

Deferred probe checks to fold in here: on-watch visual + a real long-cook on-device pass.

_Ember-glow note (lands in step 3):_ deep warm base + soft orange/red radial
pools, iOS 26-gated; when it's in, dial `Color.grillGlassTint` back down so the
background shows through the glass.

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
