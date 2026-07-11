# TODO — Grill Time Pro

Working backlog. Claude Code reads and updates this; Jim edits freely. Check
items off (`- [x]`) as they land. Git history is the source of truth for what
actually shipped — this file is just the running plan.

## Working V2 order (adjustable)
All items below are **Version 2**. Planned sequence:
1. [x] DEBUG-only free⇄paid toggle (`4ec2ca8`)
2. [x] **Combustion probe** — BLE foundation 2A–2D done + on-device connect/stream verified
3. [x] **Main-screen layout pass** — header + preheat + ember-glow + probe UI + glass redesign
4. [x] Design-consistency sweep (Settings, paywall, alerts, custom sounds, watch UI)
5. [x] Onboarding review (`6df536a`) — redesigned to ember/glass, slimmed setup, replay-from-Settings
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

**Probe UI polished (`ac25316`):** ProbePickerView + ProbeAttachSheet themed (immersive
glass + accent), added a "Done" button to the picker sheet, renamed discovered probes
"Combustion Probe" (was "Unknown Probe"), removed the redundant DEBUG "Connect Probe" entry.

**Still pending on the probe:**
- On-**watch** probe section visual + a real **long-cook** on-device pass.
- Decide **°F vs °C** for probe temps (currently °C).
- [x] Real per-probe **serial** in the picker — parses advertising manufacturer data
  (vendor `0x09C7`, serial UInt32 LE); shows "Combustion Probe / Serial 1000FADE" and uses
  it in the status line. Pinned to 4 real packets in `AdvertisingSerialTests` (`8f1e81f`).
- Fine-tune knobs if desired: ember intensity (`emberSpots` opacities), card body opacity
  (`grillCardBodyTop/Bottom`), bevel/shadow strength.

## Up next
- [x] **Design-consistency sweep (V2 step 4)** — DONE: Settings stack, paywall, custom
      sounds, alert overlays (iPhone), + watchOS-native light touch. Watch on-device check
      pending. **Next: onboarding review (step 5)**, then ship-merge (step 6).
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
  - [~] **2F — UART commands (set-prediction):** now spec'd as probe round 2 — see
        `probe-target-prediction-spec.md` and the "Probe features" section below.
        Probe-side alarm commands (`0x0B`) deliberately skipped (phone-side alert instead).
- [x] **Dev-only free⇄paid toggle** for testing premium gating — shipped `4ec2ca8`.
      `#if DEBUG`-only "Debug" section at the bottom of Settings: "Override Premium"
      switch + Free/Paid segmented picker. Overrides `isPremiumUser` locally; both
      RevenueCat sync points back off while it's on; turning it off re-syncs the real
      entitlement. Release build verified to strip it. Never calls purchase/restore.

## UX / layout
- [x] **Reposition the Preheat grill button** → now a fixed bottom bar (`69aad43`).
- [x] **Beef up the "GrillTime Pro" header** → taller + 22pt title + glass treatment (`99018fd`, `c643f5f`).
- [x] **Detailed onboarding review** (`6df536a`) — ember/glass theme, rewritten/trimmed
      copy, slimmed setup (defaults summary + optional "Customize timers"), fixed the
      title/Skip overlap, "Replay Welcome Tour" in Settings, removed dead onboarding code.
- [ ] **Cleanup (needs Xcode):** `OnboardingView.swift` is now fully dead (the active flow is
      `OnboardingFlowView` in `CarouselOnboardingView.swift`; `OnboardingView` is referenced
      only by its own `#Preview`). Delete the file via Xcode (right-click ▸ Delete) — Claude
      can't remove it without hand-editing `project.pbxproj`.

## Audio
- [ ] **Voice announcements sound bad** — investigate + improve quality
      (`AnnouncementRepeater` / voice settings in `SettingsExtension.swift`).

## Design consistency (extend the glass language to the rest of the app)
Shared helpers added in `ButtonStyles.swift` (reuse, don't re-roll): `EmberBackground`,
`.grillGlassPane`, `.immersiveGlassList` (List/Form), `.immersiveGlassBackground` (non-list).
All iOS 26-gated with pre-26 fallbacks; build + unit tests green; verified on an iOS 26.5 sim.
- [x] Settings stack — main Settings + Manage Timers + Add/Edit Timer + Alert Sounds +
      Voice Announcements + preset picker (`7ea85f4`).
- [x] Paywall/premium — `CustomPaywallView` (ember on 26 / salmon pre-26, adaptive text)
      + `PremiumUpgradeView` glass card (`75472f5`).
- [x] Custom sounds (`CustomSoundsView`) (`5574345`).
- [x] Completion alert overlays — `AlertView` frosted-red glass + pulsing rim/glow;
      `PreheatAlertView` matched, blue→accent Dismiss (`265a4cd`).
- [x] **Watch app UI refresh** — watchOS-native light touch (no ember bed): warm-tinted
      probe card, rounded/monospaced timer typography, long-preset format fix (`935e84c`).
      Build-verified; on-device visual check still pending (needs paired-iPhone sync).

## Mechanics / consistency
- [x] **Preheat timer → `endDate` model** — fixed (`b03c2ba`): now derived from an
      absolute `preheatEndDate` (+ `.common` run-loop + foreground resync), so it no
      longer runs slow when backgrounded/locked/scrolling. Pure `PreheatCountdown`
      math, unit-tested. (Found in TestFlight: a 10-min preheat took ~15 min.)
- [x] **Fahrenheit/Celsius option** — added (`8231485`): `TemperatureUnit` setting in
      Display & Accessibility, applied on the card, probe picker, and watch; unit rides
      in the probe wire payload. Probe data stays °C; conversion at display only.
      **Default is Celsius** — flip to Fahrenheit if Jim prefers (US BBQ audience).
- [ ] Watch schedules its own local notification at `endDate` so alerts fire even
      when the watch app is asleep (lets it lean less on the extended-runtime
      keep-alive). Carefully verify — touches the working alert path.

## Probe features
- [~] **Probe round 2: target temp + carryover prediction** — spec approved 2026-07-11
      (`probe-target-prediction-spec.md`). **3A (UART plumbing) done:** `ProbeUART`
      framing/CRC/SetPrediction encode + response decode (fixtures computed
      independently); `ProbeBLEManager` send→retry→timeout command logic;
      UART service discovery/write/notify in the CB central. 24 new tests.
      **3B (target on the cook card) done:** per-cook target stored in
      `Settings.probeTargetsByCookID` (dict, not on BBQTimer — legacy timers are
      rebuilt on the fly); probe strip shows "→ 203°" / "Set target" chip, tap
      opens `ProbeTargetSheet` (quick-pick doneness + custom entry, user's unit,
      stored °C); manager owns send/re-send (UART-ready hook re-pushes after
      reconnect; never clears a set point it didn't set); Reset clears the
      cook's target. 11 new tests. **On-device check pending** (strip tap,
      sheet, Combustion-app cross-check of the set point).
      **3C (carryover flow) done:** pure `ProbeCookPhaseEngine` (monitoring →
      pull-in countdown → PULL NOW → resting → done) with fire-once alerts;
      strip's ready slot is phase-driven; immediate local notification + haptic
      on pull-now/done. **Semantics caveat:** Combustion documents the states
      but not the removal→resting lifecycle — "done" trusts only probe
      state 4-while-resting OR our own stored target crossing (never the
      probe-reported set point). **Validate on a real cook** and adjust the
      engine if observed behavior differs. 9 new tests.
      **3D (crossing-alert latch) done:** pure `TargetCrossingLatch` on the
      MEASURED core (arm-below-first, fire-once, 2 °C re-arm hysteresis, −20 °C
      no-data floor ignored); new `.targetReached` event suppressed when a
      carryover alert already covered the cook; resets with the phase engine.
      8 new tests.
      **3E (battery/overheat) done:** Overheating Sensors byte (offset 48)
      decoded (nil-safe for short payloads); one-shot batteryLow/overheating
      events per USER connection (auto-reconnect blips stay quiet); warning
      icon on the header Probe chip + all three strips; notifications wired.
      8 new tests.
      **3F (watch) done — round 2 CODE-COMPLETE:** additive wire keys
      (`targetC`/`phaseRaw`/`overheating`; old payloads decode to safe
      defaults; `ProbeCookPhase` moved into WCSessionManager.swift because
      that's the file both targets compile — new files in the app folder are
      iOS-only); forwarder sends immediately on phase change; watch probe page
      shows target ("→ 203°"), phase-aware status line ("Pull now!" / resting /
      "Ready to serve"), overheat icon. 4 new tests; 186 total green.
      **Remaining before ship: on-device verification pass** —
      - [ ] Set target from card → probe picker/Combustion app shows same set point
      - [ ] Real cook: phase progression + pull-now/done alerts (validate the
            undocumented resting semantics the engine assumes — see 3C caveat)
      - [ ] Crossing alert with prediction never converging
      - [ ] Battery/overheat badges; watch page target/phase line
      - [ ] Reset clears target; reconnect re-pushes set point
      Design Qs resolved: target is **per-cook, set on the timer card**; one target
      field drives the probe's prediction set point (first UART write command,
      `0x05`), the removal+resting ("pull now → rest → done") flow, and the
      phone-side crossing alert; plus low-battery/overheat badges. Absorbs the old
      standalone "target-temp alert" item. Note: probe predictions currently only
      work if the user also runs Combustion's app to set the target — this round
      makes them self-sufficient.
- [x] **SafeCook / Food Safe — parked** (decision 2026-07-11): education-heavy,
      food-safety-liability-adjacent, and low-and-slow BBQ blows past the thresholds
      anyway. Revisit only on user demand.

## Bugs / verify on device
- [x] **Lit time froze when the flip countdown completed** — fixed: `handleCompletion()`
      no longer stops the refresh timer, so "Lit" keeps counting until Reset; resync restarts
      it after backgrounding. Regression test added. (`ce907cb`)
- [ ] **iPhone↔watch timer out of sync (under investigation)** — seen in TestFlight:
      started a timer on iPhone, but on the watch it wasn't running; after starting it
      on the watch, the iPhone's "lit" elapsed time had changed from what it should have
      been. Jim is reproducing with more detail (was Start tapped? what was tapped on the
      watch? was elapsed ahead/behind & by how much?). Touches the working sync baseline —
      diagnose from a repro before changing anything.
- [ ] Does **compact mode persist** across a cold relaunch? The Settings toggle
      binds straight to the published property; no save-on-change was spotted.
- [x] **Watch long-preset formatting:** fixed — watch `format(seconds:)` now shows hours
      (`1:30:00`), matching the iPhone (`935e84c`).

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
