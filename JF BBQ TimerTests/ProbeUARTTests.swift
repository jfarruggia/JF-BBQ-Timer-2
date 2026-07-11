// ProbeUARTTests.swift
// Grill Time Pro
//
// Swift Testing suite for the UART command channel: pure framing/CRC/encode/
// decode in ProbeUART, plus ProbeBLEManager's send → response/retry/timeout
// logic via FakeProbeCentral.
//
// Frame fixtures were computed OUTSIDE the app (independent Python model of
// CRC-16-CCITT, cross-checked against combustion-ios-ble's Data+CRC.swift and
// the standard check value 0x29B1) so these tests don't just verify the code
// against itself.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - Hex helper

private func hexData(_ hex: String) -> Data {
    var bytes: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        bytes.append(UInt8(hex[index..<next], radix: 16)!)
        index = next
    }
    return Data(bytes)
}

// MARK: - Pinned fixtures

/// SetPrediction 90.0 °C, mode removalAndResting → payload (2<<10)|900 = 0x0B84 LE.
private let frame90C          = hexData("CAFED2300502840B")
/// SetPrediction 95.0 °C (203 °F brisket), mode removalAndResting.
private let frame95C          = hexData("CAFE25530502B60B")
/// Clear: mode none, set point 0.
private let frameClear        = hexData("CAFEE55605020000")
/// SetPrediction response, success flag set.
private let responseSuccess   = hexData("CAFE5D14050100")
/// SetPrediction response, failure.
private let responseFailure   = hexData("CAFE6C27050000")

// MARK: - Pure encode/decode tests

@Suite("ProbeUART framing + CRC")
struct ProbeUARTTests {

    // MARK: CRC

    @Test("crc16ccitt matches the CCITT-FALSE standard check value 0x29B1")
    func crcStandardCheck() {
        #expect(ProbeUART.crc16ccitt(Data("123456789".utf8)) == 0x29B1)
    }

    @Test("crc16ccitt of empty data is the 0xFFFF initial value")
    func crcEmpty() {
        #expect(ProbeUART.crc16ccitt(Data()) == 0xFFFF)
    }

    // MARK: SetPrediction encoding

    @Test("encodeSetPrediction 90 °C removalAndResting matches pinned frame")
    func encode90C() {
        let frame = ProbeUART.encodeSetPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        #expect(frame == frame90C)
    }

    @Test("encodeSetPrediction 95 °C removalAndResting matches pinned frame")
    func encode95C() {
        let frame = ProbeUART.encodeSetPrediction(setPointCelsius: 95.0, mode: .removalAndResting)
        #expect(frame == frame95C)
    }

    @Test("encodeSetPrediction mode none + 0 °C (clear) matches pinned frame")
    func encodeClear() {
        let frame = ProbeUART.encodeSetPrediction(setPointCelsius: 0, mode: .none)
        #expect(frame == frameClear)
    }

    @Test("set point rounds to the nearest 0.1 °C step")
    func encodeRounding() {
        // 71.06 °C → 710.6 tenths → 711 = 0x2C7; packed (2<<10)|0x2C7 = 0x0AC7 LE
        let frame = ProbeUART.encodeSetPrediction(setPointCelsius: 71.06, mode: .removalAndResting)
        #expect(frame[6] == 0xC7)
        #expect(frame[7] == 0x0A)
    }

    @Test("set point clamps to the 10-bit field: high, negative, and non-finite")
    func encodeClamping() {
        // 150 °C → clamped to 1023 (0x3FF); packed 0x0BFF LE
        let high = ProbeUART.encodeSetPrediction(setPointCelsius: 150, mode: .removalAndResting)
        #expect(high[6] == 0xFF)
        #expect(high[7] == 0x0B)
        // −5 °C → clamped to 0; packed 0x0800 LE
        let low = ProbeUART.encodeSetPrediction(setPointCelsius: -5, mode: .removalAndResting)
        #expect(low[6] == 0x00)
        #expect(low[7] == 0x08)
        // NaN must not crash the UInt16 conversion
        let nan = ProbeUART.encodeSetPrediction(setPointCelsius: .nan, mode: .removalAndResting)
        #expect(nan[6] == 0x00)
        #expect(nan[7] == 0x08)
    }

    @Test("request layout: sync bytes, CRC placement, type, payload length")
    func requestLayout() {
        let frame = ProbeUART.encodeRequest(type: .setPrediction, payload: Data([0x84, 0x0B]))
        #expect(frame.count == ProbeUART.requestHeaderLength + 2)
        #expect(frame[0] == 0xCA && frame[1] == 0xFE)
        #expect(frame[4] == 0x05)   // message type
        #expect(frame[5] == 0x02)   // payload length
        // CRC over type+len+payload, little-endian on the wire
        let crc = ProbeUART.crc16ccitt(Data([0x05, 0x02, 0x84, 0x0B]))
        #expect(frame[2] == UInt8(crc & 0xFF))
        #expect(frame[3] == UInt8(crc >> 8))
    }

    // MARK: Response decoding

    @Test("decodes a success response")
    func decodeSuccess() {
        let responses = ProbeUART.decodeResponses(responseSuccess)
        #expect(responses == [ProbeUARTResponse(type: .setPrediction, success: true, payload: Data())])
    }

    @Test("decodes a failure response")
    func decodeFailure() {
        let responses = ProbeUART.decodeResponses(responseFailure)
        #expect(responses.count == 1)
        #expect(responses.first?.success == false)
    }

    @Test("two concatenated responses decode as two frames")
    func decodeConcatenated() {
        let responses = ProbeUART.decodeResponses(responseSuccess + responseFailure)
        #expect(responses.count == 2)
        #expect(responses[0].success == true)
        #expect(responses[1].success == false)
    }

    @Test("corrupted CRC yields no responses")
    func decodeBadCRC() {
        var bad = responseSuccess
        bad[2] ^= 0xFF
        #expect(ProbeUART.decodeResponses(bad).isEmpty)
    }

    @Test("wrong sync bytes yield no responses")
    func decodeBadSync() {
        var bad = responseSuccess
        bad[0] = 0xDE
        #expect(ProbeUART.decodeResponses(bad).isEmpty)
    }

    @Test("truncated frame yields no responses")
    func decodeTruncated() {
        #expect(ProbeUART.decodeResponses(responseSuccess.prefix(5)).isEmpty)
        #expect(ProbeUART.decodeResponses(Data()).isEmpty)
    }

    @Test("valid frame followed by garbage decodes the valid frame and stops")
    func decodeTrailingGarbage() {
        let responses = ProbeUART.decodeResponses(responseSuccess + Data([0x01, 0x02, 0x03,
                                                                          0x04, 0x05, 0x06, 0x07]))
        #expect(responses.count == 1)
    }
}

// MARK: - Manager command logic

#if os(iOS)
@Suite("ProbeBLEManager UART command logic")
@MainActor
struct ProbeUARTManagerTests {

    /// Manager wired to a fake central and already in the connected state.
    private func makeConnectedManager() -> (ProbeBLEManager, FakeProbeCentral) {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        return (mgr, fake)
    }

    @Test("setPrediction while connected writes the pinned frame once")
    func sendWritesFrame() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        #expect(fake.writtenUARTFrames == [frame90C])
        #expect(mgr.setPredictionFailed == false)
    }

    @Test("setPrediction while not connected writes nothing")
    func sendIgnoredWhenNotConnected() {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        #expect(fake.writtenUARTFrames.isEmpty)
    }

    @Test("success response settles the command — no retry, no failure flag")
    func successSettles() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        mgr.handleUARTNotification(responseSuccess)
        #expect(fake.writtenUARTFrames.count == 1)
        #expect(mgr.setPredictionFailed == false)
        // A stray duplicate response is ignored (nothing pending)
        mgr.handleUARTNotification(responseSuccess)
        #expect(fake.writtenUARTFrames.count == 1)
    }

    @Test("failure response retries once, second failure publishes setPredictionFailed")
    func failureRetriesThenGivesUp() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        mgr.handleUARTNotification(responseFailure)
        #expect(fake.writtenUARTFrames.count == 2)          // retry sent
        #expect(fake.writtenUARTFrames[1] == frame90C)      // same frame
        #expect(mgr.setPredictionFailed == false)           // not given up yet
        mgr.handleUARTNotification(responseFailure)
        #expect(fake.writtenUARTFrames.count == 2)          // no third attempt
        #expect(mgr.setPredictionFailed == true)
    }

    @Test("retry that succeeds does not set the failure flag")
    func retryThenSuccess() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        mgr.handleUARTNotification(responseFailure)
        mgr.handleUARTNotification(responseSuccess)
        #expect(fake.writtenUARTFrames.count == 2)
        #expect(mgr.setPredictionFailed == false)
    }

    @Test("a newer setPrediction supersedes the in-flight one (last write wins)")
    func newerSendSupersedes() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        mgr.setPrediction(setPointCelsius: 95.0, mode: .removalAndResting)
        #expect(fake.writtenUARTFrames == [frame90C, frame95C])
        // Failure answer now applies to the 95° command → retries the 95° frame
        mgr.handleUARTNotification(responseFailure)
        #expect(fake.writtenUARTFrames.last == frame95C)
        #expect(fake.writtenUARTFrames.count == 3)
    }

    @Test("disconnect drops the in-flight command without a failure flag")
    func disconnectDropsPending() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        guard case .connected(let id) = mgr.connectionState else {
            Issue.record("Expected connected state")
            return
        }
        mgr.handleDisconnected(id: id)
        // A late failure response must not trigger a retry or a failure flag
        mgr.handleUARTNotification(responseFailure)
        #expect(fake.writtenUARTFrames.count == 1)
        #expect(mgr.setPredictionFailed == false)
    }

    @Test("no response → timeout retries once, second timeout publishes failure")
    func timeoutRetriesThenGivesUp() async throws {
        let (mgr, fake) = makeConnectedManager()
        mgr.uartTimeoutSeconds = 0.05
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        #expect(fake.writtenUARTFrames.count == 1)
        // Wait past both timeout windows (generous margin for CI scheduling)
        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(fake.writtenUARTFrames.count == 2)
        #expect(mgr.setPredictionFailed == true)
    }

    @Test("response before the timeout cancels it — no spurious retry")
    func responseBeatsTimeout() async throws {
        let (mgr, fake) = makeConnectedManager()
        mgr.uartTimeoutSeconds = 0.05
        mgr.setPrediction(setPointCelsius: 90.0, mode: .removalAndResting)
        mgr.handleUARTNotification(responseSuccess)
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(fake.writtenUARTFrames.count == 1)
        #expect(mgr.setPredictionFailed == false)
    }
}

// MARK: - Target set-point rules (spec 3B)

@Suite("ProbeBLEManager target rules")
@MainActor
struct ProbeTargetRuleTests {

    private func makeConnectedManager() -> (ProbeBLEManager, FakeProbeCentral) {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        return (mgr, fake)
    }

    @Test("setTarget while connected sends removalAndResting with the target")
    func setTargetSends() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(95.0)
        #expect(fake.writtenUARTFrames == [frame95C])
    }

    @Test("setTarget with the same value again does not re-send")
    func setTargetDeduplicates() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(95.0)
        mgr.setTarget(95.0)
        #expect(fake.writtenUARTFrames.count == 1)
    }

    @Test("setTarget(nil) after a target sends a clear (mode none)")
    func clearTargetSendsClear() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(95.0)
        mgr.setTarget(nil)
        #expect(fake.writtenUARTFrames == [frame95C, frameClear])
    }

    @Test("setTarget(nil) when no target was ever set sends nothing")
    func clearWithoutTargetIsNoop() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(nil)
        #expect(fake.writtenUARTFrames.isEmpty)
    }

    @Test("setTarget while disconnected stores; handleUARTReady sends it after connect")
    func targetStoredUntilUARTReady() {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        mgr.setTarget(95.0)
        #expect(fake.writtenUARTFrames.isEmpty)

        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        mgr.handleUARTReady()
        #expect(fake.writtenUARTFrames == [frame95C])
    }

    @Test("handleUARTReady with no target sends nothing — must not clear a set point configured elsewhere")
    func uartReadyWithoutTargetIsSilent() {
        let (mgr, fake) = makeConnectedManager()
        mgr.handleUARTReady()
        #expect(fake.writtenUARTFrames.isEmpty)
    }

    @Test("handleUARTReady re-pushes the target after a reconnect")
    func uartReadyRepushesAfterReconnect() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(95.0)
        mgr.handleUARTNotification(responseSuccess)

        // Unexpected drop, then the link comes back and UART is rediscovered
        guard case .connected(let id) = mgr.connectionState else {
            Issue.record("Expected connected state")
            return
        }
        mgr.handleDisconnected(id: id)
        mgr.handleConnected(id: id)
        mgr.handleUARTReady()
        #expect(fake.writtenUARTFrames == [frame95C, frame95C])
    }

    @Test("detach clears the target and sends a clear to the probe")
    func detachClearsTarget() {
        let (mgr, fake) = makeConnectedManager()
        mgr.attach(toCookID: UUID())
        mgr.setTarget(95.0)
        mgr.detach()
        #expect(mgr.attachedCookID == nil)
        #expect(fake.writtenUARTFrames == [frame95C, frameClear])
        // A later UART-ready must not resurrect the cleared target
        mgr.handleUARTReady()
        #expect(fake.writtenUARTFrames.count == 2)
    }

    @Test("explicit disconnect drops the target without writing to the dying link")
    func disconnectDropsTargetSilently() {
        let (mgr, fake) = makeConnectedManager()
        mgr.setTarget(95.0)
        mgr.disconnect()
        #expect(fake.writtenUARTFrames == [frame95C])   // no clear frame added
        mgr.handleUARTReady()                            // stale callback → nothing
        #expect(fake.writtenUARTFrames.count == 1)
    }
}
#endif // os(iOS)

// MARK: - Temperature unit conversion (target entry)

@Suite("TemperatureUnit target conversion")
struct TemperatureUnitConversionTests {

    @Test("celsius(fromValue:) inverts value(fromCelsius:) in Fahrenheit")
    func fahrenheitRoundTrip() {
        let unit = TemperatureUnit.fahrenheit
        #expect(abs(unit.celsius(fromValue: 203) - 95.0) < 1e-9)
        #expect(abs(unit.celsius(fromValue: 32)) < 1e-9)
        let roundTrip = unit.celsius(fromValue: unit.value(fromCelsius: 71.06))
        #expect(abs(roundTrip - 71.06) < 1e-9)
    }

    @Test("celsius(fromValue:) is identity in Celsius")
    func celsiusIdentity() {
        #expect(TemperatureUnit.celsius.celsius(fromValue: 96.1) == 96.1)
    }
}
