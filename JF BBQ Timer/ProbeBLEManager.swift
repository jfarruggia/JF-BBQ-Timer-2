// ProbeBLEManager.swift
// Grill Time Pro
//
// Foreground CoreBluetooth connection layer for the Combustion Predictive Probe.
// All CoreBluetooth and UI code is gated behind #if os(iOS) so this file is
// safe to compile into both the iOS app target and the watchOS companion target.
// The watch must NEVER open its own BLE connection — the iPhone owns it.
//
// Required Info.plist keys (add manually in Xcode — do NOT edit Info.plist here):
//   NSBluetoothAlwaysUsageDescription  — user-facing permission prompt string
//   UIBackgroundModes                  — add "bluetooth-central" for background scanning

#if os(iOS)

import Foundation
import Combine
import CoreBluetooth

// MARK: - BLE Constants

private let probeStatusServiceUUID      = CBUUID(string: "00000100-CAAB-3792-3D44-97AE51C1407A")
private let probeStatusCharUUID         = CBUUID(string: "00000101-CAAB-3792-3D44-97AE51C1407A")
// Combustion Bluetooth Vendor ID (0x09C7) will be used for manufacturer-data
// filtering when advertising-packet parsing is added (Phase 2 nice-to-have).

// MARK: - ProbeCentral protocol

/// Commands issued by ProbeBLEManager to the underlying BLE transport.
/// Keeping this a protocol means tests can substitute a fake implementation.
protocol ProbeCentral: AnyObject {
    func startScan()
    func stopScan()
    func connect(identifier: UUID)
    func disconnect()
    /// Re-issue a CoreBluetooth connect for the peripheral retained from the last
    /// `connect(identifier:)` call. Called by the manager when an unexpected disconnect
    /// occurs and the user's intent is still "connected". No-op if no peripheral is retained.
    func reconnect()
}

// MARK: - DiscoveredProbe

/// Lightweight value type representing a probe discovered during a BLE scan.
struct DiscoveredProbe: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
}

// MARK: - ProbeConnectionState

/// Published state machine for the BLE connection lifecycle.
enum ProbeConnectionState: Equatable {
    case poweredOff
    case idle
    case scanning
    case connecting(UUID)
    case connected(UUID)
    /// Probe disconnected unexpectedly; manager is actively trying to reconnect.
    case reconnecting(UUID)
    case disconnected
}

// MARK: - ProbeBLEManager

/// Observable manager that owns all state and decision logic for the probe BLE connection.
/// CoreBluetooth delegate callbacks are thin adapters — they extract plain values and
/// call the `handle…` methods here. This design lets the manager be fully unit-tested
/// without any CoreBluetooth objects.
@MainActor
final class ProbeBLEManager: ObservableObject {

    // MARK: Published state

    @Published private(set) var connectionState: ProbeConnectionState = .idle
    @Published private(set) var discoveredProbes: [DiscoveredProbe] = []
    @Published private(set) var latestReading: ProbeReading?
    @Published private(set) var bluetoothReady: Bool = false

    // MARK: Private

    /// The underlying BLE transport. Injected at init for testability.
    private let central: ProbeCentral

    /// True while the user's intent is "stay connected".
    /// Set by `connect(_:)`; cleared by `disconnect()` (explicit user action).
    /// When the probe disconnects unexpectedly and this is `true`, the manager
    /// enters `.reconnecting` and issues `central.reconnect()`.
    private var shouldReconnect: Bool = false

    // MARK: Init

    /// - Parameter central: BLE transport to use. Defaults to the real CoreBluetooth
    ///   implementation. Pass a `FakeProbeCentral` in unit tests.
    init(central: ProbeCentral? = nil) {
        if let central {
            self.central = central
        } else {
            let real = CoreBluetoothProbeCentral()
            self.central = real
            real.manager = self
        }
    }

    // MARK: - Public intent methods

    /// Begin scanning for nearby Combustion probes.
    /// Transitions state to `.scanning` and calls through to the central.
    func startScanning() {
        connectionState = .scanning
        central.startScan()
    }

    /// Stop an in-progress scan.
    /// Transitions state to `.idle` unless already connected.
    func stopScanning() {
        if case .scanning = connectionState {
            connectionState = .idle
        }
        central.stopScan()
    }

    /// Initiate a connection to the probe with the given peripheral identifier.
    /// Sets `shouldReconnect = true` so the manager will auto-reconnect on
    /// unexpected disconnects until the user explicitly calls `disconnect()`.
    func connect(_ id: UUID) {
        shouldReconnect = true
        connectionState = .connecting(id)
        central.connect(identifier: id)
    }

    /// Disconnect from the currently connected probe.
    /// Clears `shouldReconnect` so the manager does NOT auto-reconnect after this.
    func disconnect() {
        shouldReconnect = false
        central.disconnect()
    }

    // MARK: - Event handler methods (called by the CB delegate adapter)
    //
    // All parameters are plain Swift value types — no CoreBluetooth objects cross
    // this boundary. Tests call these methods directly.

    /// Called when the CBCentralManager's state changes.
    /// `poweredOn: true` → ready to scan; `false` → not usable.
    func handleCentralStateChange(poweredOn: Bool) {
        bluetoothReady = poweredOn
        if !poweredOn {
            connectionState = .poweredOff
            discoveredProbes = []
            latestReading = nil
        } else {
            // Restore to idle if we were in poweredOff
            if case .poweredOff = connectionState {
                connectionState = .idle
            }
        }
    }

    /// Called when a peripheral is discovered during a scan.
    /// Upserts into `discoveredProbes` (same id → update rssi/name; new id → append).
    func handleDiscovered(id: UUID, name: String?, rssi: Int) {
        if let index = discoveredProbes.firstIndex(where: { $0.id == id }) {
            discoveredProbes[index].name = name
            discoveredProbes[index].rssi = rssi
        } else {
            discoveredProbes.append(DiscoveredProbe(id: id, name: name, rssi: rssi))
        }
    }

    /// Called when the central successfully connected to a peripheral.
    func handleConnected(id: UUID) {
        connectionState = .connected(id)
    }

    /// Called when a peripheral disconnects (expected or unexpected).
    /// Clears `latestReading` on disconnect — the data is stale once the link drops.
    /// If `shouldReconnect` is true (user-initiated connection still active), the
    /// manager enters `.reconnecting` and issues `central.reconnect()` so CoreBluetooth
    /// will re-establish the link as soon as the peripheral is in range again.
    func handleDisconnected(id: UUID) {
        latestReading = nil
        if shouldReconnect {
            connectionState = .reconnecting(id)
            central.reconnect()
        } else {
            connectionState = .disconnected
        }
    }

    /// Called by `CoreBluetoothProbeCentral.willRestoreState` to re-establish the
    /// manager's intent after a CoreBluetooth state-restoration wake.
    /// - Parameters:
    ///   - id:        Identifier of the restored peripheral.
    ///   - connected: Whether the peripheral is still connected at restoration time.
    func noteRestored(id: UUID, connected: Bool) {
        shouldReconnect = true
        connectionState = connected ? .connected(id) : .reconnecting(id)
    }

    /// Called when the probe status characteristic fires a notification.
    /// Decodes the raw bytes; if valid, updates `latestReading`.
    /// Short or malformed data leaves `latestReading` unchanged.
    func handleStatusNotification(_ data: Data) {
        #if DEBUG
        // Log the raw payload as hex so real-probe notifications can be copied from
        // the Xcode console and pinned as decoder test fixtures (Phase 2B item c).
        let hex = data.map { String(format: "%02X", $0) }.joined()
        debugLog("🌡️ Probe status payload (\(data.count) bytes): \(hex)")
        #endif
        guard let reading = ProbeReading.decode(data: data) else { return }
        latestReading = reading
    }
}

// MARK: - CoreBluetoothProbeCentral

/// Real CoreBluetooth transport. Thin adapter only — all logic lives in `ProbeBLEManager`.
/// This class is NOT unit-tested (CBCentralManager cannot be instantiated in tests).
final class CoreBluetoothProbeCentral: NSObject, ProbeCentral {

    // MARK: Private CB objects

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    /// Peripherals retained from discovery, keyed by identifier. A CBPeripheral must
    /// be strongly held for a connection to succeed, and looking it up here is more
    /// reliable than `retrievePeripherals(withIdentifiers:)` right after a scan.
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    /// Back-reference to the manager; set immediately after init.
    weak var manager: ProbeBLEManager?

    override init() {
        super.init()
        // Initialise on the main queue so delegate calls arrive on Main.
        // The restore identifier opts this central into CoreBluetooth state restoration:
        // the system will re-launch the app and call willRestoreState if the app was
        // suspended while an active BLE connection (or pending connect) was in progress.
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey:
                          "com.jamesfarruggia.grilltime.probe.central"]
        )
    }

    // MARK: ProbeCentral conformance

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(
            withServices: [probeStatusServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScan() {
        centralManager.stopScan()
    }

    func connect(identifier: UUID) {
        centralManager.stopScan()
        // Prefer the peripheral retained from discovery; fall back to the system cache.
        let peripheral = discoveredPeripherals[identifier]
            ?? centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
        guard let peripheral else { return }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    /// Re-issue a connect for the peripheral that was last connected.
    /// CoreBluetooth will reconnect with no timeout as soon as the peripheral
    /// is back in range; `connectedPeripheral` MUST still be set (kept on
    /// unexpected disconnect, cleared only by `disconnect()`).
    func reconnect() {
        guard let p = connectedPeripheral else { return }
        centralManager.connect(p, options: nil)
    }

    func disconnect() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
            connectedPeripheral = nil    // only user-initiated path clears this
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension CoreBluetoothProbeCentral: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            manager?.handleCentralStateChange(poweredOn: central.state == .poweredOn)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Retain the peripheral so we can connect to it reliably when the user taps it.
        discoveredPeripherals[peripheral.identifier] = peripheral
        Task { @MainActor in
            manager?.handleDiscovered(
                id: peripheral.identifier,
                name: peripheral.name,
                rssi: RSSI.intValue
            )
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover only the probe status service (also covers re-subscribe after reconnect)
        peripheral.discoverServices([probeStatusServiceUUID])
        Task { @MainActor in
            manager?.handleConnected(id: peripheral.identifier)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        // Do NOT nil connectedPeripheral here — if the manager wants to reconnect it
        // calls `reconnect()` which needs the reference. Only `disconnect()` (user-
        // initiated) clears `connectedPeripheral`.
        Task { @MainActor in
            manager?.handleDisconnected(id: peripheral.identifier)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        // Same policy: keep the peripheral so a reconnect attempt can reuse it.
        Task { @MainActor in
            manager?.handleDisconnected(id: peripheral.identifier)
        }
    }

    /// CoreBluetooth state restoration — called when the system relaunches the app
    /// after it was suspended while an active BLE session (or pending connect) existed.
    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        // Recover any peripherals that were connected (or connecting) at suspend time.
        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey]
                as? [CBPeripheral],
              let peripheral = peripherals.first
        else { return }

        // Re-adopt the peripheral into our local state.
        peripheral.delegate = self
        connectedPeripheral = peripheral
        discoveredPeripherals[peripheral.identifier] = peripheral

        let isConnected = (peripheral.state == .connected)

        // Tell the manager to restore its intent and publish the correct state.
        Task { @MainActor in
            manager?.noteRestored(id: peripheral.identifier, connected: isConnected)
        }

        if isConnected {
            // Already connected — re-discover services to re-subscribe to notifications.
            peripheral.discoverServices([probeStatusServiceUUID])
        } else {
            // Not yet connected — issue a new connect; CB will pick it up when BT is ready.
            central.connect(peripheral, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension CoreBluetoothProbeCentral: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let service = peripheral.services?.first(where: {
            $0.uuid == probeStatusServiceUUID
        }) else { return }
        peripheral.discoverCharacteristics([probeStatusCharUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == probeStatusCharUUID
        }) else { return }
        // Subscribe to notifications so we get live temperature updates
        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, characteristic.uuid == probeStatusCharUUID else { return }
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            manager?.handleStatusNotification(data)
        }
    }
}

#endif // os(iOS)
