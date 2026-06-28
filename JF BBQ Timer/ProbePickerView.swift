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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            pickerList
                .listStyle(.insetGrouped)
                .immersiveGlassList()
                .tint(Color("TimerAccent"))
                .navigationTitle("Connect Probe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .navigationViewStyle(.stack)
    }

    private var pickerList: some View {
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
                                    Text(probe.name ?? "Combustion Probe")
                                        .fontWeight(.medium)
                                    Text(probe.serial.map { "Serial \($0)" } ?? probe.id.uuidString)
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
            return "Connecting to \(label(for: id))…"
        case .connected(let id):
            return "Connected to \(label(for: id))"
        case .reconnecting(let id):
            return "Reconnecting to \(label(for: id))…"
        case .disconnected:
            return "Disconnected"
        }
    }

    /// Prefer the probe's serial (e.g. "1000FADE") for status text; fall back to the
    /// short peripheral-id prefix if we never captured the serial (e.g. auto-reconnect).
    private func label(for id: UUID) -> String {
        probeManager.serialsByID[id] ?? String(id.uuidString.prefix(8))
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
