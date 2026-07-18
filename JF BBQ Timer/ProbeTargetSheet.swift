// ProbeTargetSheet.swift
// Grill Time Pro
//
// Sheet for setting a cook's probe target temperature — the temp the food
// should reach. Drives the probe's prediction set point (removal + resting
// mode) and the phone-side target-crossed alert. Values are entered and
// displayed in the user's unit but stored in canonical °C.
//
// The "Common targets" list is user-editable (ProbeTargetPreset, stored in
// Settings): Edit opens ProbeTargetPresetEditor for rename/retemp/delete/add
// plus a restore-defaults escape hatch.
// Gated behind #if os(iOS) — the watch never presents this UI.

#if os(iOS)

import SwiftUI

@available(iOS 16, *)
struct ProbeTargetSheet: View {

    let cookName: String
    let unit: TemperatureUnit
    /// The cook's current target (°C), nil when unset.
    let currentTargetCelsius: Double?
    /// Source of the editable preset list.
    @ObservedObject var settings: Settings
    /// Called with the chosen target in °C, or nil to clear it.
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var entryText: String = ""
    @FocusState private var entryFocused: Bool

    /// The typed entry parsed to °C, nil when empty/garbled/out of range.
    private var enteredCelsius: Double? {
        guard let value = Double(entryText.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        let celsius = unit.celsius(fromValue: value)
        return ProbeTargetPresets.validCelsiusRange.contains(celsius) ? celsius : nil
    }

    private var rangeHint: String {
        let range = ProbeTargetPresets.validCelsiusRange
        let low  = Int(unit.value(fromCelsius: range.lowerBound).rounded())
        let high = Int(unit.value(fromCelsius: range.upperBound).rounded())
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
                    ForEach(settings.probeTargetPresets) { preset in
                        Button {
                            onSave(preset.celsius)
                            dismiss()
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(unit.compactString(fromCelsius: preset.celsius))
                                    .monospacedDigit()
                                    .foregroundStyle(Color("TimerAccent"))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Common targets")
                            .textCase(nil)
                        Spacer()
                        NavigationLink("Edit") {
                            ProbeTargetPresetEditor(settings: settings, unit: unit)
                        }
                        .font(.footnote.weight(.semibold))
                    }
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

// MARK: - Preset editor

/// Manage the "Common targets" list: tap to edit, swipe to delete, add new,
/// restore the standard defaults. Pushed from the target sheet's Edit link.
@available(iOS 16, *)
struct ProbeTargetPresetEditor: View {

    @ObservedObject var settings: Settings
    let unit: TemperatureUnit

    @State private var editingPreset: ProbeTargetPreset? = nil
    @State private var addingPreset = false
    @State private var confirmRestore = false

    var body: some View {
        List {
            Section {
                ForEach(settings.probeTargetPresets) { preset in
                    Button {
                        editingPreset = preset
                    } label: {
                        HStack {
                            Text(preset.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(unit.compactString(fromCelsius: preset.celsius))
                                .monospacedDigit()
                                .foregroundStyle(Color("TimerAccent"))
                        }
                    }
                }
                .onDelete { offsets in
                    settings.removeProbeTargetPresets(at: offsets)
                }

                if settings.probeTargetPresets.count < ProbeTargetPresets.maxCount {
                    Button {
                        addingPreset = true
                    } label: {
                        Label("Add preset", systemImage: "plus.circle.fill")
                    }
                }
            } footer: {
                Text("Tap a preset to change its name or temperature. Swipe left to delete.")
            }

            Section {
                Button("Restore default list") {
                    confirmRestore = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .immersiveGlassList()
        .tint(Color("TimerAccent"))
        .navigationTitle("Common Targets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPreset) { preset in
            ProbeTargetPresetForm(unit: unit, preset: preset) { updated in
                settings.updateProbeTargetPreset(updated)
            }
        }
        .sheet(isPresented: $addingPreset) {
            ProbeTargetPresetForm(unit: unit, preset: nil) { new in
                settings.addProbeTargetPreset(new)
            }
        }
        .alert("Replace your list with the standard presets?", isPresented: $confirmRestore) {
            Button("Restore Defaults", role: .destructive) {
                settings.restoreDefaultProbeTargetPresets()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your custom presets will be removed.")
        }
    }
}

// MARK: - Preset add/edit form

/// Small form for one preset: name + temperature in the user's unit.
/// Pass `preset: nil` to create a new one.
@available(iOS 16, *)
private struct ProbeTargetPresetForm: View {

    let unit: TemperatureUnit
    let preset: ProbeTargetPreset?
    let onCommit: (ProbeTargetPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var temperatureText: String = ""
    @FocusState private var nameFocused: Bool

    private var enteredCelsius: Double? {
        guard let value = Double(temperatureText.replacingOccurrences(of: ",", with: ".")) else {
            return nil
        }
        let celsius = unit.celsius(fromValue: value)
        return ProbeTargetPresets.validCelsiusRange.contains(celsius) ? celsius : nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && enteredCelsius != nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name (e.g. Tri-tip)", text: $name)
                        .focused($nameFocused)
                    TextField("Temperature in \(unit.symbol)", text: $temperatureText)
                        .keyboardType(.decimalPad)
                } footer: {
                    let range = ProbeTargetPresets.validCelsiusRange
                    let low  = Int(unit.value(fromCelsius: range.lowerBound).rounded())
                    let high = Int(unit.value(fromCelsius: range.upperBound).rounded())
                    Text("Temperature between \(low) and \(high)\(unit.symbol).")
                }
            }
            .listStyle(.insetGrouped)
            .immersiveGlassList()
            .tint(Color("TimerAccent"))
            .navigationTitle(preset == nil ? "New Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let celsius = enteredCelsius else { return }
                        var result = preset ?? ProbeTargetPreset(name: "", celsius: celsius)
                        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        result.celsius = celsius
                        onCommit(result)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let preset {
                    name = preset.name
                    temperatureText = String(Int(unit.value(fromCelsius: preset.celsius).rounded()))
                } else {
                    nameFocused = true
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#endif // os(iOS)
