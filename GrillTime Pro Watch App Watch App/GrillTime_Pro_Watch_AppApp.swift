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
