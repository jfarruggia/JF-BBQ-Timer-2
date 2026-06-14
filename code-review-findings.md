# Grill Time Pro — Code Review Findings & Roadmap

*Written by Claude (Opus 4.8) on 2026-06-14, after reviewing the app entry point,
the watch-connectivity layer, the watch UI, and the iOS timer engine.*

## How to use this document

This is our shared, living checklist for taking Grill Time Pro "to the next level."
Each item says **what** it is, **where** it lives, **why it matters**, and **what to
do** — plus a rough **effort** and **risk** so we can pick sensibly. We work through
these as small, separate pull requests (one concern per PR); Jim reviews and merges
each one. Update this file as items get done.

**Plain-language promise:** Jim is still learning iOS, so every item below is written
to be understandable without deep Swift jargon. Ask if anything is unclear.

---

## The big picture (what I found)

The app is in **better shape than the symptoms suggest**. The iOS timer engine already
does the hard, correct thing internally (it tracks an absolute finish time). The pain
you've felt — watch drift, "testing is impossible," the Xcode 26 look — traces back to
a handful of specific, fixable causes, not a rotten foundation.

Three themes:

1. **Everything is crammed into a few giant files** → every change is harder than it
   should be.
2. **The watch is fed the wrong kind of data** (a countdown number instead of a finish
   time) → that's the root of the sleep/sync problem.
3. **The logic is tangled together with the screen and live clocks** → that's why it
   can't be unit-tested, which is why "testing felt impossible."

---

## Roadmap (recommended order)

| # | Phase | Why this order |
|---|-------|----------------|
| 1 | **Safe cleanup** — dead code, logging, project hygiene | Low risk, makes everything after easier |
| 2 | **Make the timer math testable** + first real tests | Unblocks confidence for the rest |
| 3 | **Fix watch sync the right way** (send finish-times) | The big win you've been chasing |
| 4 | **Watch UI redesign** (use the full screen) | Easy once #3 reshapes the data |
| 5 | **Intentional Liquid Glass / Xcode-26 visual pass** | Fixes the "looks worse now" regressions |
| 6 | **Onboarding streamline** | Independent UX polish |
| 7 | **Bluetooth temperature probe** | Biggest new feature; build it on a clean base |

Separately (no fixed slot): **reconcile `Apple-Watch-Suport` with `main`** — `main` has
a version-bump commit this branch is missing, and this branch has all the watch work
`main` is missing. We'll plan that merge deliberately when the watch work is ready to ship.

---

## Phase 1 — Safe cleanup (low risk, high payoff)

### 1.1 Split the 2,747-line `ContentView.swift`
- **Where:** [`JF BBQ Timer/ContentView.swift`](JF BBQ Timer/ContentView.swift)
- **What:** One file holds ~30 types: data models (`BBQTimer`, `PresetInterval`), the
  `Settings` store, the **actual timer engine** (`TimerState` ~line 1995,
  `TimerStatesManager` ~line 2386), and ~20 views/button styles.
- **Why it matters:** Hard to navigate, slow to compile, and risky to edit — small
  changes can disturb unrelated code. This is the single biggest drag on every other task.
- **What to do:** Move types into focused files (e.g. `Models/`, `TimerEngine/`,
  `Views/`, `Styles/`) **without changing behavior**. Pure reorganization.
- **Effort:** Medium · **Risk:** Low (no logic change) — but touches the production file,
  so we do it carefully and verify it still builds.

### 1.2 Delete the dead `TimerCenter` stub
- **Where:** [`JF BBQ Timer/iOS/TimerCenter+WatchSync.swift`](JF BBQ Timer/iOS/TimerCenter+WatchSync.swift)
- **What:** `TimerCenter` calls itself a "minimal shell" and a set of "stubs." It holds a
  *second, empty* list of timers separate from the real engine (`TimerState`). The launch
  call that used it was already removed because it "sent empty snapshots."
- **Why it matters:** Two competing "timer brains" is confusing and was part of the
  watch-sync mess. The real timers live in `TimerStatesManager`.
- **What to do:** Remove this file (keep the small `watchPayload` idea for Phase 3 if useful).
- **Effort:** Low · **Risk:** Low (it's effectively unused).

### 1.3 Quiet the always-on logging
- **Where:** Throughout [`WCSessionManager.swift`](JF BBQ Timer/WCSessionManager.swift) and
  [the watch `ContentView.swift`](GrillTime Pro Watch App Watch App/ContentView.swift); some in
  [iOS `ContentView.swift`](JF BBQ Timer/ContentView.swift).
- **What:** Hundreds of emoji `print(...)` statements fire in **every** build, including
  what customers run. Recent work removed the old "debug-only" guards around them.
- **Why it matters:** Console noise, and a small amount of wasted work on hot paths
  (every second, every sync). Not user-visible, but unprofessional and slightly wasteful.
- **What to do:** Replace with Apple's `os.Logger` (or wrap in `#if DEBUG`) so logging is
  off in release builds. Easy, mechanical.
- **Effort:** Low–Medium · **Risk:** Low.

### 1.4 Stop copying bundled sounds on every launch + remove launch diagnostics
- **Where:** [`JF_BBQ_TimerApp.swift`](JF BBQ Timer/JF_BBQ_TimerApp.swift) — `setupSoundResources()`
  (~lines 55–203) and `SoundTestHelper.shared.runDiagnostic()` (~line 47).
- **What:** On every launch the app copies its bundled MP3s into the Documents folder and
  runs a sound "diagnostic" 2 seconds after launch.
- **Why it matters:** Bundled sounds can be played directly from the app bundle — copying
  them duplicates storage and adds file work to every startup. The diagnostic is debug code
  shipping to users.
- **What to do:** Play sounds from the bundle; delete the copy step and the launch
  diagnostic (or gate behind `#if DEBUG`). Needs a careful look at how sounds are loaded
  today so nothing breaks.
- **Effort:** Medium · **Risk:** Medium (touches the sound feature — test playback after).

### 1.5 Replace the private orientation-lock trick
- **Where:** [`JF_BBQ_TimerApp.swift`](JF BBQ Timer/JF_BBQ_TimerApp.swift) ~line 17 —
  `UIDevice.current.setValue(..., forKey: "orientation")`.
- **What:** Forces portrait using a private/undocumented key.
- **Why it matters:** Apple can reject apps for using private APIs, and it can break in new
  iOS versions. There's already a proper `supportedInterfaceOrientationsFor` in the
  AppDelegate — the KVC hack is redundant and risky.
- **What to do:** Rely on the supported orientation API (and Info.plist orientation keys);
  remove the KVC line.
- **Effort:** Low · **Risk:** Low–Medium (verify it still launches portrait-locked).

### 1.6 Small hygiene
- `UserDefaults.standard.synchronize()` (`JF_BBQ_TimerApp.swift` ~line 247) is obsolete —
  remove it.
- Empty `temp.swift` at the repo root — delete.
- `DebugPanel` / `DebugVisualizerTools.swift` / `SoundTestHelper.swift` — keep for dev, but
  make sure they're excluded from release or clearly debug-gated.
- The hardcoded RevenueCat key (`JF_BBQ_TimerApp.swift` ~line 34) is a *public* SDK key, so
  it's not a leaked secret — just noting it's there intentionally.
- **Effort:** Low · **Risk:** Low.

---

## Phase 2 — Make the timer math testable

### 2.1 Extract pure time functions with an injectable "now"
- **Where:** Logic currently lives inside `TimerState` / `TimerStatesManager` in
  [`ContentView.swift`](JF BBQ Timer/ContentView.swift) (good news: it already uses an
  absolute `targetDate` ~line 2198 and `target.timeIntervalSinceNow` ~line 2324).
- **What:** The countdown/elapsed math is woven into view-model objects that use live
  `Timer`s and the real wall clock, so testing it means running the whole app.
- **Why it matters:** This is *why* "testing was hard." It also matches a rule in
  `CLAUDE.md`: time math must be pure, testable functions with an injectable `now`.
- **What to do:** Pull the math into small free functions like
  `func remaining(at now: Date, finishingAt end: Date) -> TimeInterval`. The views call
  these; tests call them with a fake `now`.
- **Effort:** Medium · **Risk:** Low (extraction, behavior preserved).

### 2.2 Write the first real unit tests
- **Where:** [`JF BBQ TimerTests/`](JF BBQ TimerTests) — currently just empty 17-line templates.
- **What:** No real tests exist yet.
- **Why it matters:** Tests let us change the watch sync and refactors with confidence
  instead of hoping.
- **What to do:** Cover the new pure functions: countdown, "extend by N," reaching zero,
  pause/resume, preset application. Fast, no simulator UI needed.
- **Effort:** Medium · **Risk:** None (additive).

---

## Phase 3 — Fix watch sync the right way ⭐ (the main pain point)

### 3.1 Send a finish **time**, not a countdown **number**
- **Where:** iOS `buildWatchSnapshot()` / `startWatchSyncTimer()` (~line 1692) in
  [`ContentView.swift`](JF BBQ Timer/ContentView.swift); payload shape in
  [`WCSessionManager.swift`](JF BBQ Timer/WCSessionManager.swift); consumed by the watch's
  `effectiveRemaining(...)` (~line 257) in
  [the watch `ContentView.swift`](GrillTime Pro Watch App Watch App/ContentView.swift).
- **What today:** Once per second, the phone sends *"X seconds left, as of now."* The watch
  records when it arrived and runs its own 1-second clock to count down, re-requesting data
  if it drifts more than 5 seconds.
- **Why it breaks:** When the watch sleeps, its clock freezes and the phone's per-second
  sender stops, so the number goes stale → the drift/freeze/jump you've seen. This is the
  "decremented counter" anti-pattern `CLAUDE.md` warns against.
- **What to do:**
  1. Phone sends each running timer's absolute **`endDate`** (it already computes this).
  2. Watch shows it with Apple's **`Text(timerInterval:)`**, which the system keeps accurate
     **even while asleep or in Always-On dim mode** — no manual ticker, no drift, no retries.
  3. Send updates **on state change** (start/pause/reset/extend), not every second.
- **Why it's the right fix:** Removes the watch's manual clock, the 5-second drift hack, and
  the per-second message spam — and it's correct through sleep.
- **Effort:** Medium · **Risk:** Medium (core behavior — lean on Phase 2 tests).

### 3.2 Make the phone↔watch messages type-safe
- **Where:** [`WCSessionManager.swift`](JF BBQ Timer/WCSessionManager.swift) — uses
  `[String: Any]` dictionaries and `NotificationCenter` string names
  (`"receivedCommand"`, `"receivedTimersSnapshot"`, `"receivedAlert"`).
- **Why it matters:** "Stringly-typed" messaging is easy to typo and the compiler can't
  catch mistakes — a likely source of silent sync bugs.
- **What to do:** Define small `Codable` message types (e.g. `TimerSnapshot`, `WatchCommand`)
  encoded/decoded in one place.
- **Effort:** Medium · **Risk:** Low–Medium (do alongside 3.1).

---

## Phase 4 — Watch UI: use the whole screen
- **Where:** [the watch `ContentView.swift`](GrillTime Pro Watch App Watch App/ContentView.swift).
- **What:** Current layout is compact with small controls; you wanted it to use the full
  display.
- **Why after Phase 3:** The views change shape once the data is finish-time based
  (`Text(timerInterval:)` becomes the centerpiece), so redesign on the new foundation.
- **What to do:** Full-bleed countdown, larger tap targets, clearer running/paused state,
  good Always-On appearance.
- **Effort:** Medium · **Risk:** Low (visual; verified by Jim in Xcode).

---

## Phase 5 — Intentional Liquid Glass / Xcode-26 visual pass
- **Where:** Toolbars/sheets/buttons across both apps.
- **What:** Building against the iOS/watchOS 26 SDK made standard controls adopt the new
  "Liquid Glass" look automatically — the likely cause of "things looked worse after the
  Xcode update."
- **Why it matters:** Right now the new look is happening *by accident*. And the app still
  supports **iOS 15.6**, so glass effects must be switched on only for iOS 26 devices with a
  fallback for older ones.
- **What to do:** Apply glass deliberately via `.glassEffect(...)` where wanted, gated behind
  `if #available(iOS 26, *)`; restore a clean look on the rest. Don't stack glass on glass.
- **Effort:** Medium · **Risk:** Low–Medium (visual; verified in Xcode).

---

## Phase 6 — Onboarding streamline
- **Where:** [`CarouselOnboardingView.swift`](JF BBQ Timer/CarouselOnboardingView.swift)
  (~635 lines) and [`OnboardingView.swift`](JF BBQ Timer/OnboardingView.swift).
- **Status:** Flagged by Jim; **I haven't deep-read these yet** — needs a closer look before
  specifics. The size hint suggests it's grown heavy.
- **What to do (tentative):** Read it, then cut steps/friction and tighten the first-run flow.
- **Effort:** TBD · **Risk:** Low–Medium (affects first impression + the values it seeds
  into `Settings`).

---

## Phase 7 — Bluetooth temperature probe (new feature)
- **Where:** New subsystem; rough draft in
  [`combustion-probe-ble-spec.md`](combustion-probe-ble-spec.md).
- **What:** Integrate a BLE temperature probe (likely Combustion).
- **Why last:** Largest, newest feature — needs CoreBluetooth, background modes, possibly a
  new capability/entitlement (which means Xcode GUI steps for Jim, per `CLAUDE.md`). Build it
  on the cleaned-up, tested foundation rather than the current tangle.
- **Effort:** High · **Risk:** Medium–High (new hardware integration; needs real-device testing).

---

## Notes / open questions
- The two existing spec files (`timer-sync-refactor-spec.md`, `combustion-probe-ble-spec.md`)
  are **rough drafts**; Phases 3 and 7 here supersede/expand them.
- Persistence is **`UserDefaults`** (no Core Data/SwiftData). The integer "0 means unset"
  pattern (`nonZeroOr`) in `JF_BBQ_TimerApp.swift` is fragile — worth revisiting if we touch
  the data model.
- Deployment targets confirmed: **iOS 15.6**, **watchOS 11.0** (built with the iOS/watchOS 26
  SDK). Dependency: **RevenueCat** (SPM 5.31.0) for in-app purchases.
