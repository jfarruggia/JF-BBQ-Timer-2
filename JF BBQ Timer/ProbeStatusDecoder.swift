// ProbeStatusDecoder.swift
// Grill Time Pro
//
// Pure byte decoders for the Combustion Probe Status notification payload.
// No side effects, no CoreBluetooth, no UI — fully unit-testable.
//
// Payload layout (≥30 bytes):
//   [0..<4]   min log sequence (UInt32 LE)
//   [4..<8]   max log sequence (UInt32 LE)
//   [8..<21]  temperature block (13 bytes → 8 × 13-bit readings)
//   [21]      ModeId byte
//   [22]      Battery + Virtual Sensors byte
//   [23..<30] Prediction Status (7 bytes)

import Foundation

// MARK: - Temperature block decoder

extension ProbeTemperatures {

    /// Decodes 8 thermistor temperatures from the 13-byte raw temperature block.
    ///
    /// Mirrors the reference library's `fromRawData`: first reverses the 13 wire bytes,
    /// then applies the `fromReversed` bit-extraction algorithm.  The byte reversal is
    /// required because the Probe Status BLE notification sends the temperature block in
    /// the opposite byte order from what the bit-math expects.
    ///
    /// Each raw 13-bit value is converted with `Double(raw) * 0.05 - 20.0`.
    ///
    /// - Parameter block: Exactly 13 bytes in wire order (as received from the notification).
    /// - Returns: nil if `block.count != 13`.
    static func decode(block rawBlock: [UInt8]) -> ProbeTemperatures? {
        guard rawBlock.count == 13 else { return nil }

        // Reverse the wire bytes before bit-extraction, mirroring combustion-ios-ble
        // `fromRawData` which calls `reversed()` before passing to `fromReversed`.
        let bytes = Array(rawBlock.reversed())

        // Unpack 8 × 13-bit values using `insert(at: 0)` reversal so T1 ends at index 0.
        // Each line extracts a 13-bit raw value that spans two or three bytes.
        var rawTemps: [UInt16] = []

        // Line 1 (ends up at index 7 = T8 after all inserts)
        // T8: bits [7:0] of bytes[0] shifted left 5, plus bits [7:3] of bytes[1] shifted right 3
        rawTemps.insert(UInt16(bytes[0]  & 0xFF) <<  5 | UInt16(bytes[1]  & 0xF8) >> 3, at: 0)

        // Line 2 (ends up at index 6 = T7)
        // T7: bits [2:0] of bytes[1] shifted left 10, bits [7:0] of bytes[2] shifted left 2,
        //     plus bits [7:6] of bytes[3] shifted right 6
        rawTemps.insert(UInt16(bytes[1]  & 0x07) << 10 | UInt16(bytes[2]  & 0xFF) << 2 | UInt16(bytes[3]  & 0xC0) >> 6, at: 0)

        // Line 3 (ends up at index 5 = T6)
        // T6: bits [5:0] of bytes[3] shifted left 7, plus bits [7:1] of bytes[4] shifted right 1
        rawTemps.insert(UInt16(bytes[3]  & 0x3F) <<  7 | UInt16(bytes[4]  & 0xFE) >> 1, at: 0)

        // Line 4 (ends up at index 4 = T5)
        // T5: bit [0] of bytes[4] shifted left 12, bits [7:0] of bytes[5] shifted left 4,
        //     plus bits [7:4] of bytes[6] shifted right 4
        rawTemps.insert(UInt16(bytes[4]  & 0x01) << 12 | UInt16(bytes[5]  & 0xFF) << 4 | UInt16(bytes[6]  & 0xF0) >> 4, at: 0)

        // Line 5 (ends up at index 3 = T4)
        // T4: bits [3:0] of bytes[6] shifted left 9, bits [7:0] of bytes[7] shifted left 1,
        //     plus bit [7] of bytes[8] shifted right 7
        rawTemps.insert(UInt16(bytes[6]  & 0x0F) <<  9 | UInt16(bytes[7]  & 0xFF) << 1 | UInt16(bytes[8]  & 0x80) >> 7, at: 0)

        // Line 6 (ends up at index 2 = T3)
        // T3: bits [6:0] of bytes[8] shifted left 6, plus bits [7:2] of bytes[9] shifted right 2
        rawTemps.insert(UInt16(bytes[8]  & 0x7F) <<  6 | UInt16(bytes[9]  & 0xFC) >> 2, at: 0)

        // Line 7 (ends up at index 1 = T2)
        // T2: bits [1:0] of bytes[9] shifted left 11, bits [7:0] of bytes[10] shifted left 3,
        //     plus bits [7:5] of bytes[11] shifted right 5
        rawTemps.insert(UInt16(bytes[9]  & 0x03) << 11 | UInt16(bytes[10] & 0xFF) << 3 | UInt16(bytes[11] & 0xE0) >> 5, at: 0)

        // Line 8 (ends up at index 0 = T1)
        // T1: bits [4:0] of bytes[11] shifted left 8, plus bits [7:0] of bytes[12]
        rawTemps.insert(UInt16(bytes[11] & 0x1F) <<  8 | UInt16(bytes[12] & 0xFF) >> 0, at: 0)

        // Convert each 13-bit raw value to °C: raw × 0.05 − 20.0
        let celsius = rawTemps.map { Double($0) * 0.05 - 20.0 }
        return ProbeTemperatures(values: celsius)
    }
}

// MARK: - ModeId byte decoder

struct DecodedModeId {
    let mode: ProbeMode
    let color: ProbeColor
    let id: ProbeID

    /// Decodes the ModeId byte (byte 21 of the Probe Status payload).
    ///
    /// Layout:
    ///   bits [1:0] = mode  (ProbeMode raw value)
    ///   bits [4:2] = color (ProbeColor raw value)
    ///   bits [7:5] = id    (ProbeID raw value)
    init(byte: UInt8) {
        // mode: bits [1:0]
        let modeRaw  = byte & 0x3
        mode  = ProbeMode(rawValue: modeRaw) ?? .error

        // color: bits [4:2]
        let colorRaw = (byte >> 2) & 0x7
        color = ProbeColor(rawValue: colorRaw) ?? .color1

        // id: bits [7:5]
        let idRaw    = (byte >> 5) & 0x7
        id    = ProbeID(rawValue: idRaw) ?? .id1
    }
}

// MARK: - Battery + Virtual Sensors byte decoder

struct DecodedBatteryVirtualSensors {
    let batteryStatus: BatteryStatus
    let coreSensor: CoreSensor
    let surfaceSensor: SurfaceSensor
    let ambientSensor: AmbientSensor

    /// Decodes the Battery + Virtual Sensors byte (byte 22 of the Probe Status payload).
    ///
    /// Layout:
    ///   bit  [0]   = battery (0 = ok, 1 = low)
    ///   bits [3:1] = core    (maps 0x00–0x05 → T1–T6; default T1 if out of range)
    ///   bits [5:4] = surface (maps 0x00–0x03 → T4–T7; default T4 if out of range)
    ///   bits [7:6] = ambient (maps 0x00–0x03 → T5–T8; default T5 if out of range)
    init(byte: UInt8) {
        // battery: bit [0]
        let battRaw = byte & 0x1
        batteryStatus = BatteryStatus(rawValue: battRaw) ?? .ok

        // Virtual sensor fields live in bits [7:1]; shift right once to get v
        let v = byte >> 1

        // core: bits [2:0] of v → 0x00–0x05 map to T1–T6
        let coreRaw    = v & 0x7
        coreSensor     = CoreSensor(raw: coreRaw) ?? .t1

        // surface: bits [4:3] of v → 0x00–0x03 map to T4–T7
        let surfaceRaw = (v >> 3) & 0x3
        surfaceSensor  = SurfaceSensor(raw: surfaceRaw) ?? .t4

        // ambient: bits [6:5] of v → 0x00–0x03 map to T5–T8
        let ambientRaw = (v >> 5) & 0x3
        ambientSensor  = AmbientSensor(raw: ambientRaw) ?? .t5
    }
}

// MARK: - Prediction Status block decoder

extension ProbePrediction {

    /// Decodes the 7-byte Prediction Status block (bytes 23–29 of the Probe Status payload).
    ///
    /// Layout (0-indexed within the 7-byte block):
    ///   bytes[0] bits [3:0]  = state (PredictionState)
    ///   bytes[0] bits [5:4]  = mode  (PredictionMode)
    ///   bytes[0] bits [7:6]  = type  (PredictionType)
    ///   setPointTempC  = Double(bytes[2][1:0]<<8 | bytes[1]) * 0.1        (10-bit)
    ///   heatStartTempC = Double(bytes[3][3:0]<<6 | bytes[2][7:2]>>2) * 0.1 (10-bit)
    ///   predictionSecs = bytes[5][4:0]<<12 | bytes[4]<<4 | bytes[3][7:4]>>4 (17-bit)
    ///   estCoreTempC   = Double(bytes[6]<<3 | bytes[5][7:5]>>5) * 0.1 - 20.0 (11-bit)
    ///
    /// - Parameter block: At least 7 bytes, normalised to 0-based indexing before calling.
    /// - Returns: nil if `block.count < 7`.
    static func decode(block bytes: [UInt8]) -> ProbePrediction? {
        guard bytes.count >= 7 else { return nil }

        // state: bits [3:0] of bytes[0]
        let stateRaw = bytes[0] & 0xF
        let state = PredictionState(raw: stateRaw)

        // mode: bits [5:4] of bytes[0]
        let modeRaw = (bytes[0] >> 4) & 0x3
        let mode = PredictionMode(rawValue: modeRaw) ?? .none

        // type: bits [7:6] of bytes[0]
        let typeRaw = (bytes[0] >> 6) & 0x3
        let type = PredictionType(rawValue: typeRaw) ?? .none

        // setPointTempC: 10-bit value = bytes[2][1:0] << 8 | bytes[1]
        let setPointRaw = UInt16(bytes[2] & 0x03) << 8 | UInt16(bytes[1])
        let setPointTempC = Double(setPointRaw) * 0.1

        // heatStartTempC: 10-bit value = bytes[3][3:0] << 6 | bytes[2][7:2] >> 2
        let heatStartRaw = UInt16(bytes[3] & 0x0F) << 6 | UInt16(bytes[2] & 0xFC) >> 2
        let heatStartTempC = Double(heatStartRaw) * 0.1

        // predictionSeconds: 17-bit = bytes[5][4:0] << 12 | bytes[4] << 4 | bytes[3][7:4] >> 4
        let predictionSeconds = UInt32(bytes[5] & 0x1F) << 12
                              | UInt32(bytes[4])        <<  4
                              | UInt32(bytes[3] & 0xF0) >>  4

        // estimatedCoreTempC: 11-bit = (bytes[6] << 3 | bytes[5][7:5] >> 5) * 0.1 - 20.0
        let estCoreRaw = UInt16(bytes[6]) << 3 | UInt16(bytes[5] & 0xE0) >> 5
        let estimatedCoreTempC = Double(estCoreRaw) * 0.1 - 20.0

        return ProbePrediction(
            state: state,
            mode: mode,
            type: type,
            setPointTempC: setPointTempC,
            heatStartTempC: heatStartTempC,
            predictionSeconds: predictionSeconds,
            estimatedCoreTempC: estimatedCoreTempC
        )
    }
}

// MARK: - Full Probe Status payload decoder

extension ProbeReading {

    /// Decodes a full Probe Status notification payload into a `ProbeReading`.
    ///
    /// Payload byte map:
    ///   [0..<4]   min log sequence (UInt32 LE)
    ///   [4..<8]   max log sequence (UInt32 LE)
    ///   [8..<21]  temperature block (13 bytes)
    ///   [21]      ModeId byte
    ///   [22]      Battery + Virtual Sensors byte
    ///   [23..<30] Prediction Status (7 bytes)
    ///
    /// IMPORTANT: `Data` slices may have non-zero base indices; each sub-range is
    /// normalised to a 0-based `[UInt8]` via `Array(data[range])` before bit math.
    ///
    /// - Parameter data: Raw notification payload; must be ≥30 bytes.
    /// - Returns: nil when payload is too short or any sub-block fails to decode.
    static func decode(data: Data) -> ProbeReading? {
        guard data.count >= 30 else { return nil }

        // Log sequence numbers (UInt32 little-endian)
        let minLogSeqBytes = Array(data[0..<4])
        let maxLogSeqBytes = Array(data[4..<8])
        let minLogSequence = UInt32(minLogSeqBytes[0])
                           | UInt32(minLogSeqBytes[1]) << 8
                           | UInt32(minLogSeqBytes[2]) << 16
                           | UInt32(minLogSeqBytes[3]) << 24
        let maxLogSequence = UInt32(maxLogSeqBytes[0])
                           | UInt32(maxLogSeqBytes[1]) << 8
                           | UInt32(maxLogSeqBytes[2]) << 16
                           | UInt32(maxLogSeqBytes[3]) << 24

        // Temperature block: bytes [8..<21], normalised to 0-based [UInt8]
        let tempBlock = Array(data[8..<21])
        guard let temperatures = ProbeTemperatures.decode(block: tempBlock) else { return nil }

        // ModeId: byte [21]
        let modeIdByte = data[21]
        let modeId = DecodedModeId(byte: modeIdByte)

        // Battery + Virtual Sensors: byte [22]
        let battVSByte = data[22]
        let battVS = DecodedBatteryVirtualSensors(byte: battVSByte)

        // Prediction Status: bytes [23..<30], normalised to 0-based [UInt8]
        let predBlock = Array(data[23..<30])
        guard let prediction = ProbePrediction.decode(block: predBlock) else { return nil }

        return ProbeReading(
            minLogSequence: minLogSequence,
            maxLogSequence: maxLogSequence,
            temperatures: temperatures,
            mode: modeId.mode,
            probeColor: modeId.color,
            probeID: modeId.id,
            batteryStatus: battVS.batteryStatus,
            coreSensor: battVS.coreSensor,
            surfaceSensor: battVS.surfaceSensor,
            ambientSensor: battVS.ambientSensor,
            prediction: prediction,
            // Overheating Sensors: byte [48], after Food Safe Data [30..<40]
            // and Food Safe Status [40..<48]. Optional — older/short payloads
            // simply don't carry it.
            overheatingSensors: data.count >= 49 ? data[48] : nil
        )
    }
}
