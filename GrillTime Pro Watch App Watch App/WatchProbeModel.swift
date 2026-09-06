// WatchProbeModel.swift
// GrillTime Pro Watch App
//
// Observable model that receives forwarded probe readings on the watch.
// The wire types (`WatchProbeReading`, `decodeWatchProbeReading`) are defined
// once in WCSessionManager.swift, which compiles into both targets.

import Foundation
import WatchKit
import UserNotifications

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

// MARK: - WatchProbeAlertModel

/// Receives "receivedProbeEvent" posts — the probe's act-now cook moments
/// forwarded from the iPhone — and publishes the current one for the UI.
///
/// The phone tells us whether it was frontmost when the moment fired. iOS only
/// relays a phone notification to the wrist while the phone is locked, so:
///   * phone frontmost  → no relay is coming, we post our own notification
///     when the watch app is not on screen;
///   * phone backgrounded → the relayed banner already alerts the wrist, so we
///     stay quiet and only show the card if the app happens to be open.
/// That way the user is never alerted twice for one moment.
final class WatchProbeAlertModel: ObservableObject {

    /// The cook moment currently being shown, or nil when nothing is up.
    @Published var alert: WatchProbeEvent? = nil

    init() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("receivedProbeEvent"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let dict = note.userInfo as? [String: Any] else {
                debugLog("[⌚️Watch] ⚠️ receivedProbeEvent: missing userInfo")
                return
            }
            if isProbeEventClear(dict) {
                debugLog("[⌚️Watch] 🔕 receivedProbeEvent: cleared from the phone")
                self?.alert = nil
                return
            }
            guard let event = decodeWatchProbeEvent(from: dict) else {
                debugLog("[⌚️Watch] ⚠️ receivedProbeEvent: decode failed")
                return
            }
            debugLog("[⌚️Watch] 🔔 receivedProbeEvent: \(event.kind.rawValue) phoneForeground=\(event.phoneForeground)")
            self?.present(event)
        }
    }

    private func present(_ event: WatchProbeEvent) {
        let onScreen = WKApplication.shared().applicationState == .active
        if onScreen {
            alert = event
        } else if event.phoneForeground {
            postLocalNotification(for: event)
        } else {
            debugLog("[⌚️Watch] ⏭️ probe event: watch asleep and phone relay expected — no watch notification")
        }
    }

    /// Immediate local notification, used only when nothing else will alert the
    /// wrist (watch app not on screen AND no phone relay coming).
    private func postLocalNotification(for event: WatchProbeEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = [event.cookName, event.tempText]
            .compactMap { $0 }
            .joined(separator: " · ")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "watch-probe-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { debugLog("[⌚️Watch] ❌ probe notification failed: \(error)") }
        }
    }
}
