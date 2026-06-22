// ProbeWatchSync.swift
// Grill Time Pro
//
// iOS-side helpers for forwarding probe readings over WatchConnectivity:
// the throttle gate and the wire-dict encoder (which needs `ProbeReading`).
// The shared wire types (`WatchProbeReading`, `decodeWatchProbeReading`) live
// in WCSessionManager.swift, which is compiled into both targets.

import Foundation

// MARK: - Throttle helper (pure)

/// Returns `true` when a probe forward should be sent.
///
/// - Parameters:
///   - now: The current date (injected for testability).
///   - lastSent: The date of the most-recent successful send, or `nil` if never sent.
///   - minInterval: Minimum seconds between sends.
func shouldForwardProbe(now: Date, lastSent: Date?, minInterval: TimeInterval) -> Bool {
    guard let last = lastSent else { return true }
    return now.timeIntervalSince(last) >= minInterval
}

// MARK: - Encoder (iOS only — needs ProbeReading)

#if os(iOS)

/// Builds a plist-safe wire dictionary for sending a probe reading to the watch.
///
/// Temperature keys (`coreC`, `surfaceC`, `ambientC`) are omitted entirely when
/// their resolved value is at or below the −20 °C sensor floor (raw 0 = no data).
///
/// - Parameters:
///   - connected: Whether the iPhone has an active BLE connection to the probe.
///   - reading:   The latest decoded probe reading, or `nil` if disconnected / unavailable.
///   - now:       Current date, used to compute the predicted ready epoch (inject for tests).
/// - Returns: A `[String: Any]` dictionary safe for WatchConnectivity `sendMessage`.
func probeReadingWireDict(connected: Bool, reading: ProbeReading?, now: Date) -> [String: Any] {
    var dict: [String: Any] = [
        "action":     "probe",
        "connected":  connected,
        "batteryLow": reading.map { $0.batteryStatus == .low } ?? false,
        "predStateRaw": Int(reading?.prediction.state.rawValue ?? 0)
    ]

    // Temperature values: omit if at or below the −20 °C sensor floor
    let floorC = -19.99
    if let r = reading {
        if r.coreTempC > floorC    { dict["coreC"]    = r.coreTempC }
        if r.surfaceTempC > floorC { dict["surfaceC"] = r.surfaceTempC }
        if r.ambientTempC > floorC { dict["ambientC"] = r.ambientTempC }
    }

    // Predicted ready date: only include when the probe is actively predicting
    if let r = reading,
       let readyDate = r.prediction.predictedReadyDate(from: now) {
        dict["predReadyEpoch"] = readyDate.timeIntervalSince1970
    }

    return dict
}

#endif // os(iOS)
