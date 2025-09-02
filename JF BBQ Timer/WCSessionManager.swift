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

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Sets the delegate and activates the default WCSession when supported.
    func activate() {
        guard WCSession.isSupported() else {
            #if DEBUG
            print("[WCSessionManager] WCSession not supported on this device.")
            #endif
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends a full timers snapshot to the counterpart using application context.
    /// - Parameter snapshot: A dictionary representing the current timers state.
    ///                       Use only property list compatible values.
    func sendTimersSnapshot(_ snapshot: [String: Any]) {
        guard WCSession.isSupported() else { return }
        do {
            try WCSession.default.updateApplicationContext(snapshot)
            #if DEBUG
            print("[WCSessionManager] updateApplicationContext sent: \(snapshot.keys)")
            #endif
        } catch {
            #if DEBUG
            print("[WCSessionManager] Failed to update application context: \(error)")
            #endif
        }
    }

    /// Sends a command to the counterpart. If the session is reachable, uses sendMessage
    /// with an optional reply handler; otherwise falls back to transferUserInfo.
    /// - Parameters:
    ///   - command: Dictionary describing the command. Use property list compatible values.
    ///   - reply: Optional closure invoked only when a direct reply is received via sendMessage.
    func sendCommand(_ command: [String: Any], reply: (([String: Any]) -> Void)? = nil) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(command, replyHandler: { response in
                #if DEBUG
                print("[WCSessionManager] Received reply: \(response)")
                #endif
                reply?(response)
            }, errorHandler: { error in
                #if DEBUG
                print("[WCSessionManager] sendMessage error: \(error)")
                #endif
            })
        } else {
            // Not reachable; queue the command to be delivered opportunistically
            _ = session.transferUserInfo(command)
            #if DEBUG
            print("[WCSessionManager] Queued command via transferUserInfo: \(command.keys)")
            #endif
        }
    }

    // MARK: - WCSessionDelegate

    /// Called when activation completes on both iOS and watchOS.
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        #if DEBUG
        print("[WCSessionManager] activationDidCompleteWith state=\(activationState.rawValue), error=\(String(describing: error))")
        #endif
    }

    #if os(iOS)
    /// iOS-only: session became inactive (e.g., switching watches)
    func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("[WCSessionManager] sessionDidBecomeInactive")
        #endif
    }

    /// iOS-only: session deactivated; call activate() again if needed
    func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        print("[WCSessionManager] sessionDidDeactivate; re-activating")
        #endif
        WCSession.default.activate()
    }
    #endif

    /// Reachability changed (both platforms)
    func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("[WCSessionManager] reachabilityDidChange: reachable=\(session.isReachable)")
        #endif
    }

    /// Received updated application context (treat as a timers snapshot)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("receivedTimersSnapshot"),
                object: nil,
                userInfo: applicationContext
            )
        }
    }

    /// Received user info (treat as a command)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            let action = userInfo["action"] as? String
            let name = (action == "alert") ? "receivedAlert" : "receivedCommand"
            NotificationCenter.default.post(
                name: Notification.Name(name),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    /// Received a message without a reply handler (treat as a command)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            let action = message["action"] as? String
            let name = (action == "alert") ? "receivedAlert" : "receivedCommand"
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
        DispatchQueue.main.async {
            let action = message["action"] as? String
            let name = (action == "alert") ? "receivedAlert" : "receivedCommand"
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


