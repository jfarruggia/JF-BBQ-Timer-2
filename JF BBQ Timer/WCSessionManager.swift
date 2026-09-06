//
//  WCSessionManager.swift
//  Shared between iOS and watchOS targets
//
//  Minimal WatchConnectivity wrapper with a shared singleton and
//  simple message/applicationContext handling.
//

import Foundation
import WatchConnectivity

// MARK: - Debug logging
/// Lightweight stand-in for `print(...)` that compiles to a no-op in release
/// builds, so diagnostic logging stays available during development without
/// shipping console noise in the App Store build. Defined in this file because
/// it is compiled into both the iOS and watchOS targets.
#if DEBUG
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { "\($0)" }.joined(separator: separator)
    print(message, terminator: terminator)
}
#else
@inline(__always)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif

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
        debugLog("[\(platformTag)] WCSessionManager.activate() called")
        
        guard WCSession.isSupported() else {
            debugLog("[\(platformTag)] ❌ WCSession NOT SUPPORTED on this device")
            return
        }
        
        debugLog("[\(platformTag)] ✅ WCSession is supported, activating...")

        let session = WCSession.default
        session.delegate = self
        session.activate()
        
        // Log current session state immediately after activation request
        debugLog("[\(platformTag)] Session activation requested. Current state: \(session.activationState.rawValue)")
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
            debugLog("[\(platformTag)] ❌ sendTimersSnapshot: WCSession not supported")
            return false
        }
        
        let session = WCSession.default
        guard session.activationState == .activated else {
            debugLog("[\(platformTag)] ❌ sendTimersSnapshot: Session NOT activated (state: \(session.activationState.rawValue))")
            return false
        }
        
        // Log session details for debugging
        debugLog("[\(platformTag)] 📤 sendTimersSnapshot: \(timerCount) timers, reachable=\(session.isReachable)")

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
                    debugLog("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
                }
            }
            
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                debugLog("[\(self?.platformTag ?? "?")] ❌ sendMessage(snapshot) ERROR: \(error.localizedDescription)")
            }
            debugLog("[\(platformTag)] ✅ sendMessage(snapshot) sent via direct message")
            return true
        }

        // Fallback: application context (delivers latest state when possible)
        do {
            try session.updateApplicationContext(snapshot)
            debugLog("[\(platformTag)] ✅ updateApplicationContext sent (\(timerCount) timers)")
            return true
        } catch {
            debugLog("[\(platformTag)] ❌ Failed to update application context: \(error.localizedDescription)")
            return false
        }
    }

    /// Sends a compact probe reading dict to the watch via sendMessage.
    /// Probe data is ephemeral — if the watch is not currently reachable the
    /// send is skipped (no context/userInfo fallback) to avoid stale readings.
    /// - Parameter dict: Wire dict produced by `probeReadingWireDict`.
    /// - Returns: true if sendMessage was called; false if skipped (not reachable/activated).
    @discardableResult
    func sendProbeReading(_ dict: [String: Any]) -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated else { return false }

        // Latest-wins mirror through the application context: sendMessage below
        // is live-only (skipped whenever the watch isn't reachable), so without
        // this a suspended watch keeps showing the last reading it happened to
        // catch — Jim's frozen-temp cook, 2026-08-24. Context is delivered when
        // the watch wakes; repeated updates replace each other, never queue.
        do {
            try session.updateApplicationContext(dict)
        } catch {
            debugLog("[\(platformTag)] ⚠️ sendProbeReading: context mirror failed: \(error.localizedDescription)")
        }

        guard session.isReachable else {
            debugLog("[\(platformTag)] ⏭️ sendProbeReading: watch not reachable — context mirror only")
            return false
        }
        session.sendMessage(dict, replyHandler: nil) { [weak self] error in
            debugLog("[\(self?.platformTag ?? "?")] ❌ sendProbeReading ERROR: \(error.localizedDescription)")
        }
        debugLog("[\(platformTag)] 📡 sendProbeReading sent (connected=\(dict["connected"] as? Bool ?? false))")
        return true
    }

    /// Sends a probe cook-moment alert (pull now / target reached / resting
    /// done) to the watch.
    ///
    /// Unlike `sendProbeReading`, an alert must never be dropped, so this uses
    /// `transferUserInfo`: the payload is queued by the system and delivered
    /// when the watch next wakes, even if it is unreachable right now.
    /// - Parameter dict: Wire dict produced by `probeEventWireDict`.
    /// - Returns: true if the transfer was queued.
    @discardableResult
    func sendProbeEvent(_ dict: [String: Any]) -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated else {
            debugLog("[\(platformTag)] ⏭️ sendProbeEvent: session not activated")
            return false
        }
        session.transferUserInfo(dict)
        debugLog("[\(platformTag)] 📤 sendProbeEvent queued: \(dict["event"] as? String ?? "?")")
        return true
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
            debugLog("[\(platformTag)] ❌ sendCommand(\(action)): WCSession not supported")
            return
        }
        
        let session = WCSession.default
        debugLog("[\(platformTag)] 📤 sendCommand: action=\(action), timerId=\(timerId), reachable=\(session.isReachable), activated=\(session.activationState == .activated)")

        if session.isReachable {
            session.sendMessage(command, replyHandler: { [weak self] response in
                debugLog("[\(self?.platformTag ?? "?")] ✅ sendCommand(\(action)) got reply: \(response)")
                reply?(response)
            }, errorHandler: { [weak self] error in
                debugLog("[\(self?.platformTag ?? "?")] ❌ sendCommand(\(action)) ERROR: \(error.localizedDescription)")
            })
        } else {
            // Not reachable; queue the command to be delivered opportunistically
            _ = session.transferUserInfo(command)
            debugLog("[\(platformTag)] ⏳ sendCommand(\(action)) queued via transferUserInfo (not reachable)")
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
            debugLog("[\(platformTag)] ❌ Session activation FAILED: \(stateDescription), error: \(error.localizedDescription)")
        } else {
            debugLog("[\(platformTag)] ✅ Session activation completed: \(stateDescription)")
            debugLog("[\(platformTag)]   isReachable: \(session.isReachable)")
            #if os(iOS)
            debugLog("[\(platformTag)]   isPaired: \(session.isPaired)")
            debugLog("[\(platformTag)]   isWatchAppInstalled: \(session.isWatchAppInstalled)")
            #endif
        }
    }

    #if os(iOS)
    /// iOS-only: session became inactive (e.g., switching watches)
    func sessionDidBecomeInactive(_ session: WCSession) {
        debugLog("[\(platformTag)] ⚠️ Session became INACTIVE")
    }

    /// iOS-only: session deactivated; call activate() again if needed
    func sessionDidDeactivate(_ session: WCSession) {
        debugLog("[\(platformTag)] ⚠️ Session DEACTIVATED - re-activating...")
        WCSession.default.activate()
    }
    #endif

    /// Reachability changed (both platforms)
    func sessionReachabilityDidChange(_ session: WCSession) {
        let emoji = session.isReachable ? "🟢" : "🔴"
        debugLog("[\(platformTag)] \(emoji) Reachability changed: \(session.isReachable ? "REACHABLE" : "NOT REACHABLE")")
    }

    /// Received updated application context. Probe readings arrive here as the
    /// latest-wins mirror (see sendProbeReading); anything else keeps the
    /// legacy treatment as a timers snapshot.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if applicationContext["action"] as? String == "probe" {
            debugLog("[\(platformTag)] 📥 didReceiveApplicationContext: probe reading (context mirror)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("receivedProbeReading"),
                    object: nil,
                    userInfo: applicationContext
                )
            }
            return
        }
        let timerCount = (applicationContext["timers"] as? [[String: Any]])?.count ?? 0
        debugLog("[\(platformTag)] 📥 didReceiveApplicationContext: \(timerCount) timers")
        
        // Log each timer for debugging
        if let timers = applicationContext["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                debugLog("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            debugLog("[\(self.platformTag)] 📣 Posting receivedTimersSnapshot notification")
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
        debugLog("[\(platformTag)] 📥 didReceiveUserInfo: action=\(action)")
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else if action == "probe" {
                name = "receivedProbeReading"
            } else if action == "probeEvent" {
                name = "receivedProbeEvent"
            } else {
                name = "receivedCommand"
            }
            debugLog("[\(self.platformTag)] 📣 Posting \(name) notification")
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
        debugLog("[\(platformTag)] 📥 didReceiveMessage (no reply): action=\(action), timers=\(timerCount)")
        
        // If it's a snapshot, log the timer details
        if action == "snapshot", let timers = message["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                debugLog("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else if action == "probe" {
                name = "receivedProbeReading"
            } else if action == "probeEvent" {
                name = "receivedProbeEvent"
            } else {
                name = "receivedCommand"
            }
            debugLog("[\(self.platformTag)] 📣 Posting \(name) notification")
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
        debugLog("[\(platformTag)] 📥 didReceiveMessage (with reply): action=\(action), timers=\(timerCount)")
        
        // If it's a snapshot, log the timer details
        if action == "snapshot", let timers = message["timers"] as? [[String: Any]] {
            for (index, timer) in timers.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                debugLog("[\(platformTag)]   Timer \(index+1): \(name) - \(state) - \(remaining)s remaining")
            }
        }
        
        DispatchQueue.main.async {
            let name: String
            if action == "alert" {
                name = "receivedAlert"
            } else if action == "snapshot" {
                name = "receivedTimersSnapshot"
            } else if action == "probe" {
                name = "receivedProbeReading"
            } else if action == "probeEvent" {
                name = "receivedProbeEvent"
            } else {
                name = "receivedCommand"
            }
            debugLog("[\(self.platformTag)] 📣 Posting \(name) notification")
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

// MARK: - Probe wire types (shared across iOS + watchOS)
//
// Defined here because this file is compiled into BOTH targets, giving a single
// source of truth for the probe-reading wire format. The iOS-only encoder
// (`probeReadingWireDict`, which needs `ProbeReading`) lives in ProbeWatchSync.swift.

/// User-selectable temperature unit. Defined here so both the iOS app and the
/// watch app (which renders forwarded probe temps) share one implementation.
/// Probe data is always stored and transmitted in °C; conversion to the user's
/// unit happens only at display time. The raw value ("C"/"F") doubles as the
/// wire value carried in the probe payload.
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "C"
    case fahrenheit = "F"

    var id: String { rawValue }

    /// Degree symbol with unit letter, e.g. "°C" / "°F".
    var symbol: String { self == .celsius ? "°C" : "°F" }

    /// Human-readable label for the settings picker.
    var displayName: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }

    /// Convert a canonical Celsius value into this unit.
    func value(fromCelsius c: Double) -> Double {
        switch self {
        case .celsius:    return c
        case .fahrenheit: return c * 9.0 / 5.0 + 32.0
        }
    }

    /// Convert a value the user typed in this unit back to canonical Celsius —
    /// the inverse of `value(fromCelsius:)`. Used by target-temperature entry.
    func celsius(fromValue v: Double) -> Double {
        switch self {
        case .celsius:    return v
        case .fahrenheit: return (v - 32.0) * 5.0 / 9.0
        }
    }

    /// Rounded whole-degree string with a bare degree sign, e.g. "162°".
    /// Matches the compact timer card and the watch.
    func compactString(fromCelsius c: Double) -> String {
        "\(Int(value(fromCelsius: c).rounded()))°"
    }

    /// One-decimal string with the unit symbol, e.g. "72.0 °C".
    /// Matches the probe picker's detailed live reading.
    func preciseString(fromCelsius c: Double) -> String {
        String(format: "%.1f %@", value(fromCelsius: c), symbol)
    }
}

/// What stage of the guided cook the attached probe is in. Defined here (not
/// in ProbeCookPhase.swift) because it is part of the phone→watch wire format
/// and this file is compiled into both targets.
/// Raw values are wire-stable — never renumber.
enum ProbeCookPhase: UInt8, Equatable {
    /// No prediction configured (mode none) — plain temperature display.
    case none = 0
    /// Prediction configured but not yet producing a countdown
    /// (probe not inserted / inserted / warming).
    case monitoring = 1
    /// Counting down to the moment the food should come off the heat.
    case predictingRemoval = 2
    /// The probe says pull the food off now.
    case pullNow = 3
    /// Food is resting; carryover is coasting the core up to the target.
    case resting = 4
    /// The cook is finished (resting complete or target reached).
    case done = 5
}

/// Compact, plist-safe representation of a probe reading forwarded iPhone → watch.
struct WatchProbeReading: Equatable {
    /// True when the iPhone has an active BLE connection to the probe.
    var connected: Bool
    /// Core virtual-sensor temperature in °C; nil when no valid reading.
    var coreC: Double?
    /// Surface virtual-sensor temperature in °C; nil when no valid reading.
    var surfaceC: Double?
    /// Ambient virtual-sensor temperature in °C; nil when no valid reading.
    var ambientC: Double?
    /// Raw value of the probe's `PredictionState` enum.
    var predictionStateRaw: UInt8
    /// Absolute date the probe predicts the food will be ready; nil unless predicting.
    var predictedReadyDate: Date?
    /// True when the probe reports its battery is low.
    var batteryLow: Bool
    /// The unit the watch should render temperatures in (mirrors the iPhone's
    /// setting). Defaults to Celsius for older payloads that omit the field.
    var unit: TemperatureUnit = .celsius
    /// The attached cook's target temperature (°C); nil when unset.
    var targetC: Double? = nil
    /// Raw `ProbeCookPhase` — the guided-cook stage. Defaults to none (0)
    /// for older payloads that omit the field.
    var phaseRaw: UInt8 = 0
    /// True when a probe sensor reports overheating.
    var overheating: Bool = false
    /// UUID string of the cook (timer) the probe is attached to; nil when
    /// unattached. Lets the watch show the temp only on that timer's page.
    var attachedCookID: String? = nil
}

/// Decodes a WatchConnectivity wire dict into a `WatchProbeReading`.
/// Returns nil if `dict["action"]` is not `"probe"`. Missing temperature keys
/// decode to nil (meaning "no valid reading" for that sensor).
func decodeWatchProbeReading(from dict: [String: Any]) -> WatchProbeReading? {
    guard dict["action"] as? String == "probe" else { return nil }

    let connected    = dict["connected"] as? Bool ?? false
    let batteryLow   = dict["batteryLow"] as? Bool ?? false
    let predStateRaw = UInt8((dict["predStateRaw"] as? Int) ?? 0)

    let coreC:    Double? = dict["coreC"]    as? Double
    let surfaceC: Double? = dict["surfaceC"] as? Double
    let ambientC: Double? = dict["ambientC"] as? Double

    let predictedReadyDate: Date? = (dict["predReadyEpoch"] as? Double)
        .map { Date(timeIntervalSince1970: $0) }

    let unit = TemperatureUnit(rawValue: (dict["unit"] as? String) ?? "C") ?? .celsius

    return WatchProbeReading(
        connected: connected,
        coreC: coreC,
        surfaceC: surfaceC,
        ambientC: ambientC,
        predictionStateRaw: predStateRaw,
        predictedReadyDate: predictedReadyDate,
        batteryLow: batteryLow,
        unit: unit,
        targetC: dict["targetC"] as? Double,
        phaseRaw: UInt8((dict["phaseRaw"] as? Int) ?? 0),
        overheating: dict["overheating"] as? Bool ?? false,
        attachedCookID: dict["cookID"] as? String
    )
}

// MARK: - Probe cook-moment alerts (iPhone → watch)

/// The probe cook moments that are worth interrupting the user for. Raw values
/// are the wire strings, so older/newer builds degrade to "unknown event"
/// rather than crashing.
///
/// Lives in this shared file (with the other wire types) because the watch
/// target only compiles selected files — see CLAUDE.md.
enum WatchProbeAlertKind: String, CaseIterable, Equatable {
    case pullNow
    case targetReached
    case restingDone
}

/// Compact, plist-safe probe alert forwarded iPhone → watch.
struct WatchProbeEvent: Equatable {
    /// Which cook moment fired.
    var kind: WatchProbeAlertKind
    /// Headline for the moment, e.g. "Target temperature reached".
    var title: String
    /// Formatted core temperature at fire time (already in the user's unit),
    /// e.g. "135°F"; nil when no usable reading.
    var tempText: String?
    /// Name of the cook the probe is attached to; nil when unknown.
    var cookName: String?
    /// True when the iPhone app was frontmost as the alert fired.
    ///
    /// iOS only mirrors a phone notification to the watch while the phone is
    /// locked. So this flag tells the watch whether a mirrored banner is
    /// coming: when the phone was frontmost (no mirror), the watch posts its
    /// own local notification; otherwise it stays quiet and lets the mirror do
    /// the work. That keeps the user from being alerted twice.
    var phoneForeground: Bool
}

/// Builds the WatchConnectivity wire dict for a probe cook moment.
func probeEventWireDict(kind: WatchProbeAlertKind,
                        title: String,
                        tempText: String?,
                        cookName: String?,
                        phoneForeground: Bool) -> [String: Any] {
    var dict: [String: Any] = [
        "action": "probeEvent",
        "event": kind.rawValue,
        "title": title,
        "phoneForeground": phoneForeground
    ]
    if let tempText { dict["tempText"] = tempText }
    if let cookName { dict["cookName"] = cookName }
    return dict
}

/// Decodes a WatchConnectivity wire dict into a `WatchProbeEvent`.
/// Returns nil unless `action` is `"probeEvent"` and `event` is a kind this
/// build knows about.
func decodeWatchProbeEvent(from dict: [String: Any]) -> WatchProbeEvent? {
    guard dict["action"] as? String == "probeEvent",
          let raw = dict["event"] as? String,
          let kind = WatchProbeAlertKind(rawValue: raw) else { return nil }
    return WatchProbeEvent(
        kind: kind,
        title: (dict["title"] as? String) ?? "Probe alert",
        tempText: dict["tempText"] as? String,
        cookName: dict["cookName"] as? String,
        phoneForeground: dict["phoneForeground"] as? Bool ?? false
    )
}

// MARK: - Extended runtime restart policy (watch)

/// Decides whether the watch should immediately open a new extended runtime
/// session after the old one ended.
///
/// watchOS caps a session at roughly an hour and then invalidates it as
/// `.expired`. Without a restart the watch app goes quiet partway through a
/// long cook (brisket, pork butt) — the countdown freezes on the wrist.
///
/// Pure so the iOS test target can cover it: the caller maps the watchOS-only
/// `WKExtendedRuntimeSessionInvalidationReason` down to `expired`.
enum ExtendedRuntimeRestartPolicy {
    /// A real session lives for tens of minutes. Anything that dies faster than
    /// this is failing, not expiring, so restarting it would spin a hot loop
    /// that drains the battery. One minute is far below a genuine expiry and
    /// far above any plausible failure loop.
    static let minimumHealthyLifetime: TimeInterval = 60

    /// - Parameters:
    ///   - expired: true only when watchOS ended the session because it hit the
    ///     time cap. Every other reason (user left the app, system suppression,
    ///     an error) must not auto-restart.
    ///   - timerRunning: whether a cook timer is still counting down. No timer,
    ///     nothing to keep alive.
    ///   - sessionLifetime: how long the session that just ended actually ran.
    static func shouldRestart(expired: Bool,
                              timerRunning: Bool,
                              sessionLifetime: TimeInterval) -> Bool {
        guard expired, timerRunning else { return false }
        return sessionLifetime >= minimumHealthyLifetime
    }
}

// MARK: - Watch countdown-ring math

/// Pure fill math for the watch's countdown ring (watch-ring-layout-spec.md).
/// Lives in this shared file so the watch target compiles it and the iOS test
/// target can unit-test it. Mirrors `TimerState.progress(at:)` semantics: 1 =
/// full time remaining, 0 = done; measured against the run's total duration so
/// pause/resume doesn't refill the ring.
enum WatchRingMath {
    /// Fraction of the run remaining, clamped to [0, 1]. Returns 0 when
    /// `runDuration` is not positive (no sensible ring to draw).
    static func progress(remaining: Double, runDuration: Double) -> Double {
        guard runDuration > 0 else { return 0 }
        return min(1, max(0, remaining / runDuration))
    }
}


