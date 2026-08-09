# CLAUDE.md — Grill Time Pro

This file orients Claude Code on the Grill Time Pro codebase. Read it fully before making changes.

> **Note:** Keep this file accurate as the architecture evolves. The working backlog of pending tasks lives in [TODO.md](TODO.md) — check it at the start of a session and keep it updated as items land or arise.

---

## What this app is

Grill Time Pro is a shipping iOS app (live on the App Store) that helps users time and manage grilling/cooking sessions. It has a paired **Apple Watch companion app**. The product is real and in use, so changes must not break existing users' workflows or data.

## Architecture

- **Language / UI:** Swift + SwiftUI. UIKit is used where SwiftUI doesn't reach: an `AppDelegate` (orientation lock, RevenueCat config), haptics (`UI*FeedbackGenerator`), `AVAudioSession` for alert playback, and `UIScreen`/`UIDevice` for layout. RevenueCat is a dependency (paywall/premium).
- **Targets / schemes:**
  - iOS app — scheme `JF BBQ Timer`
  - watchOS app — scheme `GrillTime Pro Watch App Watch App` (companion; **requires the paired iPhone**, not independent)
- **Phone ↔ Watch communication:** `WatchConnectivity` (`WCSession`), wrapped by the shared `WCSessionManager` singleton (compiled into both targets). The **iPhone is the source of truth**; it pushes full timer snapshots (incl. each timer's absolute `endDate` and, additive since 2026-08-08, `runDuration`) and the watch mirrors/ticks locally and sends back commands. The watch's timer pages mirror the phone card — countdown ring hero (fill from `WatchRingMath` in `WCSessionManager.swift`, pure + iOS-unit-tested), name + probe temp line, phone-style preset buttons; see `watch-ring-layout-spec.md`. See [[watch-sync-working-baseline]] in memory before changing sync.
- **Combustion temperature probe (V2):** the iPhone owns a single BLE connection — raw `CoreBluetooth`, **not** the vendor SDK (see [[combustion-probe-approach]]). `ProbeBLEManager` (`#if os(iOS)`, app-wide via `.environmentObject` from `JF_BBQ_TimerApp`) holds all scan/connect/notify/reconnect state behind a `ProbeCentral` protocol so the decision logic is unit-testable; the real `CoreBluetoothProbeCentral` is a thin delegate adapter with CB state-restoration + auto-reconnect. Pure byte decoders + domain models live in `ProbeModels.swift` / `ProbeStatusDecoder.swift` (**the 13-byte temperature block must be byte-reversed before bit-unpacking** — fixtures pinned from a real probe). A compact reading is forwarded to the watch over the same `WCSession` (`ProbeWatchForwarder` → `WCSessionManager.sendProbeReading`, `"probe"` route; shared wire types in `WCSessionManager`). The probe **attaches to one cook** (`ProbeBLEManager.attachedCookID`); that timer's card shows core temp + predicted-ready. Connect via the header **"Probe" chip**. Spec: `combustion-probe-ble-spec.md`. **Round 2 (target temp + carryover; spec `probe-target-prediction-spec.md`):** the app also *writes* to the probe over its UART service — framing/CRC in `ProbeUART.swift` (pure, fixture-tested), send/retry/timeout + re-push-on-reconnect rules in `ProbeBLEManager`. A per-cook target (stored in `Settings.probeTargetsByCookID`; set via the card's probe strip → `ProbeTargetSheet`) becomes the probe's prediction set point; `ProbeCookPhaseEngine` + `TargetCrossingLatch` (pure) derive the guided-cook phase and fire-once alerts. **Gotcha: shared wire types (incl. `ProbeCookPhase`) must live in `WCSessionManager.swift`** — the watch target compiles only selected files, so a new file in the app folder is iOS-only unless Jim changes target membership in Xcode.
- **Persistence:** `UserDefaults` (no Core Data/SwiftData). `Settings` (`Settings.swift`) loads/saves all prefs and the `additionalTimers` array (JSON-encoded). Each running timer's state persists per-id in `TimerState` (`saveState`/`loadState`): `endDate`, remaining-at-pause, and elapsed-start — so countdowns survive relaunch via absolute dates, not counters.
- **Deployment target:** iOS app **15.6** (per `project.pbxproj` — the main app target with `LaunchScreen.storyboard`), watchOS 11.x; builds against the iOS/watchOS 26 SDK. (Test/UITest targets are at 18.2.) Because the app reaches back to iOS 15.6, **iOS 16+ APIs also need gating** (e.g. `scrollContentBackground` is iOS 16+), and **iOS 26 Liquid Glass code is gated behind `if #available(iOS 26, *)` with a non-glass fallback in the `else`** (see the timer cards / `TimerContainerAppearance`, and the shared glass helpers in `ButtonStyles.swift`).

## Build & test

> **Jim's Xcode version: 26.5 (17F42).** When giving GUI directions (menu paths,
> Settings panels, where to click), reference *this* version — Xcode moves things
> between releases, so instructions written for older versions can send him to the
> wrong place. Known 26.x change: **merging a branch is in the Source Control
> *navigator*** (2nd sidebar icon → expand repo → Branches → right-click the branch
> → "Merge … into …"), **not** the Integrate menu. If unsure where something lives in
> 26.5, say so rather than guessing a path from an older version.

The architecture fields above were confirmed on 2026-06-14. Useful commands:

```bash
# List schemes, targets, and configurations (if things change)
xcodebuild -list

# Build the iOS app.
# NOTE: simulator names can be ambiguous (duplicate "iPhone 16" entries) and
# make -destination by name fail with "Unable to find a device". Prefer a
# specific device id from `xcrun simctl list devices available`:
#   -destination 'id=<UDID>'
xcodebuild -scheme "JF BBQ Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build the watch app
xcodebuild -scheme "GrillTime Pro Watch App Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Run unit tests (timer/progress math lives in JF BBQ TimerTests, Swift Testing)
xcodebuild test -scheme "JF BBQ Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

To see a change running, install + launch on a booted sim and screenshot — the
developer can't relay screenshots back, but `xcrun simctl io <id> screenshot`
works headlessly:

```bash
xcrun simctl install <id> "<DerivedData>/.../JF BBQ Timer.app"
xcrun simctl launch  <id> com.jamesfarruggia.jfbbqtimer.dev
xcrun simctl io      <id> screenshot /tmp/shot.png
```

Note: toggling `compactMode` via `defaults write` does **not** reliably take
effect for this app — flip "Compact Display Mode" in the in-app Settings to test
compact layouts.

You **can** compile and run tests from the command line to verify your work. You **cannot** see the running app — visual and interaction verification happens in Xcode by the developer (Jim). For UI changes, describe clearly what to look for when he checks.

## Hard rules

- **Do not hand-edit `*.xcodeproj/project.pbxproj` or `.xcworkspace` internals.** These corrupt easily. If a change requires adding a target, capability, signing, or file references that touch the project file, **stop and write out the exact Xcode GUI steps for Jim to perform manually** instead of editing the file.
- **Time and money math must be unit-tested.** Any countdown/timer logic must be expressed as pure, testable functions with injectable "now" — not dependent on wall-clock side effects.
- **One concern per PR.** Keep changes focused. Don't bundle a UI redesign into a logic refactor.
- **Don't introduce new dependencies** without flagging it first.

## watchOS gotchas to keep in mind

- The watch app gets **suspended** when the wrist drops / screen sleeps. Anything that relies on a continuously-running `Timer` to stay correct will drift or freeze. Time-based state must be derived from absolute `Date`s, not decremented counters.
- Always-On Display shows a dimmed UI while suspended — prefer system-managed self-updating views (e.g. `Text(timerInterval:)`) for anything that must stay live.
- Local notifications (`UNUserNotificationCenter`) fire regardless of app state and are the reliable way to alert on timer completion.

## iOS / watchOS 26 + Liquid Glass

The app builds against the iOS/watchOS 26 SDK. Recompiling against this SDK causes **native SwiftUI controls to adopt Liquid Glass automatically**, which can change the appearance of toolbars, sheets, and buttons without explicit code changes. When working on UI:

- Apply glass **intentionally** via `.glassEffect(...)`, not by accident.
- **Do not stack glass on glass** — content layer = no glass, navigation layer = glass, overlays on top. Stacked translucency reads as muddy.
- If supporting OS versions below 26, gate glass APIs behind `if #available(iOS 26, *)` with a sensible fallback.

**Established glass design — reuse for consistency** (the main screen + cards were redesigned around this; don't re-roll effects):
- **Unified "frosted glass pane" treatment** on the cards, the header bar, and the Preheat bar (iOS 26): `.glassEffect(.clear.tint(.grillCardTint), in:)` + a `grillCardBodyTop → grillCardBodyBottom` `LinearGradient` `.background` (gives body + a lit-from-above 3D look) + a **beveled rim** `.overlay` (white-top → black-bottom stroke) + a deep `.shadow`. The card version lives in `TimerContainerAppearance.styledCard` (`ButtonStyles.swift`); the header and preheat replicate the same modifiers inline in `ContentView`. Don't go back to `.regular` glass for the cards (reads opaque/flat) or `.clear` with no body (reads as just an outline).
- **Glass tint tokens** (`ButtonStyles.swift`): `grillCardTint` (0.12) is the card/header/preheat tint; `grillCardBodyTop`/`grillCardBodyBottom` are the body-gradient colors — tune card transparency/body here. `grillGlassTint` (0.42) is the older single tint, kept for any remaining surfaces / `GlassActionButtonStyle`.
- **Ember-glow background** (`EmberBackground` in `ButtonStyles.swift`, iOS 26): a deep charcoal base + many small radial "coals" from the `emberSpots` array — tune count/size/opacity there. Pre-26 falls back to flat `PrimaryBackground`. `ContentView.backgroundLayer` just wraps it.
- **Shared sweep helpers** (`ButtonStyles.swift`) — reuse these to extend the glass language to any screen rather than re-rolling effects: `EmberBackground` (the coals bed), `.grillGlassPane(cornerRadius:)` (the card/header/preheat pane as a modifier), `.immersiveGlassList()` (turns a stock grouped `List`/`Form` immersive: hides the scroll background, drops `EmberBackground` behind, frosts every row via a single list-level `.listRowBackground(GrillGlassSectionFill())` that **cascades to all rows**, and forces dark scheme so system text reads light), and `.immersiveGlassBackground()` (ember + dark scheme for non-list `VStack`/`ScrollView` screens). All iOS 26-gated, no-op/fallback pre-26. Applied across the Settings stack, paywall, custom sounds, and the completion alerts.
- `GlassActionButtonStyle` — action buttons: `.primary` = solid orange (`TimerAccent`) pill, `.secondary` = translucent chip; `compact:` variant. Solid-on-glass on purpose (avoids glass-on-glass).
- `CircularTimerRing` — countdown ring driven by `TimerState.progress(at:)` (pure, unit-tested; measured against `runDuration` so pause/resume doesn't refill it).
- Per-card content: `GlassLargeTimerContent` / `GlassCompactTimerContent` (`TimerViews.swift`) — each card shows **`lit`** elapsed (keeps counting until Reset, even after completion), the **`flip in`** ring (hero), and a **`ready`** probe strip when a probe is attached (`CardProbeInfo`, `—` for no reading). Completion flash + adaptive height from `TimerContainerAppearance`. Header/cards/preheat share a 16pt horizontal margin; the header has a **"Probe" chip** that opens the connect sheet (real `CustomPaywallView` when free — never a stub).
- **Notched large-card layout** (2026-08-08, spec `notched-card-layout-spec.md`): the large card interlocks a 200pt ring with two preset buttons whose shapes are carved from the ring's circle — `NotchedCardLayout` (pure geometry, all values derive from spec constants + content width), `NotchedRoundedRect` (rounded rect minus circle via `Path.subtracting`, fine because the glass card is iOS 26-only), `NotchedActionButtonStyle` (solid-accent primary / translucent secondary, tap target clipped to the shape). Stop/Reset live in the channel between the buttons. Compact card and pre-26 layouts unchanged.
- **Alerts & voice:** the completion phrase is built by `AnnouncementMessage` (name-first — "Ribeye timer is complete" — with a `{timer}` placement placeholder; unit-tested; the Settings test button uses the same builder). When a voice announcement actually plays it **replaces** the looping alert sound (`SettingsExtension.playTimerCompletion`); background completions still alert via notification sounds. For "is any timer running" UI (e.g. the Preheat bar's disabled state), use the published `TimerStatesManager.anyTimerRunning` — the `states` array only publishes on add/remove, so scanning it from a view goes stale.

## Workflow

- Jim writes/approves a spec before implementation. Work from the spec; if the spec is ambiguous, ask before guessing.
- Claude Code handles all git operations, **including committing and merging PRs.** Open a PR per concern, verify it builds, then merge it (squash) into the working branch. Jim can review any PR on GitHub but does not need to merge manually.
- Stage specific files and review `git diff` before committing — avoid `git add -A` so build-induced changes (e.g. Xcode reformatting `project.pbxproj`) don't sweep into commits.
- Prefer small, reviewable commits with clear messages.
- **Work autonomously on low-risk tasks** (reading, builds/tests, searches, code edits, committing/merging build-verified cleanup & refactor PRs, docs/config) — act and report, don't ask. **Pause and ask only for consequential decisions:** changes that risk the live app's user-facing behavior, anything irreversible (force-push, history rewrite, data deletion), new dependencies, App Store submission, or design choices with real tradeoffs. A scoped permissions allowlist in `.claude/settings.json` reflects this (routine tools auto-approved; destructive git denied).

### Git & branching (solo App Store workflow)

- `main` is **production** — only finished, shippable work lands there. Tag each App Store release (`v1.2.1`, `v2.0`, …).
- Develop a body of work on **one feature branch** (currently `Apple-Watch-Suport`, which is really the **V2** branch). Small, focused commits.
- **Hotfix flow:** branch from `main`, fix, merge to `main`, ship + tag — then merge `main` → the feature branch to absorb the fix.
- **Stay current:** whenever `main` gains a commit, merge `main` → feature branch soon after, so the eventual merge-back stays small and clean.
- **Ship:** when the feature work is done, merge feature → `main`, tag, release.
- **Jim performs merges in Xcode** (Source Control ▸ Merge), not command-line git. Claude prepares — predicts conflicts, writes the exact click-path — and verifies the build afterward. Claude does **not** run `git merge`/rebase or force-push, and never resolves `project.pbxproj` conflicts by hand.
- Push branches to `origin` regularly (backup).

---
*Keep this file current. If you discover the architecture differs from what's described here, update it as part of your change.*
