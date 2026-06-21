// ProbeStatusDecoderTests.swift
// Grill Time Pro
//
// Swift Testing suite for ProbeStatusDecoder.
// Follows the style in TimerStateTests.swift: import Testing, @Suite, @Test, #expect.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - Temperature conversion formula

@Suite("Temperature raw-to-°C conversion")
struct TemperatureConversionTests {

    // Formula: Double(raw) * 0.05 - 20.0
    // raw 0   → -20.0 °C
    // raw 400 →   0.0 °C  (400 * 0.05 = 20.0; 20.0 - 20.0 = 0.0)
    // raw 800 →  20.0 °C
    // raw 13bit max = 8191 → 8191 * 0.05 - 20.0 = 409.55 - 20.0 = 389.55 °C

    private func convert(_ raw: UInt16) -> Double { Double(raw) * 0.05 - 20.0 }
    private let tolerance = 1e-9

    @Test("raw 0 → -20.0 °C")
    func rawZero() {
        #expect(abs(convert(0) - (-20.0)) < tolerance)
    }

    @Test("raw 400 → 0.0 °C")
    func raw400() {
        #expect(abs(convert(400) - 0.0) < tolerance)
    }

    @Test("raw 800 → 20.0 °C (mid-range)")
    func raw800() {
        #expect(abs(convert(800) - 20.0) < tolerance)
    }

    @Test("raw 7780 → ~369 °C (near maximum valid reading)")
    func rawNearMax() {
        // 7780 * 0.05 - 20.0 = 389.0 - 20.0 = 369.0
        #expect(abs(convert(7780) - 369.0) < tolerance)
    }
}

// MARK: - Test-only temperature block encoder
//
// Packs eight 13-bit raw values into 13 bytes, inverting the documented decoder layout.
// This encoder is used for round-trip tests ONLY. The golden fixture below is computed
// BY HAND from first principles — it does NOT use this encoder — to catch mirrored bugs.

private func encodeTempBlock(_ raws: [UInt16]) -> [UInt8] {
    precondition(raws.count == 8, "encodeTempBlock requires exactly 8 raw values")

    // The decoder inserts in reverse order:
    //   line-1 (r[7]=T8), line-2 (r[6]=T7), …, line-8 (r[0]=T1)
    // So raws[0]=T1 maps to line-8; raws[7]=T8 maps to line-1.
    let r = raws  // r[0]=T1 … r[7]=T8

    // Aliases matching the decoder line numbering (T8 → T1 = line 1 → line 8)
    let r8 = r[7], r7 = r[6], r6 = r[5], r5 = r[4]
    let r4 = r[3], r3 = r[2], r2 = r[1], r1 = r[0]

    var b = [UInt8](repeating: 0, count: 13)

    // Line 1: r8 = b[0]<<5 | b[1]>>3  (13 bits split 8+5)
    b[0] = UInt8((r8 >> 5) & 0xFF)
    b[1]  = UInt8((r8 & 0x1F) << 3)   // top 5 bits in positions [7:3]

    // Line 2: r7 = b[1][2:0]<<10 | b[2]<<2 | b[3][7:6]  (3+8+2 = 13)
    b[1] |= UInt8((r7 >> 10) & 0x07)
    b[2]  = UInt8((r7 >> 2) & 0xFF)
    b[3]  = UInt8((r7 & 0x03) << 6)

    // Line 3: r6 = b[3][5:0]<<7 | b[4][7:1]  (6+7 = 13)
    b[3] |= UInt8((r6 >> 7) & 0x3F)
    b[4]  = UInt8((r6 & 0x7F) << 1)

    // Line 4: r5 = b[4][0]<<12 | b[5]<<4 | b[6][7:4]  (1+8+4 = 13)
    b[4] |= UInt8((r5 >> 12) & 0x01)
    b[5]  = UInt8((r5 >> 4) & 0xFF)
    b[6]  = UInt8((r5 & 0x0F) << 4)

    // Line 5: r4 = b[6][3:0]<<9 | b[7]<<1 | b[8][7]  (4+8+1 = 13)
    b[6] |= UInt8((r4 >> 9) & 0x0F)
    b[7]  = UInt8((r4 >> 1) & 0xFF)
    b[8]  = UInt8((r4 & 0x01) << 7)

    // Line 6: r3 = b[8][6:0]<<6 | b[9][7:2]  (7+6 = 13)
    b[8] |= UInt8((r3 >> 6) & 0x7F)
    b[9]  = UInt8((r3 & 0x3F) << 2)

    // Line 7: r2 = b[9][1:0]<<11 | b[10]<<3 | b[11][7:5]  (2+8+3 = 13)
    b[9]  |= UInt8((r2 >> 11) & 0x03)
    b[10]  = UInt8((r2 >> 3) & 0xFF)
    b[11]  = UInt8((r2 & 0x07) << 5)

    // Line 8: r1 = b[11][4:0]<<8 | b[12]  (5+8 = 13)
    b[11] |= UInt8((r1 >> 8) & 0x1F)
    b[12]  = UInt8(r1 & 0xFF)

    return b
}

// MARK: - Round-trip tests (encoder → decoder)

@Suite("Temperature block round-trip (encoder→decoder)")
struct TempBlockRoundTripTests {

    private let tolerance = 1e-9

    // Helper: decode a set of raw values and assert the °C results match.
    private func assertRoundTrip(_ raws: [UInt16]) throws {
        let block = encodeTempBlock(raws)
        guard let temps = ProbeTemperatures.decode(block: block) else {
            Issue.record("decode returned nil for block: \(block.map { String(format: "%02X", $0) })")
            return
        }
        for (i, raw) in raws.enumerated() {
            let expected = Double(raw) * 0.05 - 20.0
            let actual   = temps.values[i]
            #expect(abs(actual - expected) < tolerance,
                    "T\(i+1): expected \(expected) °C, got \(actual) °C (raw \(raw))")
        }
    }

    @Test("All zeros (T1–T8 each raw = 0 → -20 °C)")
    func allZeros() throws {
        try assertRoundTrip([0, 0, 0, 0, 0, 0, 0, 0])
    }

    @Test("All max (each raw = 8191 = 0x1FFF)")
    func allMax() throws {
        try assertRoundTrip([8191, 8191, 8191, 8191, 8191, 8191, 8191, 8191])
    }

    @Test("Alternating 0x0AAA / 0x1555 (straddle byte boundaries)")
    func alternating() throws {
        try assertRoundTrip([0x0AAA, 0x1555, 0x0AAA, 0x1555, 0x0AAA, 0x1555, 0x0AAA, 0x1555])
    }

    @Test("Single LSB set (raw = 1 in each position)")
    func singleLSB() throws {
        try assertRoundTrip([1, 0, 0, 0, 0, 0, 0, 0])
        try assertRoundTrip([0, 1, 0, 0, 0, 0, 0, 0])
        try assertRoundTrip([0, 0, 0, 0, 0, 0, 0, 1])
    }

    @Test("Mixed representative values across all eight sensors")
    func mixed() throws {
        // T1=0, T2=400, T3=100, T4=200, T5=1, T6=8191, T7=5461, T8=2730
        try assertRoundTrip([0, 400, 100, 200, 1, 8191, 5461, 2730])
    }
}

// MARK: - Golden fixture (computed BY HAND, not via encoder)
//
// Input raw values (T1…T8):
//   T1 = 0x0000 (  0)  → -20.00 °C
//   T2 = 0x0190 (400)  →   0.00 °C
//   T3 = 0x0064 (100)  →  -15.00 °C
//   T4 = 0x00C8 (200)  →  -10.00 °C
//   T5 = 0x0001 (  1)  → -19.95 °C
//   T6 = 0x1FFF (8191) → 389.55 °C  (wait, valid range is up to ~369 but 8191 is the 13-bit max, okay for packing test)
//   T7 = 0x1555 (5461) → 253.05 °C
//   T8 = 0x0AAA (2730) → 116.50 °C
//
// The decoder processes lines in the order T8…T1 (because each insert pushes to front).
// r8=2730=0x0AAA, r7=5461=0x1555, r6=8191=0x1FFF, r5=1=0x0001
// r4=200=0x00C8,  r3=100=0x0064,  r2=400=0x0190,   r1=0=0x0000
//
// Byte-by-byte derivation:
//
// Line 1 (T8, r8=0x0AAA=0b0_0101_0101_0101_0):
//   b[0] = r8 >> 5 = 0x0AAA >> 5 = 0x55
//   b[1] upper = (r8 & 0x1F) << 3 = (0x0A) << 3 = 0x50
//
// Line 2 (T7, r7=0x1555=0b1_0101_0101_0101_0):
//   b[1] lower = r7 >> 10 = 5 → b[1] = 0x50 | 0x05 = 0x55
//   b[2] = (r7 >> 2) & 0xFF = 0x1555 >> 2 = 0x555 & 0xFF = 0x55
//   b[3] upper = (r7 & 0x03) << 6 = 0x01 << 6 = 0x40
//
// Line 3 (T6, r6=0x1FFF=0b1_1111_1111_1111_0):
//   b[3] lower = (r6 >> 7) & 0x3F = 0x3F → b[3] = 0x40 | 0x3F = 0x7F
//   b[4] upper = (r6 & 0x7F) << 1 = 0x7F << 1 = 0xFE
//
// Line 4 (T5, r5=0x0001=1):
//   b[4] lsb = (r5 >> 12) & 0x01 = 0 → b[4] = 0xFE | 0x00 = 0xFE
//   b[5] = (r5 >> 4) & 0xFF = 0x00
//   b[6] upper = (r5 & 0x0F) << 4 = 0x01 << 4 = 0x10
//
// Line 5 (T4, r4=0x00C8=200=0b0_0000_1100_1000):
//   b[6] lower = (r4 >> 9) & 0x0F = 0 → b[6] = 0x10 | 0x00 = 0x10
//   b[7] = (r4 >> 1) & 0xFF = 100 = 0x64
//   b[8] msb = (r4 & 0x01) << 7 = 0 → b[8] bit7 = 0x00
//
// Line 6 (T3, r3=0x0064=100=0b0_0000_0110_0100):
//   b[8] lower7 = (r3 >> 6) & 0x7F = 1 → b[8] = 0x00 | 0x01 = 0x01
//   b[9] upper = (r3 & 0x3F) << 2 = 0x24 << 2 = 0x90
//
// Line 7 (T2, r2=0x0190=400=0b0_0001_1001_0000):
//   b[9] lower = (r2 >> 11) & 0x03 = 0 → b[9] = 0x90 | 0x00 = 0x90
//   b[10] = (r2 >> 3) & 0xFF = 50 = 0x32
//   b[11] upper = (r2 & 0x07) << 5 = 0 → 0x00
//
// Line 8 (T1, r1=0x0000=0):
//   b[11] lower = (r1 >> 8) & 0x1F = 0 → b[11] = 0x00
//   b[12] = r1 & 0xFF = 0x00
//
// Final 13 bytes (hex): 55 55 55 7F FE 00 10 64 01 90 32 00 00

@Suite("Temperature block golden fixture (hand-computed)")
struct TempBlockGoldenFixtureTests {

    // The 13 bytes derived above by hand.
    private let goldenBlock: [UInt8] = [
        0x55, 0x55, 0x55, 0x7F, 0xFE, 0x00, 0x10, 0x64, 0x01, 0x90, 0x32, 0x00, 0x00
    ]

    private let tolerance = 1e-9

    @Test("Golden fixture decodes to the expected eight temperatures")
    func goldenDecode() {
        guard let temps = ProbeTemperatures.decode(block: goldenBlock) else {
            Issue.record("ProbeTemperatures.decode returned nil for golden block")
            return
        }

        // T1 = raw 0    → -20.00 °C
        #expect(abs(temps.t1 - (-20.0)) < tolerance, "T1 should be -20.0 °C, got \(temps.t1)")

        // T2 = raw 400  →   0.00 °C
        #expect(abs(temps.t2 - 0.0) < tolerance, "T2 should be 0.0 °C, got \(temps.t2)")

        // T3 = raw 100  → -15.00 °C  (100 * 0.05 - 20.0 = 5.0 - 20.0 = -15.0)
        #expect(abs(temps.t3 - (-15.0)) < tolerance, "T3 should be -15.0 °C, got \(temps.t3)")

        // T4 = raw 200  → -10.00 °C  (200 * 0.05 - 20.0 = 10.0 - 20.0 = -10.0)
        #expect(abs(temps.t4 - (-10.0)) < tolerance, "T4 should be -10.0 °C, got \(temps.t4)")

        // T5 = raw 1    → -19.95 °C  (1 * 0.05 - 20.0 = 0.05 - 20.0 = -19.95)
        #expect(abs(temps.t5 - (-19.95)) < tolerance, "T5 should be -19.95 °C, got \(temps.t5)")

        // T6 = raw 8191 → 389.55 °C  (8191 * 0.05 - 20.0 = 409.55 - 20.0 = 389.55)
        #expect(abs(temps.t6 - 389.55) < 1e-6, "T6 should be 389.55 °C, got \(temps.t6)")

        // T7 = raw 5461 → 253.05 °C  (5461 * 0.05 - 20.0 = 273.05 - 20.0 = 253.05)
        #expect(abs(temps.t7 - 253.05) < 1e-6, "T7 should be 253.05 °C, got \(temps.t7)")

        // T8 = raw 2730 → 116.50 °C  (2730 * 0.05 - 20.0 = 136.5 - 20.0 = 116.5)
        #expect(abs(temps.t8 - 116.5) < tolerance, "T8 should be 116.5 °C, got \(temps.t8)")
    }

    @Test("decode returns nil for a block shorter than 13 bytes")
    func shortBlockReturnsNil() {
        let shortBlock = Array(goldenBlock.prefix(12))
        #expect(ProbeTemperatures.decode(block: shortBlock) == nil)
    }

    @Test("decode returns nil for an empty block")
    func emptyBlockReturnsNil() {
        #expect(ProbeTemperatures.decode(block: []) == nil)
    }
}

// MARK: - ModeId byte decoder

@Suite("ModeId byte decoder")
struct ModeIdTests {

    // Byte layout: bits [1:0]=mode, bits [4:2]=color, bits [7:5]=id

    @Test("normal mode, color1, ID1 (byte = 0x00)")
    func allZeros() {
        let d = DecodedModeId(byte: 0x00)
        #expect(d.mode == .normal)
        #expect(d.color == .color1)
        #expect(d.id == .id1)
    }

    @Test("instantRead mode, color3, ID2")
    func instantReadColor3ID2() {
        // mode=1 (bits[1:0]), color=2 (bits[4:2]), id=1 (bits[7:5])
        // byte = id<<5 | color<<2 | mode
        //      = (1<<5) | (2<<2) | 1
        //      = 0x20   | 0x08   | 0x01 = 0x29
        let d = DecodedModeId(byte: 0x29)
        #expect(d.mode == .instantRead)
        #expect(d.color == .color3)
        #expect(d.id == .id2)
    }

    @Test("error mode, color8, ID8 (byte = 0xFF)")
    func allOnes() {
        // mode=3, color=7, id=7
        let d = DecodedModeId(byte: 0xFF)
        #expect(d.mode == .error)
        #expect(d.color == .color8)
        #expect(d.id == .id8)
    }

    @Test("reserved mode, color5, ID4")
    func reservedModeColor5ID4() {
        // mode=2, color=4 (0-indexed → color5), id=3 (0-indexed → id4)
        // byte = (3<<5) | (4<<2) | 2 = 0x60 | 0x10 | 0x02 = 0x72
        let d = DecodedModeId(byte: 0x72)
        #expect(d.mode == .reserved)
        #expect(d.color == .color5)
        #expect(d.id == .id4)
    }

    @Test("normal mode, color2, ID3")
    func normalColor2ID3() {
        // mode=0, color=1 (0-indexed → color2), id=2 (0-indexed → id3)
        // byte = (2<<5) | (1<<2) | 0 = 0x40 | 0x04 | 0x00 = 0x44
        let d = DecodedModeId(byte: 0x44)
        #expect(d.mode == .normal)
        #expect(d.color == .color2)
        #expect(d.id == .id3)
    }
}

// MARK: - Battery + Virtual Sensors byte decoder

@Suite("Battery and virtual sensor byte decoder")
struct BatteryVirtualSensorTests {

    // Byte layout: bit[0]=battery, bits[3:1]=core(v[2:0]), bits[5:4]=surface(v[4:3]), bits[7:6]=ambient(v[6:5])

    @Test("battery OK, all sensors at minimum (byte = 0x00 → core=T1, surface=T4, ambient=T5)")
    func allZeros() {
        let d = DecodedBatteryVirtualSensors(byte: 0x00)
        #expect(d.batteryStatus == .ok)
        #expect(d.coreSensor == .t1)
        #expect(d.surfaceSensor == .t4)
        #expect(d.ambientSensor == .t5)
    }

    @Test("battery low, core=T3, surface=T6, ambient=T7")
    func batteryLowMidSensors() {
        // battery=1 (bit0)
        // core raw=2 (T3), surface raw=2 (T6), ambient raw=2 (T7)
        // v = core | surface<<3 | ambient<<5 = 2 | (2<<3) | (2<<5) = 2 | 16 | 64 = 82 = 0x52
        // byte = (v<<1) | battery = (0x52<<1) | 1 = 0xA4 | 0x01 = 0xA5
        let d = DecodedBatteryVirtualSensors(byte: 0xA5)
        #expect(d.batteryStatus == .low)
        #expect(d.coreSensor == .t3)
        #expect(d.surfaceSensor == .t6)
        #expect(d.ambientSensor == .t7)
    }

    @Test("battery OK, core=T6 (max valid), surface=T7 (max valid), ambient=T8 (max valid)")
    func allMaxSensors() {
        // core raw=5 (T6), surface raw=3 (T7), ambient raw=3 (T8)
        // v = 5 | (3<<3) | (3<<5) = 5 | 24 | 96 = 125 = 0x7D
        // byte = (0x7D<<1) | 0 = 0xFA
        let d = DecodedBatteryVirtualSensors(byte: 0xFA)
        #expect(d.batteryStatus == .ok)
        #expect(d.coreSensor == .t6)
        #expect(d.surfaceSensor == .t7)
        #expect(d.ambientSensor == .t8)
    }

    @Test("battery low (byte = 0x01 → all sensors default)")
    func batteryLowOnly() {
        let d = DecodedBatteryVirtualSensors(byte: 0x01)
        #expect(d.batteryStatus == .low)
        #expect(d.coreSensor == .t1)
        #expect(d.surfaceSensor == .t4)
        #expect(d.ambientSensor == .t5)
    }

    @Test("CoreSensor thermistorIndex mapping")
    func coreSensorThermistorIndex() {
        #expect(CoreSensor.t1.thermistorIndex == 1)
        #expect(CoreSensor.t4.thermistorIndex == 4)
        #expect(CoreSensor.t6.thermistorIndex == 6)
    }

    @Test("SurfaceSensor thermistorIndex mapping")
    func surfaceSensorThermistorIndex() {
        #expect(SurfaceSensor.t4.thermistorIndex == 4)
        #expect(SurfaceSensor.t7.thermistorIndex == 7)
    }

    @Test("AmbientSensor thermistorIndex mapping")
    func ambientSensorThermistorIndex() {
        #expect(AmbientSensor.t5.thermistorIndex == 5)
        #expect(AmbientSensor.t8.thermistorIndex == 8)
    }
}

// MARK: - Prediction Status block decoder

@Suite("Prediction Status block decoder")
struct PredictionStatusTests {

    // Build a 7-byte prediction block for known values.
    //
    // Desired values:
    //   state = predicting (3), mode = timeToRemoval (1), type = removal (1)
    //   setPoint     = 74.0 °C  → raw = 740 = 0x2E4
    //   heatStart    = 20.0 °C  → raw = 200 = 0x0C8
    //   predSeconds  = 1200     (20 minutes)
    //   estCore      = 55.0 °C  → raw = (55.0 + 20.0) / 0.1 = 750 = 0x2EE
    //
    // bytes[0]: state | mode<<4 | type<<6 = 3 | (1<<4) | (1<<6) = 3 | 16 | 64 = 83 = 0x53
    //
    // setPointRaw = 740 = 0x2E4
    //   bytes[1] = setPointRaw & 0xFF = 0xE4
    //   bytes[2] lower 2 bits = (setPointRaw >> 8) & 0x03 = 0x02
    //
    // heatStartRaw = 200 = 0x0C8
    //   heatStart uses: bytes[3][3:0]<<6 | bytes[2][7:2]>>2
    //   So heatStartRaw bits [5:0] go into bytes[2][7:2]:
    //     (heatStartRaw & 0x3F) << 2 = (0xC8 & 0x3F) << 2 = 0x08 << 2 = 0x20 (bits [7:2] of bytes[2])
    //     bytes[2] upper = 0x20; bytes[2] lower2 = 0x02 → bytes[2] = 0x22
    //   heatStartRaw bits [9:6] go into bytes[3][3:0]:
    //     (heatStartRaw >> 6) & 0x0F = 3 → bytes[3] lower nibble = 0x03
    //
    // predictionSeconds = 1200 = 0x4B0 = 0b0000_0100_1011_0000
    //   predSecs = bytes[5][4:0]<<12 | bytes[4]<<4 | bytes[3][7:4]>>4
    //   bytes[3][7:4] = (predSecs & 0x0F) << 4 = (0x4B0 & 0xF) << 4 = 0 << 4 = 0x00
    //     → bytes[3] upper nibble = 0x00 → bytes[3] = 0x03 | 0x00 = 0x03
    //   bytes[4] = (predSecs >> 4) & 0xFF = 0x04B0 >> 4 & 0xFF = 0x4B = 75
    //   bytes[5] lower 5 bits = (predSecs >> 12) & 0x1F = 0 → bytes[5] lower5 = 0x00
    //
    // estCoreRaw = 750 = 0x2EE = 0b10_1110_1110
    //   estCore = bytes[6]<<3 | bytes[5][7:5]>>5
    //   bytes[5][7:5] = (estCoreRaw & 0x07) << 5 = (0x2EE & 7) << 5 = 6 << 5 = 0xC0
    //     → bytes[5] = 0x00 | 0xC0 = 0xC0
    //   bytes[6] = (estCoreRaw >> 3) & 0xFF = 0x5D = 93
    //
    // Summary: [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
    //
    // Verify setPoint decode:
    //   UInt16(bytes[2] & 0x03) << 8 | UInt16(bytes[1])
    //   = UInt16(0x22 & 0x03) << 8 | UInt16(0xE4)
    //   = UInt16(0x02) << 8 | 0xE4 = 0x200 | 0xE4 = 0x2E4 = 740 → 74.0 °C ✓
    //
    // Verify heatStart decode:
    //   UInt16(bytes[3] & 0x0F) << 6 | UInt16(bytes[2] & 0xFC) >> 2
    //   = UInt16(0x03 & 0x0F) << 6 | UInt16(0x22 & 0xFC) >> 2
    //   = UInt16(0x03) << 6 | UInt16(0x20) >> 2
    //   = 0xC0 | 0x08 = 0xC8 = 200 → 20.0 °C ✓
    //
    // Verify predictionSeconds decode:
    //   UInt32(bytes[5] & 0x1F)<<12 | UInt32(bytes[4])<<4 | UInt32(bytes[3] & 0xF0)>>4
    //   = UInt32(0xC0 & 0x1F)<<12 | UInt32(0x4B)<<4 | UInt32(0x03 & 0xF0)>>4
    //   = UInt32(0x00)<<12 | UInt32(0x4B)<<4 | UInt32(0x00)>>4
    //   = 0 | 0x4B0 | 0 = 0x4B0 = 1200 ✓
    //
    // Verify estCore decode:
    //   UInt16(bytes[6])<<3 | UInt16(bytes[5] & 0xE0)>>5
    //   = UInt16(0x5D)<<3 | UInt16(0xC0)>>5
    //   = 0x2E8 | 0x06 = 0x2EE = 750 → 750*0.1-20.0 = 75.0-20.0 = 55.0 °C ✓

    private let knownBlock: [UInt8] = [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
    private let tolerance = 1e-6

    @Test("Decodes predicting state")
    func state() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(p.state == .predicting)
    }

    @Test("Decodes prediction mode")
    func mode() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(p.mode == .timeToRemoval)
    }

    @Test("Decodes prediction type")
    func type_() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(p.type == .removal)
    }

    @Test("Decodes set point temperature: 74.0 °C")
    func setPoint() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(abs(p.setPointTempC - 74.0) < tolerance)
    }

    @Test("Decodes heat start temperature: 20.0 °C")
    func heatStart() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(abs(p.heatStartTempC - 20.0) < tolerance)
    }

    @Test("Decodes prediction seconds: 1200")
    func predictionSeconds() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(p.predictionSeconds == 1200)
    }

    @Test("Decodes estimated core temperature: 55.0 °C")
    func estimatedCoreTemp() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(abs(p.estimatedCoreTempC - 55.0) < tolerance)
    }

    @Test("predictedReadyDate returns now + predictionSeconds when state is predicting")
    func predictedReadyDate() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        let fixedNow = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let expected = fixedNow.addingTimeInterval(TimeInterval(1200))
        let result = p.predictedReadyDate(from: fixedNow)
        #expect(result != nil)
        #expect(abs(result!.timeIntervalSince(expected)) < 1e-9)
    }

    @Test("predictedReadyDate returns nil when state is not predicting")
    func predictedReadyDateNilWhenNotPredicting() {
        // bytes[0] with state=probeInserted (1), mode=0, type=0
        var nonPredBlock = knownBlock
        nonPredBlock[0] = 0x01   // state=1 (probeInserted), mode=0, type=0
        guard let p = ProbePrediction.decode(block: nonPredBlock) else {
            Issue.record("decode returned nil"); return
        }
        let result = p.predictedReadyDate(from: Date())
        #expect(result == nil)
    }

    @Test("percentToRemoval: (55-20)/(74-20) = 35/54 ≈ 0.6481")
    func percentToRemoval() {
        guard let p = ProbePrediction.decode(block: knownBlock) else {
            Issue.record("decode returned nil"); return
        }
        let expected = (55.0 - 20.0) / (74.0 - 20.0)   // 35/54 ≈ 0.6481
        #expect(p.percentToRemoval != nil)
        #expect(abs(p.percentToRemoval! - expected) < 1e-6)
    }

    @Test("percentToRemoval returns nil when setPoint <= heatStart")
    func percentToRemovalNilWhenDenomZero() {
        // Craft a block where setPoint == heatStart
        // setPoint = 20.0 → raw 200 = 0x0C8; but we also have heatStart = 20.0 → raw 200
        // Use the known block but adjust: set setPoint to heatStart (20.0 → 0x0C8 = 200)
        // bytes[1] = 200 & 0xFF = 0xC8, bytes[2] bits[1:0] = 200 >> 8 = 0
        // bytes[2] = (0x22 & 0xFC) | 0x00 = 0x20
        var equalBlock = knownBlock
        equalBlock[1] = 0xC8
        equalBlock[2] = (knownBlock[2] & 0xFC) | 0x00  // setPointRaw high bits = 0
        guard let p = ProbePrediction.decode(block: equalBlock) else {
            Issue.record("decode returned nil"); return
        }
        #expect(p.percentToRemoval == nil)
    }

    @Test("percentToRemoval clamps to 1.0 when estCore >= setPoint")
    func percentToRemovalClampedToOne() {
        // Force estCore = setPoint = 74.0 → estCoreRaw = (74+20)/0.1 = 940 = 0x3AC
        // bytes[5][7:5] = (940 & 7) << 5 = 4 << 5 = 0x80
        // bytes[6] = (940 >> 3) & 0xFF = 117 = 0x75
        var clampedBlock = knownBlock
        clampedBlock[5] = (knownBlock[5] & 0x1F) | 0x80   // keep low 5 bits (predSec), set upper 3
        clampedBlock[6] = 0x75
        guard let p = ProbePrediction.decode(block: clampedBlock) else {
            Issue.record("decode returned nil"); return
        }
        let pct = p.percentToRemoval
        #expect(pct != nil)
        if let pct {
            #expect(pct <= 1.0)
            #expect(pct >= 0.9)   // should be 1.0 or close
        }
    }

    @Test("decode returns nil for block shorter than 7 bytes")
    func shortBlockReturnsNil() {
        #expect(ProbePrediction.decode(block: [0x53, 0xE4, 0x22]) == nil)
    }
}

// MARK: - Full ProbeStatus payload decoder

@Suite("Full ProbeStatus payload decoder")
struct ProbeStatusPayloadTests {

    // Build a ≥30-byte payload from the known sub-blocks used in tests above.
    //
    // Layout:
    //   [0..<4]   minLog = 1         → LE: 01 00 00 00
    //   [4..<8]   maxLog = 256       → LE: 00 01 00 00
    //   [8..<21]  golden temp block  → 55 55 55 7F FE 00 10 64 01 90 32 00 00
    //   [21]      ModeId = 0x29      → instantRead, color3, ID2
    //   [22]      BattVS = 0xA5      → battLow, core=T3, surface=T6, ambient=T7
    //   [23..<30] prediction block   → 53 E4 22 03 4B C0 5D
    //   [30..<35] padding zeros (to exceed 30-byte minimum)

    private func makePayload() -> Data {
        var bytes = [UInt8](repeating: 0, count: 35)
        // minLog = 1 (LE)
        bytes[0] = 0x01; bytes[1] = 0x00; bytes[2] = 0x00; bytes[3] = 0x00
        // maxLog = 256 (LE)
        bytes[4] = 0x00; bytes[5] = 0x01; bytes[6] = 0x00; bytes[7] = 0x00
        // temp block
        let tempBlock: [UInt8] = [0x55, 0x55, 0x55, 0x7F, 0xFE, 0x00, 0x10, 0x64, 0x01, 0x90, 0x32, 0x00, 0x00]
        for (i, b) in tempBlock.enumerated() { bytes[8 + i] = b }
        // ModeId
        bytes[21] = 0x29
        // BattVS
        bytes[22] = 0xA5
        // prediction block
        let predBlock: [UInt8] = [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
        for (i, b) in predBlock.enumerated() { bytes[23 + i] = b }
        return Data(bytes)
    }

    private let tolerance = 1e-6

    @Test("Decodes log sequence numbers")
    func logSequenceNumbers() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        #expect(r.minLogSequence == 1)
        #expect(r.maxLogSequence == 256)
    }

    @Test("Decodes temperatures (spot-check T1, T2, T8)")
    func temperatures() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        #expect(abs(r.temperatures.t1 - (-20.0)) < tolerance)   // raw 0
        #expect(abs(r.temperatures.t2 - 0.0)     < tolerance)   // raw 400
        #expect(abs(r.temperatures.t8 - 116.5)   < tolerance)   // raw 2730
    }

    @Test("Decodes mode, color, and probe ID from ModeId byte 0x29")
    func modeColorID() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        #expect(r.mode == .instantRead)
        #expect(r.probeColor == .color3)
        #expect(r.probeID == .id2)
    }

    @Test("Decodes battery status and virtual sensors from byte 0xA5")
    func batteryAndVirtualSensors() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        #expect(r.batteryStatus == .low)
        #expect(r.coreSensor == .t3)
        #expect(r.surfaceSensor == .t6)
        #expect(r.ambientSensor == .t7)
    }

    @Test("Resolved coreTempC matches T3 from temperature block")
    func resolvedCoreTemp() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        // coreSensor = T3, T3 decoded from raw 100 → -15.0 °C
        #expect(abs(r.coreTempC - (-15.0)) < tolerance)
    }

    @Test("Resolved surfaceTempC matches T6 from temperature block")
    func resolvedSurfaceTemp() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        // surfaceSensor = T6, T6 decoded from raw 8191 → 389.55 °C
        #expect(abs(r.surfaceTempC - 389.55) < 1e-5)
    }

    @Test("Resolved ambientTempC matches T7 from temperature block")
    func resolvedAmbientTemp() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        // ambientSensor = T7, T7 decoded from raw 5461 → 253.05 °C
        #expect(abs(r.ambientTempC - 253.05) < 1e-5)
    }

    @Test("Decodes prediction block fields")
    func predictionBlock() {
        guard let r = ProbeReading.decode(data: makePayload()) else {
            Issue.record("decode returned nil"); return
        }
        #expect(r.prediction.state == .predicting)
        #expect(abs(r.prediction.setPointTempC - 74.0)    < tolerance)
        #expect(abs(r.prediction.heatStartTempC - 20.0)   < tolerance)
        #expect(r.prediction.predictionSeconds == 1200)
        #expect(abs(r.prediction.estimatedCoreTempC - 55.0) < tolerance)
    }

    @Test("Returns nil for empty Data")
    func emptyDataReturnsNil() {
        #expect(ProbeReading.decode(data: Data()) == nil)
    }

    @Test("Returns nil for 29-byte Data (one byte short)")
    func shortDataReturnsNil() {
        let short = Data(repeating: 0, count: 29)
        #expect(ProbeReading.decode(data: short) == nil)
    }

    @Test("Returns nil for exactly 1 byte")
    func singleByteReturnsNil() {
        #expect(ProbeReading.decode(data: Data([0x00])) == nil)
    }

    @Test("Accepts exactly 30-byte Data (minimum valid length)")
    func exactlyThirtyBytesDecodes() {
        let minimal = Data(makePayload().prefix(30))
        #expect(ProbeReading.decode(data: minimal) != nil)
    }
}
