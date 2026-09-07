// WatchPremiumGateTests.swift
// Grill Time Pro
//
// Swift Testing suite for WatchPremiumGate — the phone-side snapshot wrapper,
// the watch-side decode, and the wrist-command backstop
// (watch-premium-gate-spec.md).

import Testing
@testable import JF_BBQ_Timer

struct WatchPremiumGateTests {
    private let rows: [[String: Any]] = [
        ["id": "a", "name": "Ribeye", "remaining": 300, "state": "running"],
        ["id": "b", "name": "Corn", "remaining": 60, "state": "stopped"],
    ]

    // MARK: Phone side — snapshot(rows:premium:)

    @Test func premiumSnapshotCarriesRowsAndFlag() {
        let snapshot = WatchPremiumGate.snapshot(rows: rows, premium: true)
        #expect((snapshot["timers"] as? [[String: Any]])?.count == 2)
        #expect(snapshot["premium"] as? Bool == true)
    }

    @Test func premiumSnapshotLeavesRowsUntouched() {
        let snapshot = WatchPremiumGate.snapshot(rows: rows, premium: true)
        let sent = snapshot["timers"] as? [[String: Any]]
        #expect(sent?.first?["name"] as? String == "Ribeye")
        #expect(sent?.last?["remaining"] as? Int == 60)
    }

    @Test func lockedSnapshotHasNoTimersRegardlessOfRows() {
        let snapshot = WatchPremiumGate.snapshot(rows: rows, premium: false)
        #expect((snapshot["timers"] as? [[String: Any]])?.isEmpty == true)
        #expect(snapshot["premium"] as? Bool == false)
    }

    // MARK: Watch side — isUnlocked(_:)

    @Test func flagTrueDecodesUnlocked() {
        #expect(WatchPremiumGate.isUnlocked(["timers": [], "premium": true]) == true)
    }

    @Test func flagFalseDecodesLocked() {
        #expect(WatchPremiumGate.isUnlocked(["timers": [], "premium": false]) == false)
    }

    @Test func missingFlagFailsOpen() {
        #expect(WatchPremiumGate.isUnlocked(["timers": []]) == true)
    }

    @Test func malformedFlagFailsOpen() {
        #expect(WatchPremiumGate.isUnlocked(["premium": "yes"]) == true)
        #expect(WatchPremiumGate.isUnlocked(["premium": 0]) == true)
    }

    @Test func roundTripPreservesAccess() {
        for premium in [true, false] {
            let snapshot = WatchPremiumGate.snapshot(rows: rows, premium: premium)
            #expect(WatchPremiumGate.isUnlocked(snapshot) == premium)
        }
    }

    // MARK: Phone side backstop — allowsWristCommand(_:premium:)

    @Test func premiumPhoneHonoursEveryCommand() {
        for action in ["requestSnapshot", "applyPreset1", "applyPreset2", "toggleRun", "ackAlert", "anythingElse"] {
            #expect(WatchPremiumGate.allowsWristCommand(action, premium: true) == true)
        }
    }

    @Test func lockedPhoneOnlyAnswersSnapshotRequests() {
        #expect(WatchPremiumGate.allowsWristCommand("requestSnapshot", premium: false) == true)
        for action in ["applyPreset1", "applyPreset2", "toggleRun", "ackAlert", "anythingElse"] {
            #expect(WatchPremiumGate.allowsWristCommand(action, premium: false) == false)
        }
    }
}
