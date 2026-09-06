# Spec: Probe cook alerts on the Apple Watch

**Problem:** the probe's "act now" moments (pull now / target reached / resting
done) alert on the iPhone only. During a real cook (2026-09-06, build 13) the
watch stayed silent, because the green-card spec put the watch out of scope and
iOS only mirrors a phone notification to the watch when the phone is locked.

**Goal:** when a probe cook moment fires, the watch buzzes and shows a clear
green card, the same three moments the phone shows.

## Wire

- New WC route `action == "probeEvent"`, sent from `handleProbeCookEvent` in
  `ContentView` alongside the existing local notification.
- Payload (property-list safe): `action`, `event` (raw string), `title`,
  `tempText` (optional), `cookName` (optional).
- Delivery: `transferUserInfo` — queued and guaranteed, so a suspended or
  out-of-range watch still gets it on wake. (Readings use live/context because
  they are ephemeral; an alert must not be dropped.)
- `WCSessionManager` routes `"probeEvent"` to a `receivedProbeEvent`
  NotificationCenter post, next to the existing `"probe"` routing. The shared
  wire helper (encode + decode) lives in `WCSessionManager.swift` — the watch
  target only compiles selected files, so a new file would be iOS-only.

## Watch behaviour

- `WatchProbeModel` observes `receivedProbeEvent` and publishes a
  `probeAlert` value (title + optional temp + optional cook name).
- `ContentView` shows a **green** full-screen banner, mirroring the existing red
  `alertBanner`: thermometer symbol, cook name, big temp, event line, "Tap to
  dismiss". Tap clears it locally (no command back to the phone — the phone
  overlay is dismissed on the phone).
- Haptic `WKInterfaceDevice.current().play(.notification)` once when it appears,
  same as the timer alert.
- Only `pullNow` / `targetReached` / `restingDone`. `batteryLow` /
  `overheating` are not sent — warnings, not act-now.

## No double alerts

The phone stamps each payload with `phoneForeground` — whether the iPhone app
was frontmost when the moment fired. iOS only relays a phone notification to
the wrist while the phone is **locked**, so the watch uses that flag to decide:

| Phone frontmost | Watch app on screen | Watch does |
|---|---|---|
| yes | yes | green card + haptic |
| yes | no  | its own local notification (nothing else would alert) |
| no  | yes | green card + haptic (the relay also lands) |
| no  | no  | nothing — the relayed phone banner alerts the wrist |

So exactly one alert reaches the wrist per moment.

## Out of scope

- Sounds on the watch.
- Any change to the phone overlay, notifications, or the timers snapshot path.

## Tests

- Pure encode/decode round-trip for the `probeEvent` wire dict (iOS test
  target, next to the existing probe sync tests).
- Event filter: only the three act-now events produce a dict.
