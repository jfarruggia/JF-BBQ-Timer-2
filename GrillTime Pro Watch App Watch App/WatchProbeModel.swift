// WatchProbeModel.swift
// GrillTime Pro Watch App
//
// Observable model that receives forwarded probe readings on the watch.
// The wire types (`WatchProbeReading`, `decodeWatchProbeReading`) are defined
// once in WCSessionManager.swift, which compiles into both targets.

import Foundation

// MARK: - WatchProbeModel

/// Receives "receivedProbeReading" NotificationCenter posts (dispatched on main
/// by WCSessionManager) and publishes the decoded WatchProbeReading to SwiftUI.
final class WatchProbeModel: ObservableObject {

    /// The most-recent decoded probe reading from the iPhone.
    /// nil = no data yet received this session.
    @Published var probe: WatchProbeReading? = nil

    init() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("receivedProbeReading"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let dict = note.userInfo as? [String: Any] else {
                debugLog("[⌚️Watch] ⚠️ receivedProbeReading: missing userInfo")
                return
            }
            guard let reading = decodeWatchProbeReading(from: dict) else {
                debugLog("[⌚️Watch] ⚠️ receivedProbeReading: decode failed")
                return
            }
            debugLog("[⌚️Watch] 🌡️ receivedProbeReading: connected=\(reading.connected) core=\(reading.coreC.map { String(format: "%.1f°C", $0) } ?? "—")")
            self?.probe = reading
        }
    }
}
