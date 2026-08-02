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

    @Test("free Featured category exists, holds the free pair, and sorts first")
    func featuredCategory() {
        let manager = BundledSoundsManager()
        let featured = manager.sounds(in: BundledSoundsManager.freeCategory)
        let names = Set(featured.map(\.displayName))
        #expect(names.contains("Dinner Triangle"))
        #expect(names.contains("Chimes"))
        // Listed first so the picker's ungated section maps to the catalog order
        #expect(manager.categories.first == BundledSoundsManager.freeCategory)
    }
}

@Suite("Notification sound provider")
struct NotificationSoundProviderTests {

    @Test("alarm variant naming strips the extension and appends ' Alarm.caf'")
    func variantNaming() {
        #expect(NotificationSoundProvider.alarmVariantName(forCatalogFilename: "Fog Horn.wav")
                == "Fog Horn Alarm.caf")
        #expect(NotificationSoundProvider.alarmVariantName(forCatalogFilename: "Danger Alert.mp3")
                == "Danger Alert Alarm.caf")
    }

    @Test("every catalog sound has a bundled alarm variant that installs into Library/Sounds")
    func everyVariantInstalls() {
        for sound in BundledSoundsManager().allSounds {
            let variant = NotificationSoundProvider.alarmVariantName(forCatalogFilename: sound.filename)
            let installed = NotificationSoundProvider.installIntoLibrarySounds(bundleFilename: variant)
            #expect(installed == variant, "\(variant) missing from bundle or install failed")
        }
    }

    @Test("no bundled selection → system default sound")
    func defaultWithoutSelection() {
        let saved = UserDefaults.standard.string(forKey: "selectedBundledSoundID")
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: "selectedBundledSoundID") }
            else { UserDefaults.standard.removeObject(forKey: "selectedBundledSoundID") }
        }
        UserDefaults.standard.removeObject(forKey: "selectedBundledSoundID")
        #expect(NotificationSoundProvider.currentSound() == .default)
    }

    @Test("a bundled selection resolves to a non-default named sound")
    func selectionResolvesToNamedSound() {
        let manager = BundledSoundsManager()
        guard let sound = manager.allSounds.first else {
            Issue.record("Catalog empty")
            return
        }
        let saved = UserDefaults.standard.string(forKey: "selectedBundledSoundID")
        defer {
            if let saved { UserDefaults.standard.set(saved, forKey: "selectedBundledSoundID") }
            else { UserDefaults.standard.removeObject(forKey: "selectedBundledSoundID") }
        }
        UserDefaults.standard.set(sound.id.uuidString, forKey: "selectedBundledSoundID")
        #expect(NotificationSoundProvider.currentSound() != .default)
    }
}
