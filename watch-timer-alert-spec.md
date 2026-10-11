# Spec: Watch shows the timer-done alert by itself

Status: **approved by Jim** (2026-10-11)

## Problem

Jim's report (2026-10-11): a timer counts down to 0:00 on the watch, then the
watch just sits there. No full-screen alert, no buzz. The red notification
shows on the watch "much later". Not silent mode, not Do Not Disturb.

Causes found in the code:

1. **The watch never decides by itself that a timer is done.** It shows the
   red full-screen alert only when the phone sends `["action": "alert",
   "phase": "start"]`. The phone sends that from
   `.onChange(of: alertState.isPresented)` in `ContentView.swift`, which only
   runs when the phone app is awake and frontmost. A locked or backgrounded
   phone app is suspended (its only background mode is `bluetooth-central`),
   so no message is sent.
2. **The phone's notification is hidden while the watch app is open.** iOS
   mirrors the phone's `timer-<uuid>` notification to the watch. When our
   watch app is frontmost, watchOS hands that notification to the app's
   `UNUserNotificationCenterDelegate`. The watch app has no delegate, so
   the notification is not shown at all.
3. **The Haptics setting blocks the watch alert.** The phone sets
   `alertState.isPresented = true` only when `settings.hapticsEnabled` is
   true, so with Haptics off the watch never gets the "start" message.

## Goal

When a running timer reaches zero, the watch shows the red full-screen alert
and buzzes on time, whatever state the phone is in. Only one alert at a time.
Dismissing on either device stops it on both.

## Behaviour rules

### A. Watch-side completion (main fix)

- The watch already holds each running timer's absolute `endDate`. When the
  watch's ticker sees `now >= endDate` for a running row, the watch shows the
  full-screen alert itself and plays `.notification` haptic, as today.
- The message is **name-first**, matching the phone: "Ribeye timer is
  complete" (reuse `AnnouncementMessage` if it compiles in the watch target;
  if not, a small pure builder in `WCSessionManager.swift`).
- **Fire once** per run: remember the `(timerId, endDate)` pair that already
  alerted. A new snapshot with the same pair must not re-alert; a new run
  (new `endDate`) can alert again. Pure + unit-tested (`WatchCompletionLatch`
  or similar, in `WCSessionManager.swift`, injectable `now`).
- **On wake:** when the watch app becomes active and a row's `endDate` has
  passed **within the last 10 minutes** and that pair has not alerted, show
  the alert. Older than 10 minutes: no alert. This is a "you missed it"
  catch-up, not a stale surprise hours later.
- The alert remembers **which timer** it is for. Tapping it sends
  `ackAlert` with **that** timer's id. Today it sends `selectedTimerId`,
  which is wrong when the user swiped to another page (same class of bug as
  PR #67).
- If the phone's "alert start" message arrives while the watch alert already
  shows, nothing changes (no second buzz). The phone's "stop" message still
  dismisses it.
- Respect the Watch Premium gate: no alert on a locked (free) watch app.

### B. Show the phone's notification when the watch app is open

- Add a `UNUserNotificationCenterDelegate` to the watch app (set in the app's
  `init`, alongside the existing authorization request).
- `willPresent` for an identifier starting `timer-`: show the in-app
  full-screen alert for that timer id (same latch as A, so no double), and
  return `[.sound]` so the user's alert sound plays. No banner — the
  full-screen alert is the visual.
- Any other identifier: return `[]` (same as today — keeps probe alerts
  unchanged, they have their own green banner).
- Preheat: if the phone's preheat notification has a known identifier, treat
  it like `timer-` with the message "Preheat Complete". If not, leave it out.

### C. Phone: send the watch alert regardless of Haptics

- The phone's watch "alert start" message no longer depends on
  `hapticsEnabled`. Send it from the completion path itself, not from the
  phone's on-screen alert flag. The phone's own on-screen alert and haptics
  behaviour stay **exactly** as today.
- Include `timerId` in the message so the watch latch can match it.

## Out of scope

- Watch app closed + wrist down + phone unlocked: the watch can still miss
  the alert. Fixing that needs the watch to post its own local notification,
  which risks double alerts with the mirrored phone notification. Later.
- Any change to the phone's own alert, sounds, or voice announcement.

## Done when

- Unit tests for the fire-once latch and the 10-minute catch-up window
  (edges: 9:59, 10:00, 10:01; same pair twice; new endDate after ack).
- iOS + watch builds pass; full iOS unit test run passes (serial).
- Watch simulator check: start a short (≈10 s) timer on the watch with the
  phone app in the background or not running → the watch shows the red
  alert at zero.
- Jim checks on real devices, phone **locked** in a pocket:
  1. Watch app open → red alert + buzz at zero.
  2. Tap to dismiss → phone alert / sound stops too.
  3. Haptics off on the phone → watch still alerts.
