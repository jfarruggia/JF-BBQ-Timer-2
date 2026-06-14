# CLAUDE.md — Grill Time Pro

This file orients Claude Code on the Grill Time Pro codebase. Read it fully before making changes.

> **Note:** Several fields below are marked `‹TODO›`. They are things only the project itself can confirm. On your **first run**, inspect the project and fill these in (see "First Run" below), then keep this file accurate as the architecture evolves.

---

## What this app is

Grill Time Pro is a shipping iOS app (live on the App Store) that helps users time and manage grilling/cooking sessions. It has a paired **Apple Watch companion app**. The product is real and in use, so changes must not break existing users' workflows or data.

## Architecture

- **Language / UI:** Swift + SwiftUI ‹TODO: confirm — note any UIKit usage›
- **Targets:**
  - iOS app — `‹TODO: target/scheme name›`
  - watchOS app — `‹TODO: target/scheme name›` (companion; **requires the paired iPhone**, not independent)
- **Phone ↔ Watch communication:** `WatchConnectivity` (`WCSession`). The **iPhone is the source of truth**; the watch mirrors state.
- **Persistence:** ‹TODO: identify on first run — UserDefaults / Core Data / SwiftData / plist / files. Document the exact store, where models live, and how timer/preset state is saved.›
- **Deployment target:** ‹TODO: confirm iOS/watchOS deployment versions. The project currently builds against the Xcode 26 / iOS 26 SDK.›

## First Run — fill in the unknowns before coding

Before your first real task, run these and update the `‹TODO›` fields above:

```bash
# List schemes, targets, and configurations
xcodebuild -list

# See the overall structure
find . -name "*.swift" | head -50
```

Then inspect the code to determine: the persistence layer, how timers are currently modeled and stored, how `WCSession` is set up and what messages are sent, and the deployment targets. Report what you find and update this file.

## Build & test

Confirm exact scheme names with `xcodebuild -list` first, then:

```bash
# Build the iOS app (adjust scheme + simulator name to a valid one)
xcodebuild -scheme "‹iOS scheme›" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build the watch app
xcodebuild -scheme "‹watchOS scheme›" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Run unit tests
xcodebuild test -scheme "‹iOS scheme›" \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

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

## Workflow

- Jim writes/approves a spec before implementation. Work from the spec; if the spec is ambiguous, ask before guessing.
- Claude Code handles all git operations; **Jim reviews and merges manually.**
- Prefer small, reviewable commits with clear messages.

---
*Keep this file current. If you discover the architecture differs from what's described here, update it as part of your change.*
