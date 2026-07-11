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
// Nordic UART Service — the probe's command channel (host writes RX, probe answers on TX).
private let uartServiceUUID             = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
private let uartRXCharUUID              = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
private let uartTXCharUUID              = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
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
    /// Write a framed request to the probe's UART RX characteristic.
    /// No-op if not connected or the UART characteristics weren't discovered.
    func writeUART(_ data: Data)
}

// MARK: - DiscoveredProbe

/// Lightweight value type representing a probe discovered during a BLE scan.
struct DiscoveredProbe: Identifiable, Equatable {
    let id: UUID
    var name: String?
    /// Combustion serial as 8-digit hex (e.g. "1000FADE"), parsed from advertising data.
    var serial: String?
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
    /// The id of the cook (BBQTimer) this probe is currently attached to.
    /// nil means the probe is connected but not yet assigned to any cook.
    @Published private(set) var attachedCookID: UUID? = nil

    /// True when the most recent Set Prediction command gave up (failure response
    /// or no response, after one retry). Cleared on the next send. UI may surface
    /// this as a non-blocking "couldn't set target on probe" note — the phone-side
    /// crossing alert works regardless, so a failed write degrades gracefully.
    @Published private(set) var setPredictionFailed: Bool = false

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
    /// Also clears `attachedCookID` — an explicit disconnect ends the cook association.
    func disconnect() {
        shouldReconnect = false
        attachedCookID = nil
        cancelPendingUART()
        central.disconnect()
    }

    // MARK: - Cook attachment

    /// Associate the probe with a specific cook (timer). Call after the probe connects
    /// and the user has picked which cook the probe belongs to.
    func attach(toCookID id: UUID) {
        attachedCookID = id
    }

    /// Remove the cook association without disconnecting the probe.
    func detach() {
        attachedCookID = nil
    }

    // MARK: - UART commands (host → probe)
    //
    // One command in flight at a time. If the probe answers "failure" or doesn't
    // answer within `uartTimeoutSeconds`, the frame is retried once, then the
    // command is abandoned and `setPredictionFailed` is published. Set Prediction
    // is currently the only command; a newer send supersedes an in-flight one
    // (last write wins — the probe holds a single set point anyway).

    private struct PendingUARTCommand {
        /// Fresh per (re)send so a stale timeout can't fire against a newer send.
        let token: UUID
        let frame: Data
        let type: ProbeUARTMessageType
        let isRetry: Bool
    }

    private var pendingUART: PendingUARTCommand?
    private var uartTimeoutTask: Task<Void, Never>?

    /// How long to wait for a UART response before retrying. Internal so tests
    /// can shorten it; the probe normally answers within one connection interval.
    var uartTimeoutSeconds: TimeInterval = 2.0

    /// Send the probe its prediction set point (target core temp) and mode.
    /// Ignored unless connected — (re)send-on-reconnect rules live with the
    /// target-temperature feature (spec step 3B), not here.
    func setPrediction(setPointCelsius: Double, mode: PredictionMode) {
        guard case .connected = connectionState else { return }
        setPredictionFailed = false
        let frame = ProbeUART.encodeSetPrediction(setPointCelsius: setPointCelsius, mode: mode)
        sendUART(PendingUARTCommand(token: UUID(), frame: frame, type: .setPrediction, isRetry: false))
    }

    /// Called when the UART TX characteristic fires a notification.
    /// Matches responses against the in-flight command by message type.
    func handleUARTNotification(_ data: Data) {
        guard let pending = pendingUART else { return }
        guard let response = ProbeUART.decodeResponses(data).first(where: { $0.type == pending.type })
        else { return }
        uartTimeoutTask?.cancel()
        if response.success {
            pendingUART = nil
        } else {
            retryOrGiveUp(pending)
        }
    }

    private func sendUART(_ command: PendingUARTCommand) {
        uartTimeoutTask?.cancel()
        pendingUART = command
        central.writeUART(command.frame)
        let token = command.token
        uartTimeoutTask = Task { [weak self, timeout = uartTimeoutSeconds] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.handleUARTTimeout(token: token)
        }
    }

    /// Timeout path — only acts if the timed-out send is still the one in flight.
    private func handleUARTTimeout(token: UUID) {
        guard let pending = pendingUART, pending.token == token else { return }
        retryOrGiveUp(pending)
    }

    private func retryOrGiveUp(_ pending: PendingUARTCommand) {
        if pending.isRetry {
            cancelPendingUART()
            setPredictionFailed = true
        } else {
            sendUART(PendingUARTCommand(token: UUID(), frame: pending.frame,
                                        type: pending.type, isRetry: true))
        }
    }

    /// Drop any in-flight command without publishing a failure — used when the
    /// link goes away (the response is never coming).
    private func cancelPendingUART() {
        uartTimeoutTask?.cancel()
        uartTimeoutTask = nil
        pendingUART = nil
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
    func handleDiscovered(id: UUID, name: String?, serial: String?, rssi: Int) {
        if let serial { serialsByID[id] = serial }
        if let index = discoveredProbes.firstIndex(where: { $0.id == id }) {
            discoveredProbes[index].name = name
            discoveredProbes[index].rssi = rssi
            if let serial { discoveredProbes[index].serial = serial }
        } else {
            discoveredProbes.append(DiscoveredProbe(id: id, name: name, serial: serial, rssi: rssi))
        }
    }

    /// Serial numbers seen per peripheral id, so the connected-status line can show the
    /// serial even after the discovered list is cleared.
    private(set) var serialsByID: [UUID: String] = [:]

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
        cancelPendingUART()
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

    /// UART RX characteristic (host → probe writes), captured during discovery.
    /// Belongs to `connectedPeripheral`; cleared whenever the link drops and
    /// re-captured on the next service discovery.
    private var uartRXCharacteristic: CBCharacteristic?

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
        uartRXCharacteristic = nil
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
            connectedPeripheral = nil    // only user-initiated path clears this
        }
    }

    func writeUART(_ data: Data) {
        guard let peripheral = connectedPeripheral,
              let rx = uartRXCharacteristic else { return }
        // Prefer acknowledged writes when the characteristic supports them.
        let writeType: CBCharacteristicWriteType =
            rx.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: rx, type: writeType)
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
        // Parse the Combustion serial from the advertising manufacturer data so the
        // picker can label the probe by serial instead of "Unknown Probe".
        let serial = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)
            .flatMap { ProbeAdvertising.serialHex(fromManufacturerData: $0) }
        Task { @MainActor in
            manager?.handleDiscovered(
                id: peripheral.identifier,
                name: peripheral.name,
                serial: serial,
                rssi: RSSI.intValue
            )
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover the status service (live data) and the UART service (commands).
        // Also covers re-subscribe after reconnect.
        peripheral.discoverServices([probeStatusServiceUUID, uartServiceUUID])
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
        // initiated) clears `connectedPeripheral`. The UART characteristic IS
        // invalidated by a disconnect; it is re-captured on the next discovery.
        uartRXCharacteristic = nil
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
            peripheral.discoverServices([probeStatusServiceUUID, uartServiceUUID])
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
        for service in peripheral.services ?? [] {
            switch service.uuid {
            case probeStatusServiceUUID:
                peripheral.discoverCharacteristics([probeStatusCharUUID], for: service)
            case uartServiceUUID:
                peripheral.discoverCharacteristics([uartRXCharUUID, uartTXCharUUID], for: service)
            default:
                break
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case probeStatusCharUUID, uartTXCharUUID:
                // Subscribe: live temperatures (status) and command responses (UART TX)
                peripheral.setNotifyValue(true, for: characteristic)
            case uartRXCharUUID:
                uartRXCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        switch characteristic.uuid {
        case probeStatusCharUUID:
            Task { @MainActor in
                manager?.handleStatusNotification(data)
            }
        case uartTXCharUUID:
            Task { @MainActor in
                manager?.handleUARTNotification(data)
            }
        default:
            break
        }
    }
}

#endif // os(iOS)
