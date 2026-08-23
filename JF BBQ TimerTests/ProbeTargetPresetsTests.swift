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

// MARK: - Settings.renameTimer

// Settings is UserDefaults-backed with no injectable store, so these tests
// read/write UserDefaults.standard directly like NotificationSoundProviderTests
// does — each saves and restores the keys it touches.
@Suite("Settings.renameTimer")
struct SettingsRenameTimerTests {

    /// Snapshot + restore every key a test in this suite might touch, so runs
    /// don't leak into each other or into the app's real persisted settings.
    private static let keys = ["timer1Name", "timer2Name", "additionalTimers",
                               "selectedAlertSound"]

    private func withCleanSlate(_ body: (Settings) -> Void) {
        let saved = Self.keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(Self.keys, saved) {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        for key in ["timer1Name", "timer2Name", "additionalTimers"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        // Settings.init has a first-launch branch that WRITES a default
        // "selectedBundledSoundID" when no sound choice exists at all. Suites
        // run in parallel, so that write can race NotificationSoundProviderTests
        // (which clears the key and expects the system default). Seeding one of
        // the branch's guard keys keeps constructing Settings side-effect-free.
        if UserDefaults.standard.object(forKey: "selectedAlertSound") == nil {
            UserDefaults.standard.set(Settings.AlertSound.system.rawValue,
                                      forKey: "selectedAlertSound")
        }
        body(Settings())
    }

    @Test("renaming legacy timer 1 updates timer1Name")
    func renamesLegacyTimer1() {
        withCleanSlate { settings in
            let id = settings.legacyTimersAsBBQTimers[0].id
            settings.renameTimer(id: id, to: "Chicken")
            #expect(settings.timer1Name == "Chicken")
        }
    }

    @Test("renaming legacy timer 2 updates timer2Name")
    func renamesLegacyTimer2() {
        withCleanSlate { settings in
            let id = settings.legacyTimersAsBBQTimers[1].id
            settings.renameTimer(id: id, to: "Brisket")
            #expect(settings.timer2Name == "Brisket")
        }
    }

    @Test("renaming an additional timer updates that element's name")
    func renamesAdditionalTimer() {
        withCleanSlate { settings in
            let extra = BBQTimer(name: "Timer 3", preset1: 60, preset2: 120)
            settings.additionalTimers = [extra]
            settings.renameTimer(id: extra.id, to: "Ribs")
            #expect(settings.additionalTimers[0].name == "Ribs")
        }
    }

    @Test("unknown id is a no-op")
    func unknownIDNoOp() {
        withCleanSlate { settings in
            let before = (settings.timer1Name, settings.timer2Name, settings.additionalTimers)
            settings.renameTimer(id: UUID(), to: "Nope")
            #expect(settings.timer1Name == before.0)
            #expect(settings.timer2Name == before.1)
            #expect(settings.additionalTimers == before.2)
        }
    }

    @Test("same name is a no-op")
    func sameNameNoOp() {
        withCleanSlate { settings in
            let id = settings.legacyTimersAsBBQTimers[0].id
            let originalName = settings.timer1Name
            settings.renameTimer(id: id, to: originalName)
            #expect(settings.timer1Name == originalName)
        }
    }

    @Test("whitespace-only name is a no-op")
    func whitespaceOnlyNoOp() {
        withCleanSlate { settings in
            let id = settings.legacyTimersAsBBQTimers[0].id
            let originalName = settings.timer1Name
            settings.renameTimer(id: id, to: "   ")
            #expect(settings.timer1Name == originalName)
        }
    }
}
