// AppVersionTests.swift
// Grill Time Pro
//
// Swift Testing suite for AppVersion.displayString — the Settings ▸ About
// version row. Covers the missing/blank Info.plist cases, which is the whole
// reason the formatting is a pure function rather than string interpolation
// at the call site.

import Testing
@testable import JF_BBQ_Timer

struct AppVersionTests {
    @Test func versionAndBuildAreCombined() {
        #expect(AppVersion.displayString(version: "2.0", build: "14") == "2.0 (14)")
    }

    @Test func missingBuildShowsVersionAlone() {
        #expect(AppVersion.displayString(version: "2.0", build: nil) == "2.0")
    }

    @Test func missingVersionShowsBuildAlone() {
        #expect(AppVersion.displayString(version: nil, build: "14") == "(14)")
    }

    @Test func bothMissingShowsPlaceholder() {
        #expect(AppVersion.displayString(version: nil, build: nil) == "—")
    }

    @Test func blankValuesAreTreatedAsMissing() {
        #expect(AppVersion.displayString(version: "   ", build: "\n") == "—")
        #expect(AppVersion.displayString(version: "2.0", build: "  ") == "2.0")
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect(AppVersion.displayString(version: " 2.0 ", build: " 14 ") == "2.0 (14)")
    }

    @Test func realBundleValuesAreReadable() {
        #expect(!AppVersion.current.isEmpty)
    }
}
