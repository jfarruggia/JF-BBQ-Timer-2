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
        List(model.timers, id: \.id) { row in
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.headline)
                HStack {
                    Text(format(seconds: row.remaining))
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Button("Reset") {
                        WCSessionManager.shared.sendCommand(["action": "reset", "timerId": row.id])
                    }
                    .buttonStyle(.bordered)
                    Button("Extend +1:00") {
                        WCSessionManager.shared.sendCommand(["action": "extend", "timerId": row.id, "seconds": 60])
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

final class WatchTimersModel: ObservableObject {
    struct Row: Identifiable {
        let id: String
        let name: String
        let remaining: Int
        let state: String
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
                return Row(id: id, name: name, remaining: remaining, state: state)
            }
        }
    }
}

