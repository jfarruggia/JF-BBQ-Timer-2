// ProbeHealthTests.swift
// Grill Time Pro
//
// Swift Testing suite for probe health (spec 3E): the Overheating Sensors
// byte decode and the manager's one-shot battery-low / overheating events.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - Payload builder

/// Same base payload as ProbeBLEManagerTests.makeValidPayload (battery-low bit
/// set via BattVS 0xA5), extended to the full 49+ bytes so the Overheating
/// Sensors byte at offset 48 is present.
private func makePayload(batteryLow: Bool = true, overheatByte: UInt8 = 0, length: Int = 49) -> Data {
    var bytes = [UInt8](repeating: 0, count: length)
    bytes[0] = 0x01                                   // minLog = 1 LE
    bytes[5] = 0x01                                   // maxLog = 256 LE
    let tempBlock: [UInt8] = [0x00, 0x00, 0x32, 0x90, 0x01, 0x64, 0x10,
                              0x00, 0xFE, 0x7F, 0x55, 0x55, 0x55]
    for (i, b) in tempBlock.enumerated() { bytes[8 + i] = b }
    bytes[21] = 0x29                                  // instantRead, color3, ID2
    bytes[22] = batteryLow ? 0xA5 : 0xA4              // bit 0 = battery status
    let predBlock: [UInt8] = [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
    for (i, b) in predBlock.enumerated() { bytes[23 + i] = b }
    if length >= 49 { bytes[48] = overheatByte }
    return Data(bytes)
}

// MARK: - Decoder

@Suite("Overheating Sensors decode")
struct OverheatDecodeTests {

    @Test("byte 48 decodes; zero means not overheating")
    func decodesHealthy() throws {
        let reading = try #require(ProbeReading.decode(data: makePayload(overheatByte: 0)))
        #expect(reading.overheatingSensors == 0)
        #expect(reading.isOverheating == false)
    }

    @Test("any set bit means overheating")
    func decodesOverheat() throws {
        let t1 = try #require(ProbeReading.decode(data: makePayload(overheatByte: 0b0000_0001)))
        #expect(t1.isOverheating == true)
        let t8 = try #require(ProbeReading.decode(data: makePayload(overheatByte: 0b1000_0000)))
        #expect(t8.isOverheating == true)
    }

    @Test("short payload (no byte 48) → nil sensors, treated as not overheating")
    func shortPayloadIsHealthy() throws {
        let reading = try #require(ProbeReading.decode(data: makePayload(length: 35)))
        #expect(reading.overheatingSensors == nil)
        #expect(reading.isOverheating == false)
    }
}

// MARK: - Manager one-shots

#if os(iOS)
@Suite("ProbeBLEManager health one-shots")
@MainActor
struct ProbeHealthEventTests {

    private func makeConnectedManager() -> (ProbeBLEManager, FakeProbeCentral) {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        return (mgr, fake)
    }

    private func collectEvents(_ mgr: ProbeBLEManager) -> () -> [ProbeCookEvent] {
        // Reference wrapper so the closure can accumulate
        final class Box { var events: [ProbeCookEvent] = [] }
        let box = Box()
        mgr.onCookEvent = { box.events.append($0) }
        return { box.events }
    }

    @Test("battery low fires once per connection, not on every reading")
    func batteryLowOnce() {
        let (mgr, _) = makeConnectedManager()
        let events = collectEvents(mgr)
        mgr.handleStatusNotification(makePayload(batteryLow: true))
        mgr.handleStatusNotification(makePayload(batteryLow: true))
        #expect(events().filter { $0 == .batteryLow }.count == 1)
    }

    @Test("healthy battery never fires")
    func healthyBatterySilent() {
        let (mgr, _) = makeConnectedManager()
        let events = collectEvents(mgr)
        mgr.handleStatusNotification(makePayload(batteryLow: false))
        #expect(events().contains(.batteryLow) == false)
    }

    @Test("overheating fires once; healthy readings never fire")
    func overheatOnce() {
        let (mgr, _) = makeConnectedManager()
        let events = collectEvents(mgr)
        mgr.handleStatusNotification(makePayload(overheatByte: 0))
        mgr.handleStatusNotification(makePayload(overheatByte: 0x04))
        mgr.handleStatusNotification(makePayload(overheatByte: 0x04))
        #expect(events().filter { $0 == .overheating }.count == 1)
    }

    @Test("a fresh user connect() re-arms the health one-shots")
    func freshConnectRearms() {
        let (mgr, _) = makeConnectedManager()
        let events = collectEvents(mgr)
        mgr.handleStatusNotification(makePayload(batteryLow: true))
        #expect(events().filter { $0 == .batteryLow }.count == 1)

        // User disconnects and connects again — a new session may re-warn
        mgr.disconnect()
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        mgr.handleStatusNotification(makePayload(batteryLow: true))
        #expect(events().filter { $0 == .batteryLow }.count == 2)
    }

    @Test("auto-reconnect blip does NOT re-fire the health warnings")
    func reconnectBlipStaysQuiet() {
        let (mgr, _) = makeConnectedManager()
        let events = collectEvents(mgr)
        mgr.handleStatusNotification(makePayload(batteryLow: true))

        // Unexpected drop + reconnection (no user connect() intent)
        guard case .connected(let id) = mgr.connectionState else {
            Issue.record("Expected connected state")
            return
        }
        mgr.handleDisconnected(id: id)
        mgr.handleConnected(id: id)
        mgr.handleStatusNotification(makePayload(batteryLow: true))
        #expect(events().filter { $0 == .batteryLow }.count == 1)
    }
}
#endif // os(iOS)
