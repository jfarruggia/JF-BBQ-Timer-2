# Spec: Probe Target Temperature + Carryover Prediction (V2 probe round 2)

**Status:** IMPLEMENTED (3A–3F merged 2026-07-11, PRs #6–#11) — on-device
verification pass pending; see TODO.md for the checklist.
**Depends on:** the shipped probe foundation (2A–2E in TODO.md)
**Source of truth:** Combustion Probe BLE spec
`https://github.com/combustion-inc/combustion-documentation/blob/main/probe_ble_specification.rst`
— cross-check every bit layout against `combustion-ios-ble` before trusting it, same
rule as the first probe spec.

**Scope:** (1) the app's first host→probe **UART command layer**, (2) a per-cook
**target temperature** set on the timer card, which is sent to the probe as its
prediction set point, (3) **removal + resting ("carryover") prediction** UI and
state-transition alerts, (4) a phone-side **target-crossed alert** as a safety net,
(5) **low-battery and overheat badges**.

**Out of scope:** SafeCook / Food Safe (parked by decision 2026-07-11), MeatNet, DFU,
temperature history graph / log backfill, multiple probes, Instant Read UI, and the
probe-side alarm commands (`0x0B` — we alert phone-side instead; the phone owns the
connection and the notification path, and phone-side threshold math is unit-testable).

---

## Decisions already made (don't re-open)

- **Target is per-cook, set on the timer card** — the cook the probe is attached to
  shows the probe strip; the target belongs right there, not in the probe sheet.
- **One target field drives everything:** the probe's prediction set point, the
  carryover flow, and the phone-side crossing alert. No separate "alarm temp".
- **Units:** the user types the target in their display unit (°F/°C per the existing
  `TemperatureUnit` setting); it is **stored and transmitted in °C**, converted at
  display only — same pattern as the readings.

## The UART command layer (new plumbing)

So far the app only *listens* (Probe Status notifications). This round adds *talking*:
writes to the Nordic UART service already listed in the first spec (RX
`6E400002-…`, TX notify `6E400003-…`).

**Request framing** (transcribed from the Combustion spec, verify against the
reference lib):

- Header: sync bytes `0xCA 0xFE` (2) → CRC (2) → message type (1) → payload
  length (1), then the payload.
- CRC: **CRC-16-CCITT, polynomial `0x1021`, initial value `0xFFFF`**, computed over
  message type + payload length + payload bytes.
- Response header: sync (2) → CRC (2) → message type (1) → **success flag** (1) →
  payload length (1), then payload.

**Set Prediction command:**

- Message type **`0x05`**; request payload is one `uint16` packing:
  bits 1–10 = set point (`°C = raw × 0.1`, so 0–102.3 °C — plenty for any meat core),
  bits 11–12 = prediction mode. **Verify the bit order / endianness of this uint16
  against `combustion-ios-ble` before shipping** — this is the same class of gotcha
  as the byte-reversed temperature block.
- Prediction mode enum: `0` None, `1` Time to Removal, **`2` Removal and Resting**
  (what we send when a target is set), `3` reserved.
- Clearing the target sends mode `0` (None) with set point 0.
- Response has no payload; check the success flag, retry once on failure or timeout
  (~2 s), then surface a non-blocking "couldn't set target on probe" note. The
  phone-side crossing alert works regardless, so a failed write degrades gracefully.

**Architecture:** extend the `ProbeCentral` protocol with `write(_:)` +
TX-notification callbacks so `ProbeBLEManager` stays unit-testable with a fake
central. Framing/CRC/encode/decode are **pure functions with fixture tests**
(hand-computed CRC vectors + at least one real captured request/response pair once
hardware-verified). A tiny request queue (one in-flight command, FIFO) is enough —
we send at most a handful of commands per cook.

**Re-send rules:** the set point must be (re)sent when — a target is set or changed,
a probe (re)connects while an attached cook has a target, or the attach moves to a
different cook. On detach/clear, send mode None.

## Target temperature on the timer card

- The probe strip on the attached cook's card gains a **target facet**: shows
  `→ 203°` when set, and a subtle "Set target" affordance when not. Tapping opens a
  small themed sheet (reuse the immersive-glass language) with a temperature entry —
  quick-pick common doneness values + free entry.
- **Persistence:** the target is part of the cook, so it lives on the timer model in
  `Settings.additionalTimers` (JSON-encoded already; additive optional field — old
  saved data must decode fine without it). Cleared on Reset of that cook.
- Pre-iOS 26 fallback styling per the usual gating.

## Carryover ("Removal and Resting") flow

With mode 2 set, the probe computes a **pull temperature below the target** so that
resting carryover coasts the core up to the target. The status notification we
already decode carries Prediction State + Prediction Type (`1` Removal, `2` Resting)
+ prediction seconds + estimated core.

UI on the probe strip (phases derived from decoded state — pure mapping function,
unit-tested):

1. **Predicting removal:** "Pull at 195° · ~40 min" (pull temp = the set point field
   the probe reports back while type = Removal; countdown = the existing drifting
   `predictedReadyDate` treatment).
2. **Pull now:** Prediction State hits **Removal Prediction Done** → strip flips to
   "Pull now"; fire the alert (below).
3. **Resting:** type switches to Resting → "Resting · target 203°" with the resting
   countdown while the probe tracks carryover.
4. **Done:** resting prediction completes → "Ready". **The exact done signal for the
   resting phase must be transcribed from the reference lib** (state vs. estimated
   core reaching set point) — pin it with a fixture, don't guess.

**Alerts are state-driven, never estimate-driven** (rule carried over from the first
spec): local notification + existing in-app alert path + watch signal on **(a) Pull
now** and **(b) resting Done**. No notification scheduled in advance for a predicted
time.

## Phone-side target-crossed alert (safety net)

Independent of prediction: when the actual decoded core temp crosses the cook's
target, fire once. This covers users who ignore the carryover flow, probes whose
prediction never converges, and the failed-write case.

- **Edge-triggered, fire-once latch** per cook per target: arms when a target is set
  (or changed), fires on the first reading ≥ target **after having seen at least one
  reading below it** (guards against attaching an already-hot probe), stays latched
  until target change or Reset. Small hysteresis (re-arm only if temp falls ≥ 2 °C
  below target) guards noisy readings.
- Pure function `TargetCrossingLatch` with injected readings — **unit-tested** (cross,
  noise wiggle at the boundary, already-above on arm, target change mid-cook,
  disconnect/reconnect gap).
- Fires: local notification (works backgrounded — phone has `bluetooth-central`) +
  the existing alert/haptic path + watch via the existing alert route.
- Suppression: if the carryover "Pull now" alert already fired for this cook, the
  crossing alert is redundant chatter — one audible alert per event, so the latch
  still fires the *notification text* as "Target reached" only if no removal alert
  preceded it (decide final copy in build).

## Battery + overheat badges

- **Low battery** (already decoded): small badge on the header Probe chip + the probe
  strip; one-shot local notification per connection session ("Probe battery low").
- **Overheat:** decode the Overheating Sensors byte we currently skip (1 byte,
  bit-per-sensor, LSB = T1 … MSB = T8, `1` = overheating). Any set bit → warning
  badge + one-shot notification ("Probe overheating — check placement"). Decoder is
  a pure function + fixture tests.

## Watch

Additive keys on the existing `"probe"` wire payload (backward compatible — old
watch builds ignore them): target °C, prediction phase, pull temp, battery-low,
overheat. Watch probe page shows target + phase line; alerts arrive via the existing
alert path, no watch-side logic.

## Manual Xcode steps

None anticipated — no new capabilities, entitlements, or targets. If anything turns
out to need one, stop and write the click-path per the hard rules.

## Implementation order (one PR per step, build-verified, squash-merged)

1. **3A — UART plumbing:** framing + CRC pure functions w/ fixtures; `ProbeCentral`
   write/TX; request queue; SetPrediction encode/decode + tests.
2. **3B — target on the cook:** timer-model field + persistence, card UI + entry
   sheet, send-on-set/reconnect/attach rules.
3. **3C — carryover flow:** phase mapping + strip UI + state-transition alerts.
4. **3D — crossing-alert latch** + notification/alert wiring.
5. **3E — battery/overheat** decode + badges + one-shot notifications.
6. **3F — watch payload + watch UI** additions.
7. Hardware verification checklist for Jim (set target from card → Combustion app
   shows same set point; pull-now alert on a real cook; crossing alert with
   prediction off; badge checks).
