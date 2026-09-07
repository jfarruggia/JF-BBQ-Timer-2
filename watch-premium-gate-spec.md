# Spec: Apple Watch app is a Premium feature

**Decision (2026-09-07):** the whole Watch app is behind the Premium unlock at
V2 launch. Not a split ("see timers free, control them paid") — that gate would
read as a broken watch, not a paywall. Reasoning recorded in TODO.md under
"Shipping V2". The short version: giving the Watch away is a one-way door, and
after the $150 probe it is the only Premium feature with broad appeal.

**Problem:** the Watch target has no idea Premium exists (zero references). It
mirrors whatever timers the phone sends and can start / restart them from the
wrist. A free user who installs V2 gets the full Watch app.

**Goal:** a free user's watch shows one friendly locked screen. A paying user's
watch is unchanged. Flipping Premium on the phone flips the watch within a
second, no relaunch. Nothing on a locked watch looks broken or does nothing.

**Design rule:** *the gate lives on the phone.* The phone is the source of truth
for timers; it becomes the source of truth for access too. The watch never
decides — it only displays what the phone told it. This keeps the fragile
surface (sync, suspension, complications) out of the decision.

---

## Wire

### 1. Snapshot gains one key: `premium`

`buildWatchSnapshot()` in `ContentView.swift` (iOS, ~line 1240) currently
returns `["timers": rows]`. It now routes through a pure helper and returns:

| `isPremiumUser` | Snapshot sent to the watch |
|---|---|
| `true`  | `["timers": rows, "premium": true]` — exactly today's payload plus the flag |
| `false` | `["timers": [], "premium": false]` |

Sending an **empty `timers` array** when locked is deliberate, not just the
flag. It is defence in depth: even if a watch build mishandles the flag there
is nothing to show, nothing to control, and the complication has nothing to
display. It also means the 1-second sync timer goes quiet for free users — the
snapshot never changes, so `lastSnapshot` equality short-circuits every tick.

Additive key. Note there are no "older watch builds" to worry about: V2 is the
first release that ships a Watch app at all, so every phone that can talk to
this watch sends the key.

### 2. Pure helpers, shared file, iOS-unit-tested

All of these live in **`WCSessionManager.swift`** (the watch target compiles
only selected files; a new file in the app folder would be iOS-only).

```swift
enum WatchPremiumGate {
    static let key = "premium"

    /// Phone side. Builds the wire snapshot from the already-built rows.
    static func snapshot(rows: [[String: Any]], premium: Bool) -> [String: Any]

    /// Watch side. Reads the flag off an incoming snapshot.
    /// A MISSING key decodes as `true` — fail open. A bug that drops the key
    /// must never lock out someone who paid; the phone's empty-timers rule is
    /// the real gate, and it does not depend on this decode.
    static func isUnlocked(_ snapshot: [String: Any]) -> Bool

    /// Phone side backstop. Which wrist commands does a locked phone honour?
    /// Only `requestSnapshot` (so a locked watch can still ask "am I locked?").
    static func allowsWristCommand(_ action: String, premium: Bool) -> Bool
}
```

### 3. Phone stops talking to a locked wrist

- **Commands** — in the `receivedCommand` observer (`ContentView.swift` ~1054),
  guard with `allowsWristCommand` before the `switch`. When it returns false:
  log, `sendWatchSnapshotImmediately()` (so the watch re-learns it is locked),
  and skip the switch. `requestSnapshot` still works and returns the locked
  snapshot.
- **Alerts** — the two `sendCommand(["action": "alert", …])` sites
  (`ContentView.swift` 1138 and 1150, timer finished / preheat complete) are
  wrapped in `if settings.isPremiumUser`. A free user's wrist gets no buzz for a
  phone timer. Phone-side alerting is untouched.
- **Probe** — nothing to do. The probe cannot connect without Premium
  (`ContentView.swift` ~180), so `probe` / `probeEvent` traffic never starts.

### 4. Premium change pushes a fresh snapshot at once

Add to `ContentView` (iOS), next to the existing `.onChange(of:
settings.additionalTimers)`:

```swift
.onChange(of: settings.isPremiumUser) { _ in sendWatchSnapshotImmediately() }
```

The 1-second sync timer would catch it anyway (the snapshot differs), but the
explicit push covers purchase, restore, and the Debug override toggle without
relying on the timer being live. Same iOS-14-style `onChange` form the file
already uses.

---

## Watch behaviour

### State

`WatchTimersModel` gains one published value:

```swift
enum WatchAccess { case unknown, locked, unlocked }
@Published var access: WatchAccess = .unknown
```

Set on **every** snapshot receipt (`receivedTimersSnapshot` observer,
`ContentView.swift` watch ~759) from `WatchPremiumGate.isUnlocked(dict)`. It is
set *before* the timers array is parsed, so the two publish in the same run
loop turn and the UI never shows timers with a stale access value.

`.unknown` means "have not heard from the phone yet" and is the state at
launch. It is never set from a snapshot — a snapshot always resolves it.

### Screens (`mainContent`, watch ~162)

| `access` | Shows |
|---|---|
| `.unknown` | existing `emptyState` — "No timers yet / Open the iPhone app to sync timers." + Refresh. Unchanged. |
| `.locked` | **new `lockedState`** (below) |
| `.unlocked` | today's behaviour: `timersPager`, or `emptyState` if `timers` is empty (cannot happen in practice — `allTimers` always holds the two built-in timers) |

Both alert banner overlays stay attached to every branch as they are today.

### The locked screen

Same skeleton as `emptyState` (VStack, centred, padding, ember background),
so the two screens feel like siblings:

- `Image(systemName: "lock.fill")`, 32pt, `.gray` — the same lock glyph the
  phone's Probe chip uses for a locked feature. Not the crown (that badge means
  "premium sound" on the phone).
- Headline: **"Unlock on iPhone"** (`.headline`)
- Body (`.footnote`, `.secondary`, centred):
  **"The Apple Watch app is part of Grill Time Pro Premium. Open Settings on
  your iPhone to upgrade."**
- One button: **"Refresh"** — `.borderedProminent`, sends `requestSnapshot`,
  exactly like the empty state's button. It is the only control on the screen
  and it does something real (asks the phone again). No "Upgrade" button: the
  watch cannot complete a purchase, and a button that just says "go to your
  phone" is the do-nothing tap we are avoiding.

No countdown, no timer names, no presets. Nothing that looks like a timer.

### Initial request loop (watch ~71–96)

The retry loop currently stops when `model.timers` is non-empty. It now also
stops when `model.access != .unknown`. Otherwise a locked watch would fire its
5 retries at a phone that keeps (correctly) answering "locked".

### Selection

When `access` becomes `.locked`, `selectedTimerId` is cleared. It is re-seeded
from `timers.first` on the next unlocked snapshot by the existing
`onChange(of: model.timers)` logic — no new code, just make sure the clear
happens so a stale id cannot point at a page that no longer exists.

### Complication

`ComplicationDataSource` gains `private(set) var isLocked = false`, set from
the model alongside `updateSoonestTimer`. `createEmptyTemplate` shows:

| | header | body |
|---|---|---|
| locked | `GrillTime` | `Unlock on iPhone` |
| unlocked, no timers | `GrillTime` | `No timers` (unchanged) |

Because a locked snapshot carries no timers, `soonestTimer` is already `nil`
and the empty template is the only path — this is a copy change, not logic.
`getLocalizableSampleTemplate` (the complication picker preview) stays
"Ribeye 5:30".

---

## Phone: tell people

- `CustomPaywallView.swift` feature list (~line 67): add
  **"Apple Watch app — see and control your timers from your wrist"** as the
  **first** row. The probe row moves to last. Per the pricing discussion: lead
  with the feature the most people can use; the probe needs $150 of hardware.
- The Premium banner in Settings and the "Thank you" section need no change.
- App Store description: the Watch app must be described as a Premium feature.
  (Metadata, not code — `AppStoreMetadata.md`.)

---

## Tests

New `JF BBQ TimerTests/WatchPremiumGateTests.swift` (Swift Testing; the
synced test folder picks it up, `project.pbxproj` untouched):

- `snapshot(rows:premium: true)` == rows + `premium: true`; rows untouched.
- `snapshot(rows:premium: false)` has an empty `timers` array and
  `premium: false`, **regardless of rows passed in**.
- `isUnlocked` — `true` → true; `false` → false; **missing key → true**;
  wrong type (e.g. `"yes"`) → true.
- `allowsWristCommand` — premium true: every action allowed. premium false:
  `requestSnapshot` only; `applyPreset1`, `applyPreset2`, `toggleRun`,
  `ackAlert`, and an unknown string all refused.
- Round trip: `isUnlocked(snapshot(rows:premium: p)) == p` for both values.

No watch-side tests (the watch test target is UI-only today). The watch's only
logic is a three-way switch on a value produced by the tested helper.

---

## Test plan on TestFlight (uses the Debug ▸ Override Premium toggle)

1. **Override ON, Status = Free.** Watch shows the locked screen. Complication
   shows "Unlock on iPhone". Tap Refresh — still locked. Start and finish a
   timer on the phone — the wrist does **not** buzz.
2. **Flip Status to Paid on the phone.** Watch shows timers within ~1 s. No
   relaunch. Complication updates once a timer runs.
3. **Start a timer, then flip back to Free mid-cook.** Watch drops to the locked
   screen. The phone timer keeps running and still alerts on the phone. No
   crash on either side.
4. **Override OFF.** Watch state matches the real purchase state.
5. **Cold start order.** Kill both apps. Open the watch first: "Open the iPhone
   app to sync" (unknown). Open the phone: watch resolves to locked or timers
   correctly.
6. **Lock screen wake.** With the watch locked, lower and raise the wrist —
   still the locked screen, no flash of timers.

---

## Out of scope

- A free trial of the Watch app (time-limited unlock). Honest pattern, but it
  is a subtractive gate with date-tracking on both sides. Not for a
  one-month-out ship.
- Gating complications separately from the app.
- Any change to what Premium gates on the phone.
- The `canAddMoreTimers()` cap (`Settings.swift` ~326) says **10** timers for
  Premium while the paywall says **24**. Real discrepancy, separate concern —
  logged in TODO.md.
