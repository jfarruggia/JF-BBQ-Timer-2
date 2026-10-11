//
//  GrillTime_Pro_Watch_AppApp.swift
//  GrillTime Pro Watch App Watch App
//
//  Created by James Farruggia on 8/17/25.
//

import SwiftUI
import WatchConnectivity
import ClockKit
import UserNotifications

@main
struct GrillTime_Pro_Watch_App_Watch_AppApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = WatchNotificationDelegate.shared
        WCSessionManager.shared.activate()

        // The watch posts its own local notification for a probe cook moment
        // when nothing else will alert the wrist (see WatchProbeAlertModel), so
        // it needs its own authorization — the iPhone's does not cover it.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            #if DEBUG
            debugLog("[⌚️Watch] 🔔 notification authorization granted=\(granted) error=\(error?.localizedDescription ?? "none")")
            #endif
        }
        
        #if DEBUG
        debugLog("WCSession (watchOS) activated")
        #endif
    }
    var body: some Scene {
        WindowGroup {
            TimersListView()
        }
    }
}

/// Foreground notification handling. When the watch app is frontmost, watchOS
/// hands the phone's mirrored notification here; without a delegate it is
/// hidden. For a timer (or preheat) notification we raise the full-screen alert
/// through the model's fire-once latch and let only the sound play. Anything
/// else (probe alerts have their own banner) stays hidden, as before.
final class WatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WatchNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        guard identifier.hasPrefix("timer-") || identifier.hasPrefix("preheat-") else { return [] }
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name("watchMirroredNotificationWillPresent"),
                                            object: nil, userInfo: ["identifier": identifier])
        }
        return [.sound]
    }
}
