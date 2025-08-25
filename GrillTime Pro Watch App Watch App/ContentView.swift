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
                List(model.timers, id: \.id) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        // Timer name
                        Text(row.name)
                            .font(.headline)
                        // Big countdown above buttons
                        Text(format(seconds: row.remaining))
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                        // Small elapsed label under countdown, if available
                        if let elapsed = row.elapsedSeconds {
                            Text("Elapsed \(format(seconds: elapsed))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        // Buttons row
                        HStack {
                            Button(preset1Label(for: row)) {
                                // Ask iPhone to apply its Preset 1 for this specific timer
                                WCSessionManager.shared.sendCommand([
                                    "action": "applyPreset1",
                                    "timerId": row.id
                                ])
                            }
                            .buttonStyle(.bordered)
                            Button(preset2Label(for: row)) {
                                WCSessionManager.shared.sendCommand([
                                    "action": "applyPreset2",
                                    "timerId": row.id
                                ])
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
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

    init() {
        NotificationCenter.default.addObserver(forName: Notification.Name("receivedTimersSnapshot"), object: nil, queue: .main) { [weak self] note in
            guard let dict = note.userInfo as? [String: Any], let arr = dict["timers"] as? [[String: Any]] else { return }
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

