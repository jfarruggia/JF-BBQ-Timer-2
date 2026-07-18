// ProbeTargetPresetsTests.swift
// Grill Time Pro
//
// Swift Testing suite for the editable probe-target preset model: defaults,
// validation rules, and wire (JSON) round-trip. The Settings CRUD wrappers are
// thin guards over these rules and UserDefaults, so the rules are what's
// pinned here.

import Testing
import Foundation
@testable import JF_BBQ_Timer

@Suite("ProbeTargetPresets")
struct ProbeTargetPresetsTests {

    @Test("default list is sane: non-empty, within cap, all valid, expected anchors")
    func defaultsSane() {
        let defaults = ProbeTargetPresets.defaults
        #expect(!defaults.isEmpty)
        #expect(defaults.count <= ProbeTargetPresets.maxCount)
        #expect(defaults.allSatisfy { ProbeTargetPresets.isValid($0) })
        // Anchor two well-known values (°C canonical: 165 °F chicken, 203 °F brisket)
        #expect(defaults.contains { $0.name == "Chicken / Turkey" && abs($0.celsius - 73.9) < 1e-9 })
        #expect(defaults.contains { $0.name == "Brisket" && abs($0.celsius - 95.0) < 1e-9 })
    }

    @Test("validation: blank names and out-of-range temperatures are rejected")
    func validationRules() {
        #expect(ProbeTargetPresets.isValid(.init(name: "Tri-tip", celsius: 57.0)))
        #expect(!ProbeTargetPresets.isValid(.init(name: "", celsius: 57.0)))
        #expect(!ProbeTargetPresets.isValid(.init(name: "   ", celsius: 57.0)))
        #expect(!ProbeTargetPresets.isValid(.init(name: "Ice", celsius: 0.0)))
        #expect(!ProbeTargetPresets.isValid(.init(name: "Lava", celsius: 200.0)))
        // Range edges are inclusive
        #expect(ProbeTargetPresets.isValid(.init(name: "Low", celsius: 1.0)))
        #expect(ProbeTargetPresets.isValid(.init(name: "High", celsius: 102.0)))
    }

    @Test("JSON round-trip preserves ids, names, and temperatures")
    func jsonRoundTrip() throws {
        let original = ProbeTargetPresets.defaults + [ProbeTargetPreset(name: "Sausage", celsius: 71.1)]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([ProbeTargetPreset].self, from: data)
        #expect(decoded == original)
    }

    @Test("preset validation range matches the custom-entry range used by the sheet")
    func rangeMatchesSheet() {
        // Both flows must accept the same temperatures — the probe's set point
        // field tops out at 102.3 °C.
        #expect(ProbeTargetPresets.validCelsiusRange == 1.0...102.0)
    }
}
