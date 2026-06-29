// ProbeWatchSyncTests.swift
// Grill Time Pro
//
// Swift Testing suite for the ProbeWatchSync encoder/decoder and helpers.
// The shared mapper compiles into the iOS test target, so tests run there.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - Helpers

/// Builds a valid ≥30-byte Probe Status payload using the sub-blocks from
/// ProbeStatusDecoderTests.  This matches the fixture used in that test so the
/// values are already verified correct by the decoder tests.
///
/// Decoded fields:
///   coreSensor   = T3  (-15.0 °C, raw 100)
///   surfaceSensor= T6  (389.55 °C, raw 8191)
///   ambientSensor= T7  (253.05 °C, raw 5461)
///   batteryStatus= .low
///   prediction.state = .predicting
///   prediction.predictionSeconds = 1200
private func makeTestPayload() -> Data {
    var bytes = [UInt8](repeating: 0, count: 35)
    // minLog = 1 (LE)
    bytes[0] = 0x01; bytes[1] = 0x00; bytes[2] = 0x00; bytes[3] = 0x00
    // maxLog = 256 (LE)
    bytes[4] = 0x00; bytes[5] = 0x01; bytes[6] = 0x00; bytes[7] = 0x00
    // Temp block (wire order): T3=raw100 → -15°C core; T6=raw8191 → 389.55°C surface; T7=raw5461 → 253.05°C ambient
    let tempBlock: [UInt8] = [0x00, 0x00, 0x32, 0x90, 0x01, 0x64, 0x10, 0x00, 0xFE, 0x7F, 0x55, 0x55, 0x55]
    for (i, b) in tempBlock.enumerated() { bytes[8 + i] = b }
    // ModeId = 0x29 → instantRead, color3, ID2
    bytes[21] = 0x29
    // BattVS = 0xA5 → battLow, core=T3, surface=T6, ambient=T7
    bytes[22] = 0xA5
    // Prediction block: state=predicting(3), predictionSeconds=1200
    let predBlock: [UInt8] = [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
    for (i, b) in predBlock.enumerated() { bytes[23 + i] = b }
    return Data(bytes)
}

// MARK: - Suite 1: Round-trip encode → decode

@Suite("ProbeWatchSync — round-trip encode/decode")
struct ProbeWatchSyncRoundTripTests {

    private let tolerance = 0.01   // 0.01 °C rounding tolerance

    @Test("Round-trip: connected reading preserves core/surface/ambient and connected flag")
    func roundTrip() throws {
        guard let reading = ProbeReading.decode(data: makeTestPayload()) else {
            Issue.record("ProbeReading.decode returned nil"); return
        }
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

        let dict = probeReadingWireDict(connected: true, reading: reading, now: now)
        guard let decoded = decodeWatchProbeReading(from: dict) else {
            Issue.record("decodeWatchProbeReading returned nil"); return
        }

        // connected flag
        #expect(decoded.connected == true)

        // Core = T3 = -15.0 °C (valid — well above −20 floor, should be present)
        #expect(decoded.coreC != nil, "coreC should be non-nil for -15.0 °C")
        if let c = decoded.coreC {
            #expect(abs(c - (-15.0)) < tolerance, "coreC expected -15.0, got \(c)")
        }

        // Surface = T6 = 389.55 °C (well above floor, should be present)
        #expect(decoded.surfaceC != nil, "surfaceC should be non-nil for 389.55 °C")

        // Ambient = T7 = 253.05 °C (well above floor, should be present)
        #expect(decoded.ambientC != nil, "ambientC should be non-nil for 253.05 °C")
    }
}

// MARK: - Suite 2: −20 °C floor omission

@Suite("ProbeWatchSync — floor omission")
struct ProbeWatchSyncFloorTests {

    /// Build a payload where T3 (core) and T5 (ambient) are raw 0 = -20°C,
    /// but T6 (surface) is valid.  We'll use the test payload and override
    /// the BattVS byte to place core=T1 (raw0→-20), surface=T2 (raw400→0°C), ambient=T1 (raw0→-20).
    ///
    /// Actually: the simplest approach is to build a payload where ALL eight thermistors
    /// are raw 0 (−20 °C), so whichever virtual sensors are chosen they all resolve to −20.
    @Test("Temps at −20 °C floor are omitted from dict; decoded values are nil")
    func floorOmission() {
        // Payload with all-zero temp block → all T1–T8 = -20 °C
        var bytes = [UInt8](repeating: 0, count: 35)
        // BattVS = 0x00 → battery OK, core=T1, surface=T4, ambient=T5 (all -20)
        bytes[22] = 0x00
        // Prediction block: state=probeNotInserted (0), everything else 0
        // bytes[23..29] already 0

        let data = Data(bytes)
        guard let reading = ProbeReading.decode(data: data) else {
            Issue.record("ProbeReading.decode returned nil for all-zero payload"); return
        }

        let now = Date()
        let dict = probeReadingWireDict(connected: true, reading: reading, now: now)

        // Dict must not contain the temp keys
        #expect(dict["coreC"]    == nil, "coreC key should be absent when temp <= -19.99")
        #expect(dict["surfaceC"] == nil, "surfaceC key should be absent when temp <= -19.99")
        #expect(dict["ambientC"] == nil, "ambientC key should be absent when temp <= -19.99")

        // Decoded struct must have nil temps
        guard let decoded = decodeWatchProbeReading(from: dict) else {
            Issue.record("decodeWatchProbeReading returned nil"); return
        }
        #expect(decoded.coreC    == nil, "decoded coreC should be nil")
        #expect(decoded.surfaceC == nil, "decoded surfaceC should be nil")
        #expect(decoded.ambientC == nil, "decoded ambientC should be nil")
    }
}

// MARK: - Suite 3: Prediction epoch

@Suite("ProbeWatchSync — prediction epoch")
struct ProbeWatchSyncPredictionTests {

    @Test("predReadyEpoch ≈ now + predictionSeconds when state is predicting")
    func predEpochPresent() {
        guard let reading = ProbeReading.decode(data: makeTestPayload()) else {
            Issue.record("ProbeReading.decode returned nil"); return
        }
        // Confirm state is predicting and predictionSeconds = 1200
        #expect(reading.prediction.state == .predicting)
        #expect(reading.prediction.predictionSeconds == 1200)

        let fixedNow = Date(timeIntervalSinceReferenceDate: 2_000_000)
        let dict = probeReadingWireDict(connected: true, reading: reading, now: fixedNow)

        // predReadyEpoch must be present
        guard let epoch = dict["predReadyEpoch"] as? Double else {
            Issue.record("predReadyEpoch key missing from dict"); return
        }
        let expectedEpoch = fixedNow.addingTimeInterval(1200).timeIntervalSince1970
        #expect(abs(epoch - expectedEpoch) < 1.0, "epoch \(epoch) not ≈ expected \(expectedEpoch)")

        // Decoded predictedReadyDate should be non-nil
        guard let decoded = decodeWatchProbeReading(from: dict) else {
            Issue.record("decodeWatchProbeReading returned nil"); return
        }
        #expect(decoded.predictedReadyDate != nil, "predictedReadyDate should be non-nil when predicting")
        if let d = decoded.predictedReadyDate {
            #expect(abs(d.timeIntervalSince1970 - expectedEpoch) < 1.0)
        }
    }

    @Test("predReadyEpoch key absent when state is not predicting; decoded predictedReadyDate is nil")
    func predEpochAbsentWhenNotPredicting() {
        // Use the all-zero payload → prediction state = probeNotInserted (0)
        let data = Data(repeating: 0, count: 35)
        guard let reading = ProbeReading.decode(data: data) else {
            Issue.record("ProbeReading.decode returned nil"); return
        }
        #expect(reading.prediction.state != .predicting)

        let dict = probeReadingWireDict(connected: true, reading: reading, now: Date())
        #expect(dict["predReadyEpoch"] == nil, "predReadyEpoch should be absent when not predicting")

        guard let decoded = decodeWatchProbeReading(from: dict) else {
            Issue.record("decodeWatchProbeReading returned nil"); return
        }
        #expect(decoded.predictedReadyDate == nil, "predictedReadyDate should be nil when not predicting")
    }
}

// MARK: - Suite 4: Disconnected reading

@Suite("ProbeWatchSync — disconnected")
struct ProbeWatchSyncDisconnectedTests {

    @Test("connected:false, reading:nil → connected==false, all temps nil")
    func disconnected() {
        let now = Date()
        let dict = probeReadingWireDict(connected: false, reading: nil, now: now)

        #expect(dict["action"] as? String == "probe")
        #expect(dict["connected"] as? Bool == false)
        // No temp keys
        #expect(dict["coreC"]    == nil)
        #expect(dict["surfaceC"] == nil)
        #expect(dict["ambientC"] == nil)

        guard let decoded = decodeWatchProbeReading(from: dict) else {
            Issue.record("decodeWatchProbeReading returned nil"); return
        }
        #expect(decoded.connected == false)
        #expect(decoded.coreC    == nil)
        #expect(decoded.surfaceC == nil)
        #expect(decoded.ambientC == nil)
    }

    @Test("decodeWatchProbeReading returns nil for a dict with wrong action")
    func wrongAction() {
        let dict: [String: Any] = ["action": "snapshot", "connected": true]
        #expect(decodeWatchProbeReading(from: dict) == nil)
    }

    @Test("decodeWatchProbeReading returns nil for empty dict")
    func emptyDict() {
        #expect(decodeWatchProbeReading(from: [:]) == nil)
    }
}

// MARK: - Suite 5: shouldForwardProbe pure logic

@Suite("ProbeWatchSync — shouldForwardProbe throttle")
struct ShouldForwardProbeTests {

    private let minInterval: TimeInterval = 1.0

    @Test("nil lastSent → always forward")
    func nilLastSent() {
        let now = Date()
        #expect(shouldForwardProbe(now: now, lastSent: nil, minInterval: minInterval) == true)
    }

    @Test("within minInterval → do not forward")
    func withinInterval() {
        let last = Date(timeIntervalSinceReferenceDate: 0)
        let now  = Date(timeIntervalSinceReferenceDate: 0.5) // 0.5s < 1.0s
        #expect(shouldForwardProbe(now: now, lastSent: last, minInterval: minInterval) == false)
    }

    @Test("exactly at minInterval boundary → forward")
    func atBoundary() {
        let last = Date(timeIntervalSinceReferenceDate: 0)
        let now  = Date(timeIntervalSinceReferenceDate: 1.0)
        #expect(shouldForwardProbe(now: now, lastSent: last, minInterval: minInterval) == true)
    }

    @Test("past minInterval → forward")
    func pastInterval() {
        let last = Date(timeIntervalSinceReferenceDate: 0)
        let now  = Date(timeIntervalSinceReferenceDate: 5.0)
        #expect(shouldForwardProbe(now: now, lastSent: last, minInterval: minInterval) == true)
    }

    @Test("just under minInterval → do not forward")
    func justUnder() {
        let last = Date(timeIntervalSinceReferenceDate: 100)
        let now  = Date(timeIntervalSinceReferenceDate: 100.999)
        #expect(shouldForwardProbe(now: now, lastSent: last, minInterval: minInterval) == false)
    }
}

// MARK: - TemperatureUnit conversion / formatting

@Suite("TemperatureUnit")
struct TemperatureUnitTests {

    @Test("Celsius is identity")
    func celsiusIdentity() {
        #expect(TemperatureUnit.celsius.value(fromCelsius: 0) == 0)
        #expect(TemperatureUnit.celsius.value(fromCelsius: 93.3) == 93.3)
    }

    @Test("Fahrenheit conversion at known points")
    func fahrenheitPoints() {
        #expect(TemperatureUnit.fahrenheit.value(fromCelsius: 0) == 32)
        #expect(TemperatureUnit.fahrenheit.value(fromCelsius: 100) == 212)
        #expect(abs(TemperatureUnit.fahrenheit.value(fromCelsius: 37) - 98.6) < 0.0001)
    }

    @Test("compactString rounds and keeps a bare degree sign")
    func compact() {
        #expect(TemperatureUnit.celsius.compactString(fromCelsius: 71.6) == "72°")
        #expect(TemperatureUnit.fahrenheit.compactString(fromCelsius: 100) == "212°")
    }

    @Test("preciseString includes one decimal and the unit symbol")
    func precise() {
        #expect(TemperatureUnit.celsius.preciseString(fromCelsius: 72) == "72.0 °C")
        #expect(TemperatureUnit.fahrenheit.preciseString(fromCelsius: 0) == "32.0 °F")
    }
}

// MARK: - Unit carried in the probe wire payload

@Suite("probe wire dict carries unit")
struct ProbeWireUnitTests {

    @Test("encodes the supplied unit and round-trips through decode")
    func roundTrip() {
        let dict = probeReadingWireDict(connected: true, reading: nil, now: Date(), unit: .fahrenheit)
        #expect(dict["unit"] as? String == "F")
        let decoded = decodeWatchProbeReading(from: dict)
        #expect(decoded?.unit == .fahrenheit)
    }

    @Test("defaults to Celsius when the unit key is absent")
    func defaultsCelsius() {
        var dict = probeReadingWireDict(connected: true, reading: nil, now: Date())
        dict.removeValue(forKey: "unit")
        let decoded = decodeWatchProbeReading(from: dict)
        #expect(decoded?.unit == .celsius)
    }
}
