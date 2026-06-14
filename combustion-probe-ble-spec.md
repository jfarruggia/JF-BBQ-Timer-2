# Spec: Combustion Predictive Probe BLE Integration

**Status:** Ready for implementation (do the timer-sync refactor first)
**Source of truth:** Combustion Inc. Predictive Probe BLE Specification
`https://github.com/combustion-inc/combustion-documentation/blob/main/probe_ble_specification.rst`
(spec is marked DRAFT by Combustion — treat field layouts as authoritative but verify against their open-source reference, see below)

**Scope:** Connect to a Combustion Predictive Probe, read live temperatures + the probe's cook prediction, surface them on phone and watch. **Out of scope:** MeatNet (Display / Booster / Range Extender repeater network), firmware update (DFU), Food Safe UI, and any project-file/capability changes (those are manual Xcode steps — see below).

---

## Reference implementation

Before writing the byte-parsing by hand, check the `combustion-inc` GitHub org for their **open-source Swift / iOS BLE library**. If it exists and is usable, the cleanest path may be to depend on it or to use it as the canonical reference to validate our parser against. Either way, **do not guess bit layouts** — transcribe from the spec and cross-check against their parser. Report what you find before implementing.

## Key architectural decisions

1. **The iPhone owns the BLE connection.** The watch app is a companion; it must not open its own CoreBluetooth connection to the probe. The phone connects, decodes, and pushes a small struct (temps + prediction + battery + status) to the watch over the existing `WCSession`. This reuses the channel from the timer-sync work and keeps watch battery sane.
2. **The probe's prediction is an estimate, not a countdown.** See "Prediction vs. fixed timers" below — this is the main design subtlety.
3. **Two ways to get temperature:** the probe broadcasts temps in its **advertising packet** (no connection needed, good for a quick glance / device picker), and streams full status via **notifications** once connected. Implement connected status first; advertising-parse is a nice-to-have.

---

## What the device is

A single probe has **8 physical thermistors (T1–T8)**, T1 at the tip. The probe also computes **virtual sensors** — which physical thermistor currently represents the food's **Core**, **Surface**, and **Ambient**. Most UIs should show Core / Surface / Ambient (the meaningful values) and optionally expose the raw T1–T8.

## GATT services & characteristics (transcribe exactly)

**Device Information Service** — `0x180A` (standard). Read manufacturer, model, serial, hardware rev, firmware rev (standard `0x2A29/2A24/2A25/2A27/2A26` characteristics).

**Probe Status Service** — `00000100-CAAB-3792-3D44-97AE51C1407A`
- **Probe Status characteristic** — `00000101-CAAB-3792-3D44-97AE51C1407A` — properties Read + **Notify**. This is the primary data feed; subscribe to notifications. The probe pushes a status update every measurement.

**UART Service (Nordic NUS)** — `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` — Write (host → probe commands)
- **TX** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` — Read/Notify (probe → host responses)

The UART service carries request/response commands (set alarms, read logs, set prediction, etc.). For a first integration we only **need the Probe Status notifications**; UART commands are phase 2.

## Probe Status notification payload (the thing to decode first)

Fields in order (see spec for exact byte counts): Log Range (8) → **Current Raw Temperature Data (13)** → **Mode/ID (1)** → **Battery Status + Virtual Sensors (1)** → **Prediction Status (7)** → Food Safe Data (10) → Food Safe Status (8) → Overheating Sensors (1) → Thermometer Preferences (1) → High Alarm array (22) → Low Alarm array (22).

For v1 we care about the **bolded** fields. Decode the rest into a struct opportunistically but don't build UI for them yet.

### Decode formulas (implement as pure functions + unit tests)

- **Raw Temperature Data** = 13 bytes packing **8 × 13-bit** thermistor readings (little-endian bit packing across byte boundaries — this is the fiddly part; write test vectors). Each:
  `temperatureC = (raw13 × 0.05) − 20` , valid range −20 °C … 369 °C.
  In **Instant Read** mode only T1 is populated; T2–T8 read 0.
- **Mode/ID** (1 byte): bits 1–2 = Mode (`0` Normal, `1` Instant Read, `3` Error); bits 3–5 = Color; bits 6–8 = Probe ID (0 → "ID 1", etc.).
- **Battery + Virtual Sensors** (1 byte): bit 1 = Battery (`0` OK / `1` Low); bits 2–8 = packed virtual-sensor enums (Core 3-bit, Surface 2-bit, Ambient 2-bit) mapping to which physical T-sensor is core/surface/ambient.
- **Prediction Status** (7 bytes): Prediction State (4-bit enum: 0 Not Inserted, 1 Inserted, 2 Warming, 3 Predicting, 4 Removal Prediction Done, 15 Unknown), Prediction Mode (2-bit), Prediction Type (2-bit), Set Point Temp (10-bit, `°C = raw × 0.1`), Heat Start Temp (10-bit, `°C = raw × 0.1`), **Prediction Value Seconds (17-bit = seconds-to-event from now)**, Estimated Core Temp (11-bit, `°C = (raw × 0.1) − 20`).
  - Progress bar: `percentToRemoval = (estCore − heatStart) / (setPoint − heatStart)`.

## Prediction vs. fixed timers (important — ties into the timer-sync spec)

The probe's "Prediction Value Seconds" is a **continuously re-estimated** time-to-removal, not a fixed end time. Each status notification gives a fresh "N seconds from now." Treat it like this:

- Convert each update to `predictedReadyDate = now + predictionValueSeconds`, and let the UI show a live countdown to that date (same `Text(timerInterval:)` technique as the timer-sync spec). But **expect the date to move** as cooking conditions change — do not lock it in.
- **Do not** schedule a hard local notification far in advance for the predicted time the way you would for a user-set fixed timer, because the estimate drifts. Instead, fire a notification on the meaningful **state transition** (e.g. Prediction State → "Removal Prediction Done", or Estimated Core crossing the set point / a user-set alarm). State-driven alerts are stable; estimate-driven ones would fire early/late and re-fire as the number wiggles.
- A user-set fixed timer (the other spec) and the probe's prediction are **two different features** that can coexist on screen. Keep them as separate models.

## CoreBluetooth implementation notes

- Use a `CBCentralManager`. **Scan** by filtering for the Probe Status Service UUID (advertised in the scan response) and/or manufacturer data with Bluetooth Vendor ID `0x09C7`. Present discovered probes in a picker (use Mode/ID color + serial to label them).
- On connect: discover services, discover the Probe Status characteristic, `setNotifyValue(true)`, decode each notification into the domain struct, publish to the app's state, and forward a compact version to the watch via `WCSession`.
- The probe supports up to **3 simultaneous connections** and expects a connection interval of ~400–500 ms in normal mode (tighter in Instant Read). Don't fight the defaults.
- **Background operation:** to keep receiving notifications while the app is backgrounded (likely, during a long cook), implement CoreBluetooth **state preservation/restoration** and handle reconnection on disconnect (probe may drop out of range). This pairs with the suspension-resilience theme from the timer work.

## Manual Xcode steps (DO NOT edit project files for these — write them out for Jim)

These touch capabilities / Info.plist / entitlements and must be done by hand in Xcode:

1. Add **`NSBluetoothAlwaysUsageDescription`** to the iOS app's Info.plist with a user-facing reason string.
2. Enable the **Background Modes → Uses Bluetooth LE accessories** (`bluetooth-central`) capability on the iOS target (needed for background notifications + state restoration).
3. Confirm the watch target needs **no** BLE capability (it shouldn't — phone owns the connection).

When implementation reaches a point that needs any of these, **stop and hand Jim the exact click-path** rather than modifying `project.pbxproj` or entitlements files.

## Testing requirements

- **Bit-unpacking is the highest-risk code.** Write unit tests with **known sample byte arrays → expected decoded values** for: 8-thermistor raw temp block, Mode/ID, Battery+Virtual sensors, and Prediction Status. Capture a few real notification payloads from the device (log the raw `Data`) and pin them as fixtures.
- Test the decode functions with `now` injected so predicted-date math is deterministic.
- CoreBluetooth itself can't be exercised in `xcodebuild test`; wrap the central manager behind a protocol so the decode/state layer is testable without hardware. Hardware verification (scan, connect, live temps, background reconnect, watch mirroring) is a manual checklist for Jim.

## Suggested implementation order

1. Check for / evaluate Combustion's open-source Swift BLE library; report recommendation (depend on it vs. parse ourselves).
2. Define domain models: `ProbeReading` (core/surface/ambient + raw T1–T8 + mode + battery) and `ProbePrediction` (state, predicted seconds, est. core, set point, progress).
3. Implement + unit-test the decoders for Raw Temperature Data, Mode/ID, Battery/Virtual Sensors, Prediction Status with fixtures.
4. CoreBluetooth central: scan → picker → connect → subscribe → publish readings (foreground first).
5. Forward compact readings to the watch over `WCSession`; render core temp + (drifting) predicted-ready countdown on both.
6. Add background state restoration + reconnection.
7. Hand Jim the manual Xcode capability steps; manual hardware verification pass.
8. (Phase 2, separate spec) UART commands: high/low temp alarms (`0x0B`), set prediction (`0x05`), log backfill (`0x04`).
