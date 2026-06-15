# CLAUDE.md — Grill Time Pro

This file orients Claude Code on the Grill Time Pro codebase. Read it fully before making changes.

> **Note:** Several fields below are marked `‹TODO›`. They are things only the project itself can confirm. On your **first run**, inspect the project and fill these in (see "First Run" below), then keep this file accurate as the architecture evolves.

---

## What this app is

Grill Time Pro is a shipping iOS app (live on the App Store) that helps users time and manage grilling/cooking sessions. It has a paired **Apple Watch companion app**. The product is real and in use, so changes must not break existing users' workflows or data.

## Architecture

- **Language / UI:** Swift + SwiftUI. UIKit is used where SwiftUI doesn't reach: an `AppDelegate` (orientation lock, RevenueCat config), haptics (`UI*FeedbackGenerator`), `AVAudioSession` for alert playback, and `UIScreen`/`UIDevice` for layout. RevenueCat is a dependency (paywall/premium).
- **Targets / schemes:**
  - iOS app — scheme `JF BBQ Timer`
  - watchOS app — scheme `GrillTime Pro Watch App Watch App` (companion; **requires the paired iPhone**, not independent)
- **Phone ↔ Watch communication:** `WatchConnectivity` (`WCSession`), wrapped by the shared `WCSessionManager` singleton (compiled into both targets). The **iPhone is the source of truth**; it pushes full timer snapshots (incl. each timer's absolute `endDate`) and the watch mirrors/ticks locally and sends back commands. See [[watch-sync-working-baseline]] in memory before changing sync.
- **Persistence:** `UserDefaults` (no Core Data/SwiftData). `Settings` (`Settings.swift`) loads/saves all prefs and the `additionalTimers` array (JSON-encoded). Each running timer's state persists per-id in `TimerState` (`saveState`/`loadState`): `endDate`, remaining-at-pause, and elapsed-start — so countdowns survive relaunch via absolute dates, not counters.
- **Deployment target:** iOS app 18.2, watchOS 11.x; builds against the iOS/watchOS 26 SDK. The app still supports pre-26, so **iOS 26 Liquid Glass code is gated behind `if #available(iOS 26, *)` with a non-glass fallback in the `else`** (see the timer cards and `TimerContainerAppearance`).

## Build & test

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

**Established glass components — reuse these for consistency** (the main timer screen was redesigned around them; don't re-roll effects):
- `Color.grillGlassTint` (`ButtonStyles.swift`) — the one shared warm tint applied to **every** glass surface (cards, header, preheat) so white text keeps contrast on the bright background. Tune contrast here.
- `GlassActionButtonStyle` — action buttons: `.primary` = solid orange (`TimerAccent`) pill, `.secondary` = translucent chip; has a `compact:` variant. Solid-on-glass on purpose (avoids glass-on-glass).
- `CircularTimerRing` — countdown ring driven by `TimerState.progress(at:)` (pure, unit-tested; measured against `runDuration` so pause/resume doesn't refill it).
- Per-card content lives in `GlassLargeTimerContent` / `GlassCompactTimerContent` (`TimerViews.swift`); the glass material, completion flash and adaptive height come from `TimerContainerAppearance`. Toolbar/cards/preheat share a 16pt horizontal margin.

## Workflow

- Jim writes/approves a spec before implementation. Work from the spec; if the spec is ambiguous, ask before guessing.
- Claude Code handles all git operations, **including committing and merging PRs.** Open a PR per concern, verify it builds, then merge it (squash) into the working branch. Jim can review any PR on GitHub but does not need to merge manually.
- Stage specific files and review `git diff` before committing — avoid `git add -A` so build-induced changes (e.g. Xcode reformatting `project.pbxproj`) don't sweep into commits.
- Prefer small, reviewable commits with clear messages.
- **Work autonomously on low-risk tasks** (reading, builds/tests, searches, code edits, committing/merging build-verified cleanup & refactor PRs, docs/config) — act and report, don't ask. **Pause and ask only for consequential decisions:** changes that risk the live app's user-facing behavior, anything irreversible (force-push, history rewrite, data deletion), new dependencies, App Store submission, or design choices with real tradeoffs. A scoped permissions allowlist in `.claude/settings.json` reflects this (routine tools auto-approved; destructive git denied).

---
*Keep this file current. If you discover the architecture differs from what's described here, update it as part of your change.*
