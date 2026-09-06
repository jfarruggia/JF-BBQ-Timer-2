// AppVersion.swift
// Grill Time Pro
//
// The app's version string, as shown in Settings ▸ About. The formatting is a
// pure function over the two Info.plist values so it can be unit-tested without
// a bundle; `current` is the thin wrapper that reads the real bundle.

import Foundation

enum AppVersion {
    /// "2.0 (14)" — marketing version with the build number in parentheses.
    /// Either value can be missing from the bundle, so each case is handled
    /// rather than force-unwrapped: a Settings row must never crash the app.
    static func displayString(version: String?, build: String?) -> String {
        switch (version?.trimmedNonEmpty, build?.trimmedNonEmpty) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil):    return version
        case let (nil, build?):      return "(\(build))"
        case (nil, nil):             return "—"
        }
    }

    /// The running app's version, read from the main bundle.
    static var current: String {
        displayString(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }
}

private extension String {
    /// The string with surrounding whitespace removed, or nil if nothing is left.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
