// ProbeBLEManagerTests.swift
// Grill Time Pro
//
// Swift Testing suite for ProbeBLEManager.
// Uses FakeProbeCentral to avoid any real CoreBluetooth dependency.
// All tests call the manager's public + handler methods directly.

import Testing
import Foundation
@testable import JF_BBQ_Timer

// MARK: - FakeProbeCentral

/// Records every command issued by ProbeBLEManager so tests can assert on them.
#if os(iOS)
final class FakeProbeCentral: ProbeCentral {

    // Call-tracking counters
    private(set) var startScanCallCount  = 0
    private(set) var stopScanCallCount   = 0
    private(set) var connectCallCount    = 0
    private(set) var disconnectCallCount = 0

    // Last arguments
    private(set) var lastConnectID: UUID?

    func startScan()                  { startScanCallCount  += 1 }
    func stopScan()                   { stopScanCallCount   += 1 }
    func connect(identifier: UUID)    { connectCallCount    += 1; lastConnectID = identifier }
    func disconnect()                 { disconnectCallCount += 1 }
}
#endif

// MARK: - Payload helper
//
// Builds a valid ≥30-byte ProbeStatus payload identical to the one used in
// ProbeStatusDecoderTests, so we get a known core temperature.
// core sensor = T3, T3 raw = 100 → -15.0 °C (via virtual-sensor byte 0xA5).

private func makeValidPayload() -> Data {
    var bytes = [UInt8](repeating: 0, count: 35)
    // minLog = 1 LE
    bytes[0] = 0x01
    // maxLog = 256 LE
    bytes[5] = 0x01
    // temp block: wire-order (reversed fromReversed layout) matching the updated decoder.
    // Decodes to: T1=-20°C, T2=0°C, T3=-15°C, T4=-10°C, T5=-19.95°C, T6=389.55°C, T7=253.05°C, T8=116.5°C
    let tempBlock: [UInt8] = [0x00, 0x00, 0x32, 0x90, 0x01, 0x64, 0x10, 0x00, 0xFE, 0x7F, 0x55, 0x55, 0x55]
    for (i, b) in tempBlock.enumerated() { bytes[8 + i] = b }
    // ModeId = 0x29 (instantRead, color3, ID2)
    bytes[21] = 0x29
    // BattVS = 0xA5 (battery low, core=T3, surface=T6, ambient=T7)
    bytes[22] = 0xA5
    // prediction block
    let predBlock: [UInt8] = [0x53, 0xE4, 0x22, 0x03, 0x4B, 0xC0, 0x5D]
    for (i, b) in predBlock.enumerated() { bytes[23 + i] = b }
    return Data(bytes)
}

// MARK: - Test suite

#if os(iOS)
@Suite("ProbeBLEManager state logic")
@MainActor
struct ProbeBLEManagerTests {

    // MARK: Helpers

    /// Creates a manager wired to a fresh FakeProbeCentral and returns both.
    private func makeManager() -> (ProbeBLEManager, FakeProbeCentral) {
        let fake = FakeProbeCentral()
        let mgr  = ProbeBLEManager(central: fake)
        return (mgr, fake)
    }

    // MARK: 1. startScanning

    @Test("startScanning sets state to .scanning and calls central.startScan")
    func startScanningCallsCentral() {
        let (mgr, fake) = makeManager()
        mgr.startScanning()
        #expect(mgr.connectionState == .scanning)
        #expect(fake.startScanCallCount == 1)
    }

    // MARK: 2. handleCentralStateChange

    @Test("handleCentralStateChange(poweredOn: false) sets bluetoothReady=false and state .poweredOff")
    func bluetoothPoweredOff() {
        let (mgr, _) = makeManager()
        mgr.handleCentralStateChange(poweredOn: false)
        #expect(mgr.bluetoothReady == false)
        #expect(mgr.connectionState == .poweredOff)
    }

    @Test("handleCentralStateChange(poweredOn: true) sets bluetoothReady=true")
    func bluetoothPoweredOn() {
        let (mgr, _) = makeManager()
        // Start from poweredOff
        mgr.handleCentralStateChange(poweredOn: false)
        mgr.handleCentralStateChange(poweredOn: true)
        #expect(mgr.bluetoothReady == true)
    }

    @Test("handleCentralStateChange(poweredOn: true) restores idle from poweredOff")
    func bluetoothPoweredOnRestoresIdle() {
        let (mgr, _) = makeManager()
        mgr.handleCentralStateChange(poweredOn: false)
        #expect(mgr.connectionState == .poweredOff)
        mgr.handleCentralStateChange(poweredOn: true)
        #expect(mgr.connectionState == .idle)
    }

    @Test("handleCentralStateChange(poweredOn: false) clears discoveredProbes and latestReading")
    func poweredOffClearsState() {
        let (mgr, _) = makeManager()
        // Seed some state
        mgr.handleCentralStateChange(poweredOn: true)
        mgr.handleDiscovered(id: UUID(), name: "Probe A", rssi: -55)
        mgr.handleStatusNotification(makeValidPayload())

        mgr.handleCentralStateChange(poweredOn: false)
        #expect(mgr.discoveredProbes.isEmpty)
        #expect(mgr.latestReading == nil)
    }

    // MARK: 3. handleDiscovered — upsert behaviour

    @Test("handleDiscovered with new ID appends to discoveredProbes")
    func discoverNewProbe() {
        let (mgr, _) = makeManager()
        let id = UUID()
        mgr.handleDiscovered(id: id, name: "Probe A", rssi: -60)
        #expect(mgr.discoveredProbes.count == 1)
        #expect(mgr.discoveredProbes[0].id == id)
        #expect(mgr.discoveredProbes[0].name == "Probe A")
        #expect(mgr.discoveredProbes[0].rssi == -60)
    }

    @Test("handleDiscovered with same ID updates existing entry (upsert)")
    func discoverSameProbeUpdates() {
        let (mgr, _) = makeManager()
        let id = UUID()
        mgr.handleDiscovered(id: id, name: "Probe A", rssi: -60)
        mgr.handleDiscovered(id: id, name: "Probe A v2", rssi: -45)
        #expect(mgr.discoveredProbes.count == 1)
        #expect(mgr.discoveredProbes[0].name == "Probe A v2")
        #expect(mgr.discoveredProbes[0].rssi == -45)
    }

    @Test("handleDiscovered with two different IDs produces two entries")
    func discoverTwoDifferentProbes() {
        let (mgr, _) = makeManager()
        mgr.handleDiscovered(id: UUID(), name: "Probe A", rssi: -60)
        mgr.handleDiscovered(id: UUID(), name: "Probe B", rssi: -70)
        #expect(mgr.discoveredProbes.count == 2)
    }

    // MARK: 4. connect / handleConnected

    @Test("connect(id) sets state to .connecting and calls central.connect")
    func connectCallsCentral() {
        let (mgr, fake) = makeManager()
        let id = UUID()
        mgr.connect(id)
        if case .connecting(let connID) = mgr.connectionState {
            #expect(connID == id)
        } else {
            Issue.record("Expected .connecting state, got \(mgr.connectionState)")
        }
        #expect(fake.connectCallCount == 1)
        #expect(fake.lastConnectID == id)
    }

    @Test("handleConnected(id) transitions state to .connected")
    func handleConnectedTransitionsState() {
        let (mgr, _) = makeManager()
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        if case .connected(let connID) = mgr.connectionState {
            #expect(connID == id)
        } else {
            Issue.record("Expected .connected state, got \(mgr.connectionState)")
        }
    }

    // MARK: 5. handleStatusNotification

    @Test("handleStatusNotification with valid payload sets latestReading with correct core temp")
    func validPayloadSetsLatestReading() {
        let (mgr, _) = makeManager()
        let payload = makeValidPayload()
        mgr.handleStatusNotification(payload)
        // core sensor = T3, T3 raw 100 → -15.0 °C
        #expect(mgr.latestReading != nil)
        if let reading = mgr.latestReading {
            #expect(abs(reading.coreTempC - (-15.0)) < 1e-6)
        }
    }

    @Test("handleStatusNotification with short payload leaves latestReading unchanged")
    func shortPayloadLeavesReadingUnchanged() {
        let (mgr, _) = makeManager()
        // Seed a valid reading first
        mgr.handleStatusNotification(makeValidPayload())
        let previousReading = mgr.latestReading

        // Now send a too-short payload (< 30 bytes)
        let shortData = Data(repeating: 0, count: 10)
        mgr.handleStatusNotification(shortData)

        // latestReading must not have changed
        #expect(mgr.latestReading != nil)
        if let prev = previousReading, let current = mgr.latestReading {
            #expect(prev.minLogSequence == current.minLogSequence)
        }
    }

    @Test("handleStatusNotification with empty Data leaves latestReading nil (never set)")
    func emptyPayloadDoesNotSetReading() {
        let (mgr, _) = makeManager()
        mgr.handleStatusNotification(Data())
        #expect(mgr.latestReading == nil)
    }

    // MARK: 6. handleDisconnected

    @Test("handleDisconnected sets state to .disconnected and clears latestReading")
    func handleDisconnectedClearsState() {
        let (mgr, _) = makeManager()
        let id = UUID()
        mgr.connect(id)
        mgr.handleConnected(id: id)
        mgr.handleStatusNotification(makeValidPayload())
        // Verify we have a reading before disconnect
        #expect(mgr.latestReading != nil)

        mgr.handleDisconnected(id: id)
        #expect(mgr.connectionState == .disconnected)
        // latestReading is cleared on disconnect (stale data policy)
        #expect(mgr.latestReading == nil)
    }

    // MARK: stopScanning

    @Test("stopScanning from .scanning sets state to .idle and calls central.stopScan")
    func stopScanningCallsCentral() {
        let (mgr, fake) = makeManager()
        mgr.startScanning()
        mgr.stopScanning()
        #expect(mgr.connectionState == .idle)
        #expect(fake.stopScanCallCount == 1)
    }

    // MARK: disconnect

    @Test("disconnect calls central.disconnect")
    func disconnectCallsCentral() {
        let (mgr, fake) = makeManager()
        mgr.disconnect()
        #expect(fake.disconnectCallCount == 1)
    }
}
#endif // os(iOS)
