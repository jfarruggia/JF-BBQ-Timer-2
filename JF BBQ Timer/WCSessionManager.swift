//
//  WCSessionManager.swift
//  Shared between iOS and watchOS targets
//
//  Minimal WatchConnectivity wrapper with a shared singleton and
//  simple message/applicationContext handling.
//

import Foundation
import WatchConnectivity

/// A lightweight, SwiftUI-friendly manager for WatchConnectivity.
/// This builds on both iOS and watchOS. Avoid UIKit imports here.
final class WCSessionManager: NSObject, WCSessionDelegate {
    /// Shared singleton used across the app and watch app
    static let shared = WCSessionManager()
    
    // MARK: - Diagnostic helper to identify platform in logs
    // This helps us see which device (iOS or watchOS) is logging
    private var platformTag: String {
        #if os(iOS)
        return "📱iOS"
        #elseif os(watchOS)
        return "⌚️Watch"
        #else
        return "❓Unknown"
        #endif
    }

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Sets the delegate and activates the default WCSession when supported.
    func activate() {
        // Log activation attempt with platform identifier
        print("[\(platformTag)] WCSessionManager.activate() called")
        
        guard WCSession.isSupported() else {
            print("[\(platformTag)] ❌ WCSession NOT SUPPORTED on this device")
            return
        }
        
        print("[\(platformTag)] ✅ WCSession is supported, activating...")

        let session = WCSession.default
        session.delegate = self
        session.activate()
        
        // Log current session state immediately after activation request
        print("[\(platformTag)] Session activation requested. Current state: \(session.activationState.rawValue)")
    }

    /// Sends a full timers snapshot to the counterpart. If reachable, uses sendMessage
    /// for immediate delivery; otherwise falls back to updateApplicationContext.
    /// - Parameter snapshot: Property-list safe dictionary describing timers state
    /// - Returns: true if a send was attempted successfully
    @discardableResult
    func sendTimersSnapshot(_ snapshot: [String: Any]) -> Bool {
        // Extract timer count for logging
        let timerCount = (snapshot["timers"] as? [[String: Any]])?.count ?? 0
        
        guard WCSession.isSupported() else {
            print("[\(platformTag)] ❌ sendTimersSnapshot: WCSession not supported")
            return false
        }
        
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[\(platformTag)] ❌ sendTimersSnapshot: Session NOT activated (state: \(session.activationState.rawValue))")
            return false
        }
        
        // Log session details for debugging
        print("[\(platformTag)] 📤 sendTimersSnapshot: \(timerCount) timers, reachable=\(session.isReachable)")

        // Prefer immediate delivery while reachable
        if session.isReachable {
            var payload = snapshot
            payload["action"] = "snapshot"
            
            // Log the actual timer data being sent
            if let timers = snapshot["timers"] as? [[String: Any]] {
                for (index, timer) in timers.enumerated() {
                    let name = timer["name"] as? String ?? "?"
                    let state = timer["state"] as? String ?? "?"
                    let remaining = timer["remaining"] as? Int ?? 0
                    print("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
                }
            }
            
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                print("[\(self?.platformTag ?? "?")] ❌ sendMessage(snapshot) ERROR: \(error.localizedDescription)")
            }
            print("[\(platformTag)] ✅ sendMessage(snapshot) sent via direct message")
            return true
        }

        // Fallback: application context (delivers latest state when possible)
        do {
            try session.updateApplicationContext(snapshot)
            print("[\(platformTag)] ✅ updateApplicationContext sent (\(timerCount) timers)")
            return true
        } catch {
            print("[\(platformTag)] ❌ Failed to update application context: \(error.localizedDescription)")
            return false
        }
    }

    /// Sends a command to the counterpart. If the session is reachable, uses sendMessage
    /// with an optional reply handler; otherwise falls back to transferUserInfo.
    /// - Parameters:
    ///   - command: Dictionary describing the command. Use property list compatible values.
    ///   - reply: Optional closure invoked only when a direct reply is received via sendMessage.
    func sendCommand(_ command: [String: Any], reply: (([String: Any]) -> Void)? = nil) {
        let action = command["action"] as? String ?? "unknown"
        let timerId = command["timerId"] as? String ?? "none"
        
        guard WCSession.isSupported() else {
            print("[\(platformTag)] ❌ sendCommand(\(action)): WCSession not supported")
            return
        }
        
        let session = WCSession.default
        print("[\(platformTag)] 📤 sendCommand: action=\(action), timerId=\(timerId), reachable=\(session.isReachable), activated=\(session.activationState == .activated)")

        if session.isReachable {
            session.sendMessage(command, replyHandler: { [weak self] response in
                print("[\(self?.platformTag ?? "?")] ✅ sendCommand(\(action)) got reply: \(response)")
                reply?(response)
            }, errorHandler: { [weak self] error in
                print("[\(self?.platformTag ?? "?")] ❌ sendCommand(\(action)) ERROR: \(error.localizedDescription)")
            })
        } else {
            // Not reachable; queue the command to be delivered opportunistically
            _ = session.transferUserInfo(command)
            print("[\(platformTag)] ⏳ sendCommand(\(action)) queued via transferUserInfo (not reachable)")
        }
    }

    // MARK: - WCSessionDelegate

    /// Called when activation completes on both iOS and watchOS.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // Describe the activation state in human-readable form
        let stateDescription: String
        switch activationState {
        case .notActivated: stateDescription = "notActivated"
        case .inactive: stateDescription = "inactive"
        case .activated: stateDescription = "activated ✅"
        @unknown default: stateDescription = "unknown(\(activationState.rawValue))"
        }
        
        if let error = error {
            print("[\(platformTag)] ❌ Session activation FAILED: \(stateDescription), error: \(error.localizedDescription)")
        } else {
            print("[\(platformTag)] ✅ Session activation completed: \(stateDescription)")
            print("[\(platformTag)]   isReachable: \(session.isReachable)")
            #if os(iOS)
            print("[\(platformTag)]   isPaired: \(session.isPaired)")
            print("[\(platformTag)]   isWatchAppInstalled: \(session.isWatchAppInstalled)")
            #endif
        }
    }

    #if os(iOS)
    /// iOS-only: session became inactive (e.g., switching watches)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("[\(platformTag)] ⚠️ Session became INACTIVE")
    }

    /// iOS-only: session deactivated; call activate() again if needed
    func sessionDidDeactivate(_ session: WCSession) {
        print("[\(platformTag)] ⚠️ Session DEACTIVATED - re-activating...")
        WCSession.default.activate()
    }
    #endif

    /// Reachability changed (both platforms)
    func sessionReachabilityDidChange(_ session: WCSession) {
        let emoji = session.isReachable ? "🟢" : "🔴"
        print("[\(platformTag)] \(emoji) Reachability changed: \(session.isReachable ? "REACHABLE" : "NOT REACHABLE")")
    }

    /// Received updated application context (treat as a timers snapshot)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let timerCount = (applicationContext["timers"] as? [[String: Any]])?.count ?? 0
        print("[\(platformTag)] 📥 didReceiveApplicationContext: \(timerCount) timers")
        
        // Log each timer for debugging
        if let timers = applicationContext["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                print("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            print("[\(self.platformTag)] 📣 Posting receivedTimersSnapshot notification")
            NotificationCenter.default.post(
                name: Notification.Name("receivedTimersSnapshot"),
                object: nil,
                userInfo: applicationContext
            )
        }
    }

    /// Received user info (treat as a command)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let action = userInfo["action"] as? String ?? "unknown"
        print("[\(platformTag)] 📥 didReceiveUserInfo: action=\(action)")
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else {
                name = "receivedCommand"
            }
            print("[\(self.platformTag)] 📣 Posting \(name) notification")
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    /// Received a message without a reply handler (treat as a command or snapshot)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let action = message["action"] as? String ?? "unknown"
        let timerCount = (message["timers"] as? [[String: Any]])?.count ?? 0
        print("[\(platformTag)] 📥 didReceiveMessage (no reply): action=\(action), timers=\(timerCount)")
        
        // If it's a snapshot, log the timer details
        if action == "snapshot", let timers = message["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                print("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else {
                name = "receivedCommand"
            }
            print("[\(self.platformTag)] 📣 Posting \(name) notification")
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: nil,
                userInfo: message
            )
        }
    }

    /// Received a message with a reply handler; post notification and optionally ack.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        let action = message["action"] as? String ?? "unknown"
        let timerCount = (message["timers"] as? [[String: Any]])?.count ?? 0
        print("[\(platformTag)] 📥 didReceiveMessage (with reply): action=\(action), timers=\(timerCount)")
        
        // If it's a snapshot, log the timer details
        if action == "snapshot", let timers = message["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                print("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else {
                name = "receivedCommand"
            }
            print("[\(self.platformTag)] 📣 Posting \(name) notification")
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: nil,
                userInfo: message
            )
        }
        // Minimal acknowledgement to keep the channel healthy
        replyHandler([:])
    }
}


