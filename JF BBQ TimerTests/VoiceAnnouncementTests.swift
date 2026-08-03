// VoiceAnnouncementTests.swift
// Grill Time Pro
//
// Swift Testing suite for the announcement voice ranking (pure logic behind
// bestAnnouncementVoice's "pick the best installed voice" default).

import Testing
import Foundation
@testable import JF_BBQ_Timer

@Suite("Voice ranking")
struct VoiceRankingTests {

    // AVSpeechSynthesisVoiceQuality rawValues: default 1, enhanced 2, premium 3

    @Test("quality dominates: premium > enhanced > compact regardless of locale")
    func qualityDominates() {
        let pref = "en-US"
        let premiumGB  = VoiceRanking.score(qualityRaw: 3, language: "en-GB", preferredLanguage: pref)
        let enhancedUS = VoiceRanking.score(qualityRaw: 2, language: "en-US", preferredLanguage: pref)
        let compactUS  = VoiceRanking.score(qualityRaw: 1, language: "en-US", preferredLanguage: pref)
        #expect(premiumGB > enhancedUS)
        #expect(enhancedUS > compactUS)
    }

    @Test("locale match breaks quality ties")
    func localeBreaksTies() {
        let pref = "en-US"
        let enhancedUS = VoiceRanking.score(qualityRaw: 2, language: "en-US", preferredLanguage: pref)
        let enhancedAU = VoiceRanking.score(qualityRaw: 2, language: "en-AU", preferredLanguage: pref)
        #expect(enhancedUS > enhancedAU)
    }

    @Test("quality labels: Enhanced/Premium named, compact unlabeled")
    func qualityLabels() {
        #expect(VoiceRanking.qualityLabel(forRaw: 1) == nil)
        #expect(VoiceRanking.qualityLabel(forRaw: 2) == "Enhanced")
        #expect(VoiceRanking.qualityLabel(forRaw: 3) == "Premium")
        #expect(VoiceRanking.qualityLabel(forRaw: 0) == nil)
    }
}
