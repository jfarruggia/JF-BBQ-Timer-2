import Foundation

/// Builds the spoken timer-completion phrase. Name-first by design —
/// "Ribeye timer is complete" — because "Your timer has completed Ribeye"
/// (the old name-appended form) read backwards. The `{timer}` placeholder
/// lets a custom message position the name explicitly. Both real
/// completions and the Settings "Test Voice Announcement" button build
/// their phrase here, so what you test is what you hear.
enum AnnouncementMessage {
    static let defaultMessage = "timer is complete"

    /// The old shipped default, which produced the name-last phrasing.
    /// Migrated to `defaultMessage` when settings load.
    static let legacyDefaultMessage = "Your timer has completed"

    static func spoken(custom: String, timerName: String) -> String {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(timerName) \(defaultMessage)." }
        if trimmed.contains("{timer}") {
            return trimmed.replacingOccurrences(of: "{timer}", with: timerName)
        }
        return "\(timerName) \(trimmed)"
    }

    /// Maps the legacy default (or blank) stored message onto the new
    /// default; leaves genuinely custom messages untouched.
    static func migratedStoredMessage(_ stored: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == legacyDefaultMessage.lowercased() {
            return defaultMessage
        }
        return stored
    }
}
