// BundledSoundsTests.swift
// Grill Time Pro
//
// Guards the bundled-sound catalog: every entry in sound_metadata.json must
// resolve to a real file in the app bundle (tests are hosted in the app, so
// Bundle.main is the app bundle). Catches filename typos and forgotten files
// whenever sounds are added or renamed.

import Testing
import Foundation
@testable import JF_BBQ_Timer

@Suite("Bundled sound catalog")
struct BundledSoundsTests {

    @Test("metadata loads and every entry's file exists in the bundle")
    func catalogFilesAllPresent() {
        let manager = BundledSoundsManager()
        #expect(!manager.allSounds.isEmpty, "sound_metadata.json failed to load or is empty")
        for sound in manager.allSounds {
            #expect(sound.fileURL != nil, "\(sound.filename) is in the catalog but not in the bundle")
        }
    }

    @Test("the 2026-07 additions are in the catalog")
    func newSoundsRegistered() {
        let names = Set(BundledSoundsManager().allSounds.map(\.displayName))
        #expect(names.contains("Church Bell"))
        #expect(names.contains("Ocean Liner Horn"))
    }
}
