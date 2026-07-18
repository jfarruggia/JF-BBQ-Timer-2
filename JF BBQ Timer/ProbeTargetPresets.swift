// ProbeTargetPresets.swift
// Grill Time Pro
//
// User-editable doneness presets for the probe target sheet's "Common
// targets" list. Temperatures are canonical °C (converted to the user's
// unit at display, like all probe values). The stored list is seeded from
// `ProbeTargetPresets.defaults` on first run and persisted by Settings.
// iOS-only by target membership (new files in this folder don't join the
// watch target).

import Foundation

// MARK: - Model

struct ProbeTargetPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var celsius: Double
}

// MARK: - Defaults + rules

enum ProbeTargetPresets {

    /// Keep the picker scrollable — hard cap on user-added presets.
    static let maxCount = 20

    /// The standard list a fresh install starts with (US-familiar °F values).
    static var defaults: [ProbeTargetPreset] {
        [
            ProbeTargetPreset(name: "Chicken / Turkey", celsius: 73.9),  // 165 °F
            ProbeTargetPreset(name: "Pork chops",       celsius: 62.8),  // 145 °F
            ProbeTargetPreset(name: "Ribs",             celsius: 90.6),  // 195 °F
            ProbeTargetPreset(name: "Pulled pork",      celsius: 96.1),  // 205 °F
            ProbeTargetPreset(name: "Brisket",          celsius: 95.0),  // 203 °F
            ProbeTargetPreset(name: "Beef med-rare",    celsius: 54.4),  // 130 °F
            ProbeTargetPreset(name: "Beef medium",      celsius: 60.0),  // 140 °F
        ]
    }

    /// Same validity window as custom target entry (probe set point tops out
    /// at 102.3 °C; ≤ 0 °C is meaningless for cooking).
    static let validCelsiusRange = 1.0...102.0

    /// A preset is storable when its name is non-blank and its temperature is
    /// inside the probe's representable range.
    static func isValid(_ preset: ProbeTargetPreset) -> Bool {
        !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && validCelsiusRange.contains(preset.celsius)
    }
}
