// ProbeTargetSheet.swift
// Grill Time Pro
//
// Sheet for setting a cook's probe target temperature — the temp the food
// should reach. Drives the probe's prediction set point (removal + resting
// mode) and, later, the phone-side target-crossed alert. Values are entered
// and displayed in the user's unit but stored in canonical °C.
// Gated behind #if os(iOS) — the watch never presents this UI.

#if os(iOS)

import SwiftUI

@available(iOS 16, *)
struct ProbeTargetSheet: View {

    let cookName: String
    let unit: TemperatureUnit
    /// The cook's current target (°C), nil when unset.
    let currentTargetCelsius: Double?
    /// Called with the chosen target in °C, or nil to clear it.
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entryText: String = ""
    @FocusState private var entryFocused: Bool

    /// Common BBQ doneness targets, canonical °C (US-familiar °F in comments).
    private static let quickPicks: [(name: String, celsius: Double)] = [
        ("Chicken / Turkey", 73.9),   // 165 °F
        ("Pork chops",       62.8),   // 145 °F
        ("Ribs",             90.6),   // 195 °F
        ("Pulled pork",      96.1),   // 205 °F
        ("Brisket",          95.0),   // 203 °F
        ("Beef med-rare",    54.4),   // 130 °F
        ("Beef medium",      60.0),   // 140 °F
    ]

    /// Valid target range in °C — the probe's set-point field tops out at
    /// 102.3 °C, and anything at/below 0 is meaningless for cooking.
    private static let validCelsiusRange = 1.0...102.0

    /// The typed entry parsed to °C, nil when empty/garbled/out of range.
    private var enteredCelsius: Double? {
        guard let value = Double(entryText.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        let celsius = unit.celsius(fromValue: value)
        return Self.validCelsiusRange.contains(celsius) ? celsius : nil
    }

    private var rangeHint: String {
        let low  = Int(unit.value(fromCelsius: Self.validCelsiusRange.lowerBound).rounded())
        let high = Int(unit.value(fromCelsius: Self.validCelsiusRange.upperBound).rounded())
        return "\(low)–\(high)\(unit.symbol)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Temperature in \(unit.symbol)", text: $entryText)
                            .keyboardType(.decimalPad)
                            .focused($entryFocused)
                        Button("Set") {
                            if let celsius = enteredCelsius {
                                onSave(celsius)
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(enteredCelsius == nil)
                    }
                } header: {
                    Text("Custom target")
                        .textCase(nil)
                } footer: {
                    Text("Between \(rangeHint). The probe predicts when to pull the food so resting carries it to this temperature.")
                }

                Section {
                    ForEach(Self.quickPicks, id: \.name) { pick in
                        Button {
                            onSave(pick.celsius)
                            dismiss()
                        } label: {
                            HStack {
                                Text(pick.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(unit.compactString(fromCelsius: pick.celsius))
                                    .monospacedDigit()
                                    .foregroundStyle(Color("TimerAccent"))
                            }
                        }
                    }
                } header: {
                    Text("Common targets")
                        .textCase(nil)
                }

                if currentTargetCelsius != nil {
                    Section {
                        Button(role: .destructive) {
                            onSave(nil)
                            dismiss()
                        } label: {
                            Text("Clear target")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .immersiveGlassList()
            .tint(Color("TimerAccent"))
            .navigationTitle("Target for \(cookName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let current = currentTargetCelsius {
                    let shown = unit.value(fromCelsius: current)
                    entryText = String(Int(shown.rounded()))
                } else {
                    entryFocused = true
                }
            }
        }
    }
}

#endif // os(iOS)
