// ProbePickerView.swift
// Grill Time Pro
//
// Minimal SwiftUI picker for selecting and connecting to a Combustion probe.
// Real visual polish is deferred to Phase 2E.
// Gated behind #if os(iOS) — the watch never presents this UI.

#if os(iOS)

import SwiftUI

// MARK: - ProbeReadingRow

/// Simple label + value row that avoids LabeledContent (requires iOS 16 in Swift 6 mode).
private struct ProbeReadingRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ProbePickerView

struct ProbePickerView: View {

    @ObservedObject var probeManager: ProbeBLEManager

    var body: some View {
        List {
            // MARK: Connection state banner
            Section(header: Text("Status")) {
                Text(connectionStateDescription)
                    .foregroundStyle(.secondary)
            }

            // MARK: Scan controls
            Section {
                if case .scanning = probeManager.connectionState {
                    Button("Stop Scanning") {
                        probeManager.stopScanning()
                    }
                    .foregroundStyle(.red)
                } else {
                    Button("Scan for Probes") {
                        probeManager.startScanning()
                    }
                    .disabled(!probeManager.bluetoothReady)
                }
            }

            // MARK: Discovered probes
            if !probeManager.discoveredProbes.isEmpty {
                Section(header: Text("Discovered Probes")) {
                    ForEach(probeManager.discoveredProbes) { probe in
                        Button {
                            probeManager.connect(probe.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(probe.name ?? "Unknown Probe")
                                        .fontWeight(.medium)
                                    Text(probe.id.uuidString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(probe.rssi) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            // MARK: Live reading (when connected)
            if let reading = probeManager.latestReading {
                Section(header: Text("Live Reading")) {
                    ProbeReadingRow(label: "Core Temp",
                                   value: String(format: "%.1f °C", reading.coreTempC))
                    ProbeReadingRow(label: "Surface Temp",
                                   value: String(format: "%.1f °C", reading.surfaceTempC))
                    ProbeReadingRow(label: "Ambient Temp",
                                   value: String(format: "%.1f °C", reading.ambientTempC))
                    ProbeReadingRow(label: "Prediction State",
                                   value: predictionStateDescription(reading.prediction.state))
                    if reading.prediction.state.isActivePrediction {
                        ProbeReadingRow(label: "Est. Time Remaining",
                                        value: "\(reading.prediction.predictionSeconds / 60) min")
                    }
                }
            }

            // MARK: Disconnect button (when connected or reconnecting)
            // Shown during `.reconnecting` too so the user can cancel a stuck reconnect.
            if case .connected   = probeManager.connectionState { disconnectSection }
            if case .reconnecting = probeManager.connectionState { disconnectSection }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connect Probe")
    }

    // MARK: - Helpers

    @ViewBuilder
    private var disconnectSection: some View {
        Section {
            Button("Disconnect") {
                probeManager.disconnect()
            }
            .foregroundStyle(.red)
        }
    }

    private var connectionStateDescription: String {
        switch probeManager.connectionState {
        case .poweredOff:
            return "Bluetooth is off"
        case .idle:
            return probeManager.bluetoothReady ? "Ready — tap Scan to discover probes" : "Bluetooth unavailable"
        case .scanning:
            return "Scanning…"
        case .connecting(let id):
            return "Connecting to \(id.uuidString.prefix(8))…"
        case .connected(let id):
            return "Connected to \(id.uuidString.prefix(8))"
        case .reconnecting(let id):
            return "Reconnecting to \(id.uuidString.prefix(8))…"
        case .disconnected:
            return "Disconnected"
        }
    }

    private func predictionStateDescription(_ state: PredictionState) -> String {
        switch state {
        case .probeNotInserted:       return "Not inserted"
        case .probeInserted:          return "Inserted"
        case .cooking:                return "Cooking"
        case .predicting:             return "Predicting"
        case .removalPredictionDone:  return "Done"
        case .unknown:                return "Unknown"
        }
    }
}

#endif // os(iOS)
