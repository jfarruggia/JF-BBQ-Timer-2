//
//  ContentView.swift
//  GrillTime Pro Watch App Watch App
//
//  Created by James Farruggia on 8/17/25.
//

import SwiftUI
import WatchConnectivity

struct TimersListView: View {
    @StateObject private var model = WatchTimersModel()
    // Local ticker so the watch UI updates every second without waiting for iPhone
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Show a friendly placeholder when no timers have been
        // received from the iPhone yet. This avoids a black screen
        // and teaches the user what to do next.
        Group {
            if model.timers.isEmpty {
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
            } else {
                // Use a paged TabView: one full-screen page per timer, swipe to switch
                TabView {
                    ForEach(model.timers, id: \.id) { row in
                        ZStack(alignment: .topLeading) {
                            // Main content
                            VStack(alignment: .leading, spacing: 8) {
                                header(for: row)
                                Spacer(minLength: 8)
                                presetButtons(for: row)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal)
                            // Add headroom so overlayed name doesn’t overlap
                            .padding(.top, 18)

                            // Timer name pinned to real top-left
                            Text(row.name)
                                .font(.headline)
                                .padding(.leading, 2)
                                .padding(.top, -8) // lift higher into the top-left corner
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .tabViewStyle(.page)
            }
        }
        // Drive the local clock
        .onReceive(ticker) { date in
            now = date
        }
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
                Text(format(seconds: effectiveRemaining(for: row)))
                    .font(.title2)
                    .fontWeight(.bold)
                if let shownElapsed = effectiveElapsed(for: row) {
                    Text("Elapsed \(format(seconds: shownElapsed))")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .layoutPriority(1) // ensure text has space; avoids truncation under button
            Spacer()
            Button(isRunning(row) ? "Pause" : "Start") {
                WCSessionManager.shared.sendCommand([
                    "action": "toggleRun",
                    "timerId": row.id
                ])
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(.caption2)
            .buttonBorderShape(.roundedRectangle(radius: 6))
            .frame(width: 76, height: 44) // narrow width, keep Apple tap height
        }
    }

    @ViewBuilder
    private func presetButtons(for row: WatchTimersModel.Row) -> some View {
        HStack {
            Button(preset1Label(for: row)) {
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset1",
                    "timerId": row.id
                ])
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(.caption)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .frame(minWidth: 64, minHeight: 44)

            Button(preset2Label(for: row)) {
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset2",
                    "timerId": row.id
                ])
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(.caption)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .frame(minWidth: 64, minHeight: 44)
        }
    }
}

final class WatchTimersModel: ObservableObject {
    struct Row: Identifiable {
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

