// ProbeWatchForwarder.swift
// Grill Time Pro
//
// iOS-only glue between ProbeBLEManager and WCSessionManager.
// This is the ONLY place where WatchConnectivity meets the BLE probe layer.
// ProbeBLEManager remains WC-free so its unit tests stay pure.

#if os(iOS)

import Foundation
import Combine

// MARK: - ProbeWatchForwarder

/// Subscribes to `ProbeBLEManager` published state and forwards compact probe
/// readings to the Apple Watch via `WCSessionManager.sendProbeReading`.
///
/// Throttled to at most one send per `minInterval` seconds, with exceptions:
/// connection state transitions and valid↔invalid reading transitions always
/// forward immediately to keep the watch in sync.
@MainActor
final class ProbeWatchForwarder {

    // MARK: - Configuration

    /// Minimum time between forwarded readings during steady-state streaming.
    private let minInterval: TimeInterval

    // MARK: - Private state

    private var cancellables = Set<AnyCancellable>()
    private var lastSentAt: Date? = nil
    private var lastConnected: Bool? = nil
    private var lastHadValidReading: Bool? = nil
    private var lastPhase: ProbeCookPhase? = nil
    /// Read at send time for the target temp (not published; changes always
    /// coincide with a phase reset, which triggers a forward anyway).
    private weak var bleManager: ProbeBLEManager?

    // MARK: - Init

    /// - Parameters:
    ///   - bleManager:   The shared `ProbeBLEManager` to observe.
    ///   - minInterval:  Minimum forwarding interval (default 1.0 s).
    init(bleManager: ProbeBLEManager, minInterval: TimeInterval = 1.0) {
        self.minInterval = minInterval
        self.bleManager = bleManager
        subscribe(to: bleManager)
    }

    // MARK: - Combine subscription

    private func subscribe(to ble: ProbeBLEManager) {
        // Combine the published properties so any change triggers a re-evaluation.
        ble.$latestReading
            .combineLatest(ble.$connectionState, ble.$cookPhase)
            .receive(on: RunLoop.main)
            .sink { [weak self] reading, state, phase in
                self?.handle(reading: reading, connectionState: state, phase: phase)
            }
            .store(in: &cancellables)
    }

    // MARK: - Forwarding logic

    private func handle(reading: ProbeReading?, connectionState: ProbeConnectionState,
                        phase: ProbeCookPhase) {
        let now = Date()

        let connected: Bool
        switch connectionState {
        case .connected: connected = true
        default:         connected = false
        }

        let hasValidReading = reading != nil

        // Detect transitions that warrant an immediate forward
        let connectionChanged  = lastConnected != connected
        let validityChanged    = lastHadValidReading != hasValidReading
        let phaseChanged       = lastPhase != phase
        let immediateForward   = connectionChanged || validityChanged || phaseChanged

        // Apply throttle unless this is a forced send
        let shouldSend = immediateForward
            || shouldForwardProbe(now: now, lastSent: lastSentAt, minInterval: minInterval)

        guard shouldSend else { return }

        // Build the wire dict and attempt to send. The display unit (set by the
        // user in Settings) rides along so the watch renders the same unit as the
        // phone; read at send time so unit changes propagate immediately.
        // Fallback must match Settings' default (Fahrenheit) so the watch
        // agrees with the phone before the preference is ever saved.
        let unit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "temperatureUnit") ?? "F") ?? .fahrenheit
        let dict = probeReadingWireDict(
            connected: connected,
            reading: reading,
            now: now,
            unit: unit,
            targetC: bleManager?.targetCelsius,
            phaseRaw: phase.rawValue,
            overheating: reading?.isOverheating ?? false,
            attachedCookID: bleManager?.attachedCookID?.uuidString
        )
        let sent = WCSessionManager.shared.sendProbeReading(dict)

        if sent {
            lastSentAt = now
        }
        // Always update transition-detection state regardless of send success,
        // so we don't spam retries on every tick when the watch is unreachable.
        lastConnected       = connected
        lastHadValidReading = hasValidReading
        lastPhase           = phase
    }
}

#endif // os(iOS)
