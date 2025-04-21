//
//  JF_BBQ_TimerApp.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import UIKit

// This class will handle the orientation lock
class OrientationLock: ObservableObject {
    init() {
        // Lock the orientation to portrait on launch
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        AppDelegate.orientationLock = .portrait
    }
}

// Add a class to handle app delegate functionality
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct JF_BBQ_TimerApp: App {
    // Add the app delegate and orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var orientationLock = OrientationLock()
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
    }
}
