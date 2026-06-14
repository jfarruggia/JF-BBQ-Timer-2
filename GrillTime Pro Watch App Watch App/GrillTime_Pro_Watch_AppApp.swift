//
//  GrillTime_Pro_Watch_AppApp.swift
//  GrillTime Pro Watch App Watch App
//
//  Created by James Farruggia on 8/17/25.
//

import SwiftUI
import WatchConnectivity
import ClockKit

@main
struct GrillTime_Pro_Watch_App_Watch_AppApp: App {
    init() {
        WCSessionManager.shared.activate()
        
        #if DEBUG
        print("WCSession (watchOS) activated")
        #endif
    }
    var body: some Scene {
        WindowGroup {
            TimersListView()
        }
    }
}
