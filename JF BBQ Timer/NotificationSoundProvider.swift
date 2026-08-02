// NotificationSoundProvider.swift
// Grill Time Pro
//
// Resolves the user's selected alert sound into a UNNotificationSound so
// lock-screen notifications play the chosen sound instead of the stock ding.
//
// Every bundled sound ships with a hidden "<name> Alarm.caf" variant — the
// sound repeated with short gaps to ~20 s (mono IMA4, the notification-safe
// format) — generated at build time and kept OUT of sound_metadata.json so
// pickers never show it. UserNotifications only loads app-provided files from
// the bundle root or the container's Library/Sounds directory; because the
// bundle layout of Resources/Sounds isn't guaranteed, the variant is copied
// into Library/Sounds once (idempotent) and referenced by name from there.
//
// Fallbacks: no bundled selection (system sound or none), a custom imported
// sound (arbitrary format, can't be guaranteed notification-safe), or any
// missing file → the system default notification sound.
// iOS-only by target membership.

import Foundation
import UserNotifications

enum NotificationSoundProvider {

    /// Filename of the repeated alarm variant for a catalog sound file.
    static func alarmVariantName(forCatalogFilename filename: String) -> String {
        (filename as NSString).deletingPathExtension + " Alarm.caf"
    }

    /// The notification sound for the user's current selection.
    static func currentSound() -> UNNotificationSound {
        guard let idString = UserDefaults.standard.string(forKey: "selectedBundledSoundID"),
              let id = UUID(uuidString: idString),
              let sound = BundledSoundsManager().allSounds.first(where: { $0.id == id })
        else { return .default }

        let variant = alarmVariantName(forCatalogFilename: sound.filename)
        guard let installed = installIntoLibrarySounds(bundleFilename: variant) else {
            debugLog("🔔 Alarm variant missing for \(sound.filename) — default sound")
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(installed))
    }

    /// Locate `bundleFilename` in the app bundle (same locations
    /// BundledSoundsManager probes) and copy it into Library/Sounds.
    /// Idempotent: skips the copy when the destination already exists.
    /// - Returns: the installed filename, or nil when the file can't be found.
    @discardableResult
    static func installIntoLibrarySounds(bundleFilename: String) -> String? {
        guard let source = locateInBundle(bundleFilename) else { return nil }
        let fm = FileManager.default
        guard let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let soundsDir = library.appendingPathComponent("Sounds", isDirectory: true)
        let destination = soundsDir.appendingPathComponent(bundleFilename)
        do {
            try fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: destination.path) {
                try fm.copyItem(at: source, to: destination)
                debugLog("🔔 Installed notification sound: \(bundleFilename)")
            }
            return bundleFilename
        } catch {
            debugLog("❌ Failed installing notification sound \(bundleFilename): \(error)")
            return nil
        }
    }

    private static func locateInBundle(_ filename: String) -> URL? {
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(filename),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds/\(filename)"),
            Bundle.main.resourceURL?.appendingPathComponent("Sounds/\(filename)"),
        ]
        return candidates.compactMap { $0 }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
