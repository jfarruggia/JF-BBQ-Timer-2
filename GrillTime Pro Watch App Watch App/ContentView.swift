//
//  ContentView.swift
//  GrillTime Pro Watch App Watch App
//
//  Created by James Farruggia on 8/17/25.
//

import SwiftUI
import WatchConnectivity
import WatchKit

struct TimersListView: View {
    @StateObject private var model = WatchTimersModel()
    // Local ticker so the watch UI updates every second without waiting for iPhone
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // Tracks which timer page is currently visible so we can show its name in the top bar
    @State private var selectedTimerId: String? = nil
    // Request guard so we only ask iPhone for a snapshot once on launch
    @State private var hasRequestedInitialSnapshot: Bool = false
    // Keeps the app executing when it leaves the foreground, similar to Apple's Timer app
    // so countdowns remain accurate and alerts can still be coordinated.
    private let runtime = ExtendedRuntimeController()

    var body: some View {
        // NavigationStack provides the top system bar on watchOS
        NavigationStack {
            mainContent
                // Clear any default title to avoid duplication with the toolbar item
                .navigationTitle("")
                // Put the timer name in the top-left, aligned with the system clock on the right
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if let name = selectedTimerName {
                            Text(name)
                                // Match the system clock size for visual alignment; nudge higher
                                .font(.footnote)
                                .baselineOffset(-3)
                        }
                    }
                }
        }
        // Drive the local clock
        .onReceive(ticker) { date in
            now = date
        }
        // Initialize the selection to the first timer when available
        .onAppear {
            if selectedTimerId == nil {
                selectedTimerId = model.timers.first?.id
            }
            // If we launch to an empty list, proactively ask iPhone for a snapshot
            if !hasRequestedInitialSnapshot && model.timers.isEmpty {
                hasRequestedInitialSnapshot = true
                WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
            }
            // Ensure extended runtime is active if any timers are already running
            refreshExtendedRuntimeSession()
        }
        // Keep the selection valid when the timers list changes
        .onChange(of: model.timers) { oldValue, newValue in
            if let current = selectedTimerId,
               newValue.contains(where: { $0.id == current }) {
                // keep current selection
            } else {
                selectedTimerId = newValue.first?.id
            }
            // Start/stop extended runtime according to whether any timers are running
            refreshExtendedRuntimeSession()
        }
        // When an alert appears, play a lightweight haptic once
        .onChange(of: model.alertMessage) { oldValue, newValue in
            if newValue != nil {
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    // Break the main content into smaller subviews for faster type-checking
    @ViewBuilder
    private var mainContent: some View {
        if model.timers.isEmpty {
            emptyState
                .overlay(alertBanner, alignment: .top)
        } else {
            timersPager
                .overlay(alertBanner, alignment: .top)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(.gray)
            Text("No timers yet")
                .font(.headline)
            Text("Open the iPhone app to sync timers.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Refresh") {
                // Ask the iPhone for a snapshot (safe no-op if ignored)
                WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var timersPager: some View {
        TabView(selection: $selectedTimerId) {
            ForEach(model.timers) { row in
                timerPage(row)
                    .tag(row.id)
            }
        }
        .tabViewStyle(.page)
    }

    @ViewBuilder
    private func timerPage(_ row: WatchTimersModel.Row) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(for: row)
            Spacer(minLength: 8)
            presetButtons(for: row)
            // Centered Start/Pause button below preset buttons with tight spacing
            startStopButton(for: row)
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        // Add breathing room below the top bar timer name
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // Compact alert banner displayed at the top; tap to acknowledge/stop
    @ViewBuilder
    private var alertBanner: some View {
        if let message = model.alertMessage {
            Button {
                // Tell the iPhone to stop the alert, and hide locally
                var payload: [String: Any] = ["action": "ackAlert"]
                if let id = selectedTimerId { payload["timerId"] = id }
                WCSessionManager.shared.sendCommand(payload)
                model.alertMessage = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                    Text(message)
                        .font(.headline)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color("TimerRed"))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    // Returns the name of the currently visible timer (or first timer if none selected)
    private var selectedTimerName: String? {
        if model.timers.isEmpty { return nil }
        if let id = selectedTimerId,
           let row = model.timers.first(where: { $0.id == id }) {
            return row.name
        }
        return model.timers.first?.name
    }

    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // Build the button label using preset1 seconds if present; fallback to generic
    private func preset1Label(for row: WatchTimersModel.Row) -> String {
        if let preset = row.preset1Seconds {
            return format(seconds: preset)
        }
        return "Preset 1"
    }

    private func preset2Label(for row: WatchTimersModel.Row) -> String {
        if let preset = row.preset2Seconds {
            return "+" + format(seconds: preset)
        }
        return "+Preset 2"
    }

    // MARK: - Local time computations for smooth UI
    private func isRunning(_ row: WatchTimersModel.Row) -> Bool {
        row.state == "running"
    }

    private func effectiveRemaining(for row: WatchTimersModel.Row) -> Int {
        guard isRunning(row), let snap = model.lastSnapshotAt else { return row.remaining }
        let delta = max(0, Int(now.timeIntervalSince(snap)))
        return max(0, row.remaining - delta)
    }

    private func effectiveElapsed(for row: WatchTimersModel.Row) -> Int? {
        guard let base = row.elapsedSeconds else { return nil }
        guard isRunning(row), let snap = model.lastSnapshotAt else { return base }
        let delta = max(0, Int(now.timeIntervalSince(snap)))
        return max(0, base + delta)
    }

    // MARK: - Small helper views to keep body() simple for the compiler
    @ViewBuilder
    private func header(for row: WatchTimersModel.Row) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                // Add a small label next to the main remaining-time counter
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Flip In")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(format(seconds: effectiveRemaining(for: row)))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                if let shownElapsed = effectiveElapsed(for: row) {
                    Text("Lit Time \(format(seconds: shownElapsed))")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1) // ensure text has space
            Spacer()
        }
    }

    // Centered Start/Pause button placed below the preset buttons
    @ViewBuilder
    private func startStopButton(for row: WatchTimersModel.Row) -> some View {
        HStack { // center horizontally
            Spacer()
            Button(isRunning(row) ? "Pause" : "Start") {
                // Stronger haptic: start vs pause use distinct patterns
                let device = WKInterfaceDevice.current()
                if isRunning(row) {
                    device.play(.stop) // pausing
                    // Optimistically pause locally so UI responds immediately
                    optimisticPause(row)
                    // If nothing else is running, end the extended runtime session
                    refreshExtendedRuntimeSession()
                } else {
                    device.play(.start) // starting
                    // Optimistically start locally so UI responds immediately
                    // If the timer has no time, prefer Preset 1 if available
                    let startingRemaining = row.remaining > 0 ? row.remaining : (row.preset1Seconds ?? max(1, row.remaining))
                    optimisticStart(row, remainingOverride: startingRemaining)
                    // Ensure extended runtime is active while a timer is running
                    refreshExtendedRuntimeSession()
                }
                WCSessionManager.shared.sendCommand([
                    "action": "toggleRun",
                    "timerId": row.id
                ])
            }
            // Use a filled prominent style with brand tint, and white text for contrast
            .buttonStyle(.borderedProminent)
            .tint(Color("TimerAccent"))
            .foregroundStyle(.white)
            .controlSize(.mini)
            .font(.caption2)
            .buttonBorderShape(.roundedRectangle(radius: 6))
            .frame(width: 76, height: 44) // keep Apple tap height
            Spacer()
        }
    }

    @ViewBuilder
    private func presetButtons(for row: WatchTimersModel.Row) -> some View {
        HStack {
            Button(preset1Label(for: row)) {
                // Stronger confirmation haptic on preset apply
                WKInterfaceDevice.current().play(.success)
                // Optimistically apply Preset 1 and start immediately for snappy UX
                if let preset = row.preset1Seconds {
                    optimisticStart(row, remainingOverride: preset)
                    refreshExtendedRuntimeSession()
                }
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset1",
                    "timerId": row.id
                ])
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PresetButtonBG"))
            // Use .small so the custom minHeight is applied on watchOS
            .controlSize(.small)
            // Slightly larger label text for better readability on-watch
            .font(.footnote)
            .foregroundStyle(.white)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            // Increase vertical height for a taller, easier tap target on watchOS
            .frame(minWidth: 64, minHeight: 52)

            Button(preset2Label(for: row)) {
                // Stronger confirmation haptic on preset apply
                WKInterfaceDevice.current().play(.success)
                // Optimistically apply Preset 2 and start immediately for snappy UX
                if let preset = row.preset2Seconds {
                    optimisticStart(row, remainingOverride: preset)
                    refreshExtendedRuntimeSession()
                }
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset2",
                    "timerId": row.id
                ])
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("PresetButtonBG"))
            // Use .small so the custom minHeight is applied on watchOS
            .controlSize(.small)
            // Slightly larger label text for better readability on-watch
            .font(.footnote)
            .foregroundStyle(.white)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            // Increase vertical height for a taller, easier tap target on watchOS
            .frame(minWidth: 64, minHeight: 52)
        }
    }

    // MARK: - Optimistic UI helpers
    /// Immediately reflect a local start so the countdown and state change without
    /// waiting for the iPhone round-trip. The next snapshot will reconcile if needed.
    private func optimisticStart(_ row: WatchTimersModel.Row, remainingOverride: Int? = nil) {
        let newRemaining = max(1, remainingOverride ?? effectiveRemaining(for: row))
        // Nudge the local clock so effectiveRemaining() subtracts time smoothly
        model.lastSnapshotAt = Date()
        model.timers = model.timers.map { item in
            if item.id == row.id {
                return WatchTimersModel.Row(
                    id: item.id,
                    name: item.name,
                    remaining: newRemaining,
                    state: "running",
                    preset1Seconds: item.preset1Seconds,
                    preset2Seconds: item.preset2Seconds,
                    elapsedSeconds: item.elapsedSeconds
                )
            }
            return item
        }
    }

    /// Immediately reflect a local pause so the UI stops ticking at the current
    /// effective remaining time.
    private func optimisticPause(_ row: WatchTimersModel.Row) {
        let currentRemaining = effectiveRemaining(for: row)
        model.timers = model.timers.map { item in
            if item.id == row.id {
                return WatchTimersModel.Row(
                    id: item.id,
                    name: item.name,
                    remaining: currentRemaining,
                    state: "stopped",
                    preset1Seconds: item.preset1Seconds,
                    preset2Seconds: item.preset2Seconds,
                    elapsedSeconds: item.elapsedSeconds
                )
            }
            return item
        }
    }

    /// Starts extended runtime while any timer is running; invalidates otherwise.
    private func refreshExtendedRuntimeSession() {
        let anyRunning = model.timers.contains { $0.state == "running" }
        if anyRunning {
            runtime.startIfNeeded()
        } else {
            runtime.invalidate()
        }
    }
}

final class WatchTimersModel: ObservableObject {
    // Conform to Equatable so Array<Row> can be used with onChange(of:)
    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        let remaining: Int
        let state: String
        // Optional: seconds for Preset 1 provided by iPhone snapshot
        let preset1Seconds: Int?
        // Optional: seconds for Preset 2 provided by iPhone snapshot
        let preset2Seconds: Int?
        // Optional: elapsed seconds provided by iPhone snapshot
        let elapsedSeconds: Int?
    }

    @Published var timers: [Row] = []
    // When the last snapshot was received (used for local ticking)
    @Published var lastSnapshotAt: Date? = nil
    // Message to show in the alert banner when iPhone signals an alert
    @Published var alertMessage: String? = nil

    init() {
        NotificationCenter.default.addObserver(forName: Notification.Name("receivedTimersSnapshot"), object: nil, queue: .main) { [weak self] note in
            guard let dict = note.userInfo as? [String: Any], let arr = dict["timers"] as? [[String: Any]] else { return }
            self?.lastSnapshotAt = Date()
            self?.timers = arr.compactMap { item in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String,
                      let remaining = item["remaining"] as? Int,
                      let state = item["state"] as? String else { return nil }
                let preset1 = item["preset1"] as? Int
                let preset2 = item["preset2"] as? Int
                let elapsed = item["elapsed"] as? Int
                return Row(id: id, name: name, remaining: remaining, state: state, preset1Seconds: preset1, preset2Seconds: preset2, elapsedSeconds: elapsed)
            }
        }
        // Listen for explicit alert messages sent from iPhone via the session manager
        NotificationCenter.default.addObserver(forName: Notification.Name("receivedAlert"), object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo as? [String: Any], let phase = info["phase"] as? String else { return }
            if phase == "start" {
                let msg = (info["message"] as? String) ?? "Timer Finished"
                self?.alertMessage = msg
            } else if phase == "stop" {
                self?.alertMessage = nil
            }
        }
    }
}

// MARK: - Extended runtime controller
/// Lightweight wrapper around `WKExtendedRuntimeSession` that starts a background
/// execution window while timers are active, helping keep countdowns accurate
/// when the app returns to the watch face. It does not keep the app visible.
final class ExtendedRuntimeController: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    private(set) var isRunning: Bool = false

    /// Start a new extended runtime session if not already running.
    func startIfNeeded() {
        if isRunning { return }
        // Always create a fresh session to avoid edge states
        session?.invalidate()
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession
        newSession.start()
    }

    /// End the session if one is active.
    func invalidate() {
        guard let s = session else { return }
        s.invalidate()
        session = nil
        isRunning = false
    }

    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        isRunning = true
        #if DEBUG
        print("[ExtendedRuntime] didStart")
        #endif
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        #if DEBUG
        print("[ExtendedRuntime] willExpire soon")
        #endif
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        isRunning = false
        session = nil
        #if DEBUG
        print("[ExtendedRuntime] invalidated, reason=\(reason.rawValue), error=\(String(describing: error))")
        #endif
    }
}

// MARK: - SwiftUI Preview
// This preview enables Xcode Canvas for the watch UI.
// It renders `TimersListView`, which shows either the empty state
// or any timers provided by a snapshot during previews.
#if DEBUG
// Break the large literal into simple constants the compiler can type-check quickly.
private func previewSampleTimers() -> [[String: Any]] {
    let t1: [String: Any] = [
        "id": UUID().uuidString,
        "name": "Ribeye",
        "remaining": 300,
        "state": "running",
        "preset1": 300,
        "preset2": 60,
        "elapsed": 0
    ]
    let t2: [String: Any] = [
        "id": UUID().uuidString,
        "name": "Tri‑Tip",
        "remaining": 900,
        "state": "stopped",
        "preset1": 900,
        "preset2": 120,
        "elapsed": 0
    ]
    return [t1, t2]
}

#Preview {
    TimersListView()
}

#Preview("With sample timers") {
    // Preview that injects a mock snapshot so Canvas shows real rows
    TimersListView()
        .onAppear {
            let timers: [[String: Any]] = previewSampleTimers()
            NotificationCenter.default.post(
                name: Notification.Name("receivedTimersSnapshot"),
                object: nil,
                userInfo: ["timers": timers]
            )
        }
}
#endif

