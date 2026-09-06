import Foundation
import AVFoundation
import RevenueCat

class Settings: ObservableObject {
    // Define sound options
    enum AlertSound: String, CaseIterable, Identifiable, Codable {
        case system = "System Sound"
        case bell = "Bell Sound"
        case ding = "Ding Sound"
        case horn = "Horn Sound"
        case beep = "Beep Sound"
        case alarm = "Alarm Sound"
        case electronic = "Electronic Sound"
        case anticipate = "Anticipate Sound"
        case bloom = "Bloom Sound"
        case calypso = "Calypso Sound"
        case chime = "Chime Sound"
        case complete = "Complete Sound"

        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .ding:
                return "Tri-tone"
            default:
                return self.rawValue
            }
        }

        var systemSoundID: SystemSoundID {
            switch self {
                case .system: return 1005
                case .bell: return 1013
                case .ding: return 1007
                case .horn: return 1016
                case .beep: return 1000
                case .alarm: return 1034
                case .electronic: return 1057
                case .anticipate: return 1020
                case .bloom: return 1021
                case .calypso: return 1022
                case .chime: return 1023
                case .complete: return 1034
            }
        }

        var isPremiumSound: Bool {
            switch self {
                case .system, .bell, .ding: return false
                case .horn, .beep, .alarm, .electronic,
                     .anticipate, .bloom, .calypso, .chime, .complete: return true
            }
        }

        static var standardSounds: [AlertSound] {
            return [.system, .bell, .ding]
        }

        static var premiumSounds: [AlertSound] {
            return []
        }
    }

    // Legacy timer settings for backward compatibility
    @Published var timer1Name: String
    @Published var timer2Name: String
    @Published var timer1Preset1: Int
    @Published var timer1Preset2: Int
    @Published var timer2Preset1: Int
    @Published var timer2Preset2: Int

    // New properties for multi-timer support
    @Published var additionalTimers: [BBQTimer] = []
    /// User-chosen display order for the main screen, as timer UUID strings
    /// (covers the two legacy timers and additional timers alike). Timers not
    /// in the list keep their natural position after the ordered ones; ids of
    /// deleted timers are ignored. Empty = natural order (legacy 1, 2, then
    /// additional), which is what existing users see until they first drag.
    @Published var timerOrderIds: [String] = []

    // Other settings
    @Published var preheatDuration: Int
    @Published var soundEnabled: Bool
    @Published var hapticsEnabled: Bool
    @Published var compactMode: Bool
    @Published var selectedAlertSound: AlertSound

    // Voice announcement settings
    @Published var voiceAnnouncementsEnabled: Bool
    @Published var customAnnouncementMessage: String
    @Published var selectedVoiceIdentifier: String
    @Published var announceOnlyWithHeadphones: Bool

    // Temperature display unit for probe readings. Probe data is always stored
    // in °C; this only changes how temperatures are shown (phone + watch).
    @Published var temperatureUnit: TemperatureUnit {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "temperatureUnit")
        }
    }

    // Which probe readings appear on the timer card's probe strip (core temp
    // always shows). All default ON; toggled in Settings ▸ Temperature Probe.
    @Published var showProbeSurfaceTemp: Bool {
        didSet { UserDefaults.standard.set(showProbeSurfaceTemp, forKey: "showProbeSurfaceTemp") }
    }
    @Published var showProbeAmbientTemp: Bool {
        didSet { UserDefaults.standard.set(showProbeAmbientTemp, forKey: "showProbeAmbientTemp") }
    }
    @Published var showProbePredictedReady: Bool {
        didSet { UserDefaults.standard.set(showProbePredictedReady, forKey: "showProbePredictedReady") }
    }

    /// Probe target temperature per cook, in canonical °C. Keyed by cook id
    /// rather than stored on `BBQTimer` because the two legacy timers are
    /// rebuilt on the fly (there is no stored struct to carry the field).
    /// Drives the probe's prediction set point and the target-crossed alert.
    @Published var probeTargetsByCookID: [UUID: Double] = [:]

    /// User-editable doneness presets shown in the probe target sheet.
    /// Seeded from `ProbeTargetPresets.defaults` when the key has never been
    /// written; an intentionally emptied list stays empty.
    @Published var probeTargetPresets: [ProbeTargetPreset] = []

    // True for Debug builds and TestFlight builds — never the App Store build.
    // The App Store receipt is named "receipt"; a TestFlight receipt is named
    // "sandboxReceipt". Used to expose testing-only affordances (e.g. the premium
    // override below) while keeping them impossible to trigger in production.
    static let isTestBuild: Bool = {
        #if DEBUG
        return true
        #else
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
        #endif
    }()

    // Premium features flag - one-time purchase
    // When debugPremiumOverrideEnabled is true, RevenueCat sync is ignored so
    // isPremiumUser can be set manually for testing. The override only has any
    // effect when isTestBuild is true, so it can never affect the production app.
    @Published var debugPremiumOverrideEnabled: Bool {
        didSet {
            UserDefaults.standard.set(debugPremiumOverrideEnabled, forKey: "debugPremiumOverrideEnabled")
        }
    }

    @Published var isPremiumUser: Bool {
        didSet {
            debugLog("🔄 isPremiumUser changed from \(oldValue) to \(isPremiumUser)")
            UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
            UserDefaults.standard.synchronize()
            debugLog("💾 Saved premium status to UserDefaults")
            objectWillChange.send()
        }
    }

    // Premium feature limits
    let maxFreeTimers: Int = 2

    func updatePremiumStatus() {
        debugLog("🔄 Checking premium status from RevenueCat...")
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            if let error = error {
                debugLog("❌ Error fetching customer info: \(error)")
                return
            }

            let isPremium = customerInfo?.entitlements["premium_access"]?.isActive == true
            debugLog("📱 Premium status from RevenueCat: \(isPremium)")
            debugLog("🔑 Entitlements: \(String(describing: customerInfo?.entitlements))")

            DispatchQueue.main.async {
                if Settings.isTestBuild && self?.debugPremiumOverrideEnabled == true {
                    debugLog("🧪 Premium override active (test build) — ignoring RevenueCat sync")
                    return
                }
                if self?.isPremiumUser != isPremium {
                    debugLog("⚠️ Local premium status doesn't match RevenueCat - updating...")
                    self?.isPremiumUser = isPremium
                } else {
                    debugLog("✅ Local premium status matches RevenueCat")
                }
            }
        }
    }

    init() {
        self.timer1Name = UserDefaults.standard.string(forKey: "timer1Name") ?? "Timer 1"
        self.timer2Name = UserDefaults.standard.string(forKey: "timer2Name") ?? "Timer 2"
        self.timer1Preset1 = UserDefaults.standard.integer(forKey: "timer1Preset1")
        self.timer1Preset2 = UserDefaults.standard.integer(forKey: "timer1Preset2")
        self.timer2Preset1 = UserDefaults.standard.integer(forKey: "timer2Preset1")
        self.timer2Preset2 = UserDefaults.standard.integer(forKey: "timer2Preset2")
        self.preheatDuration = UserDefaults.standard.integer(forKey: "preheatDuration")
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled")
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.voiceAnnouncementsEnabled = UserDefaults.standard.bool(forKey: "voiceAnnouncementsEnabled")
        // Migrates the old "Your timer has completed" default (which was
        // spoken with the timer name awkwardly appended) to the name-first
        // default; custom messages pass through untouched.
        self.customAnnouncementMessage = AnnouncementMessage.migratedStoredMessage(
            UserDefaults.standard.string(forKey: "customAnnouncementMessage") ?? "")
        self.selectedVoiceIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") ?? ""
        self.announceOnlyWithHeadphones = UserDefaults.standard.bool(forKey: "announceOnlyWithHeadphones")
        // Default Fahrenheit (US BBQ audience); a stored choice always wins.
        self.temperatureUnit = TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: "temperatureUnit") ?? "F") ?? .fahrenheit
        // Probe display toggles default ON (bool(forKey:) returns false for
        // missing keys, so treat "never set" as true — same pattern as soundEnabled).
        self.showProbeSurfaceTemp = UserDefaults.standard.object(forKey: "showProbeSurfaceTemp") == nil
            ? true : UserDefaults.standard.bool(forKey: "showProbeSurfaceTemp")
        self.showProbeAmbientTemp = UserDefaults.standard.object(forKey: "showProbeAmbientTemp") == nil
            ? true : UserDefaults.standard.bool(forKey: "showProbeAmbientTemp")
        self.showProbePredictedReady = UserDefaults.standard.object(forKey: "showProbePredictedReady") == nil
            ? true : UserDefaults.standard.bool(forKey: "showProbePredictedReady")

        if let savedSound = UserDefaults.standard.string(forKey: "selectedAlertSound"),
           let alertSound = AlertSound(rawValue: savedSound) {
            self.selectedAlertSound = alertSound
        } else {
            self.selectedAlertSound = .system
        }

        if let data = UserDefaults.standard.data(forKey: "additionalTimers"),
           let stored = try? JSONDecoder().decode([BBQTimer].self, from: data) {
            self.additionalTimers = stored
        } else {
            self.additionalTimers = []
        }

        self.timerOrderIds = UserDefaults.standard.stringArray(forKey: "timerOrderIds") ?? []

        if let data = UserDefaults.standard.data(forKey: "probeTargetsByCookID"),
           let stored = try? JSONDecoder().decode([UUID: Double].self, from: data) {
            self.probeTargetsByCookID = stored
        } else {
            self.probeTargetsByCookID = [:]
        }

        if let data = UserDefaults.standard.data(forKey: "probeTargetPresets"),
           let stored = try? JSONDecoder().decode([ProbeTargetPreset].self, from: data) {
            self.probeTargetPresets = stored
        } else {
            self.probeTargetPresets = ProbeTargetPresets.defaults
        }

        self.isPremiumUser = UserDefaults.standard.bool(forKey: "isPremiumUser")
        self.debugPremiumOverrideEnabled = UserDefaults.standard.bool(forKey: "debugPremiumOverrideEnabled")
        debugLog("📱 Initialized premium status from UserDefaults: \(self.isPremiumUser)")

        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            self.soundEnabled = true
        }

        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            self.hapticsEnabled = true
        }

        // First launch ever: default the alert sound to the free Dinner
        // Triangle instead of the weak system chime. Guarded on the absence of
        // ANY persisted sound choice — existing users have "selectedAlertSound"
        // written by save(), so a deliberate System pick is never overridden.
        if UserDefaults.standard.object(forKey: "selectedAlertSound") == nil,
           UserDefaults.standard.string(forKey: "selectedBundledSoundID") == nil,
           UserDefaults.standard.string(forKey: "selectedCustomSoundID") == nil,
           let triangle = BundledSoundsManager().allSounds
               .first(where: { $0.displayName == "Dinner Triangle" }) {
            UserDefaults.standard.set(triangle.id.uuidString, forKey: "selectedBundledSoundID")
            debugLog("🔔 First launch: defaulting alert sound to Dinner Triangle")
        }
    }

    func save() {
        debugLog("💾 Saving settings...")
        UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
        UserDefaults.standard.set(timer1Name, forKey: "timer1Name")
        UserDefaults.standard.set(timer2Name, forKey: "timer2Name")
        UserDefaults.standard.set(timer1Preset1, forKey: "timer1Preset1")
        UserDefaults.standard.set(timer1Preset2, forKey: "timer1Preset2")
        UserDefaults.standard.set(timer2Preset1, forKey: "timer2Preset1")
        UserDefaults.standard.set(timer2Preset2, forKey: "timer2Preset2")
        UserDefaults.standard.set(preheatDuration, forKey: "preheatDuration")
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
        UserDefaults.standard.set(compactMode, forKey: "compactMode")
        UserDefaults.standard.set(voiceAnnouncementsEnabled, forKey: "voiceAnnouncementsEnabled")
        UserDefaults.standard.set(customAnnouncementMessage, forKey: "customAnnouncementMessage")
        UserDefaults.standard.set(selectedVoiceIdentifier, forKey: "selectedVoiceIdentifier")
        UserDefaults.standard.set(announceOnlyWithHeadphones, forKey: "announceOnlyWithHeadphones")
        UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "temperatureUnit")
        UserDefaults.standard.set(showProbeSurfaceTemp, forKey: "showProbeSurfaceTemp")
        UserDefaults.standard.set(showProbeAmbientTemp, forKey: "showProbeAmbientTemp")
        UserDefaults.standard.set(showProbePredictedReady, forKey: "showProbePredictedReady")
        UserDefaults.standard.set(selectedAlertSound.rawValue, forKey: "selectedAlertSound")
        if let data = try? JSONEncoder().encode(additionalTimers) {
            UserDefaults.standard.set(data, forKey: "additionalTimers")
        }
        UserDefaults.standard.set(timerOrderIds, forKey: "timerOrderIds")
        if let data = try? JSONEncoder().encode(probeTargetsByCookID) {
            UserDefaults.standard.set(data, forKey: "probeTargetsByCookID")
        }
        if let data = try? JSONEncoder().encode(probeTargetPresets) {
            UserDefaults.standard.set(data, forKey: "probeTargetPresets")
        }
        UserDefaults.standard.synchronize()
        debugLog("✅ Settings saved successfully")
    }

    // MARK: - Timer Management

    func addTimer(name: String, preset1: Int = 60, preset2: Int = 120) -> Bool {
        if canAddMoreTimers() {
            let newTimer = BBQTimer(name: name, preset1: preset1, preset2: preset2)
            additionalTimers.append(newTimer)
            save()
            return true
        }
        return false
    }

    func canAddMoreTimers() -> Bool {
        let totalTimers = legacyTimersAsBBQTimers.count + additionalTimers.count
        if isPremiumUser {
            return totalTimers < 10
        } else {
            return totalTimers < 2
        }
    }

    func unlockPremiumFeatures() {
        isPremiumUser = true
        save()
    }

    func resetPremiumStatus() {
        isPremiumUser = false
        save()
    }

    func removeTimer(at index: Int) {
        guard index >= 0 && index < additionalTimers.count else { return }
        additionalTimers.remove(at: index)
        save()
    }

    func updateTimer(at index: Int, name: String? = nil, preset1: Int? = nil, preset2: Int? = nil, isVisible: Bool? = nil) {
        guard index >= 0 && index < additionalTimers.count else { return }
        if let name = name { additionalTimers[index].name = name }
        if let preset1 = preset1 { additionalTimers[index].preset1 = preset1 }
        if let preset2 = preset2 { additionalTimers[index].preset2 = preset2 }
        if let isVisible = isVisible { additionalTimers[index].isVisible = isVisible }
        save()
    }

    /// Rename whichever timer owns `id` — the two legacy timers or an
    /// additional timer. No-op for unknown ids, empty names, or a same-name
    /// rename (avoids a pointless save/sync cycle).
    func renameTimer(id: UUID, to newName: String) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let legacy = legacyTimersAsBBQTimers
        if id == legacy[0].id {
            guard timer1Name != name else { return }
            timer1Name = name
            save()
        } else if id == legacy[1].id {
            guard timer2Name != name else { return }
            timer2Name = name
            save()
        } else if let index = additionalTimers.firstIndex(where: { $0.id == id }),
                  additionalTimers[index].name != name {
            updateTimer(at: index, name: name)
        }
    }

    // MARK: - Probe target temperature

    /// The probe target for a cook (°C), or nil when none is set.
    func probeTarget(forCookID id: UUID) -> Double? {
        probeTargetsByCookID[id]
    }

    /// Set (or clear, with nil) the probe target for a cook and persist.
    func setProbeTarget(_ celsius: Double?, forCookID id: UUID) {
        if probeTargetsByCookID[id] == celsius { return }
        probeTargetsByCookID[id] = celsius
        save()
    }

    // MARK: - Probe target presets (user-editable doneness list)

    /// Append a preset (validated + capped) and persist. Returns false when
    /// rejected (invalid or at the cap) so the UI can react.
    @discardableResult
    func addProbeTargetPreset(_ preset: ProbeTargetPreset) -> Bool {
        guard ProbeTargetPresets.isValid(preset),
              probeTargetPresets.count < ProbeTargetPresets.maxCount else { return false }
        probeTargetPresets.append(preset)
        save()
        return true
    }

    /// Update the preset with a matching id (validated) and persist.
    @discardableResult
    func updateProbeTargetPreset(_ preset: ProbeTargetPreset) -> Bool {
        guard ProbeTargetPresets.isValid(preset),
              let index = probeTargetPresets.firstIndex(where: { $0.id == preset.id })
        else { return false }
        probeTargetPresets[index] = preset
        save()
        return true
    }

    /// Remove presets at the given offsets (List swipe-to-delete) and persist.
    /// (Manual descending removal — this file doesn't import SwiftUI, which is
    /// where Array.remove(atOffsets:) lives.)
    func removeProbeTargetPresets(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where probeTargetPresets.indices.contains(index) {
            probeTargetPresets.remove(at: index)
        }
        save()
    }

    /// Replace the list with the standard defaults and persist.
    func restoreDefaultProbeTargetPresets() {
        probeTargetPresets = ProbeTargetPresets.defaults
        save()
    }

    var visibleAdditionalTimers: [BBQTimer] {
        additionalTimers.filter { $0.isVisible }
    }

    var legacyTimersAsBBQTimers: [BBQTimer] {
        [
            BBQTimer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                    name: timer1Name,
                    preset1: timer1Preset1,
                    preset2: timer1Preset2),
            BBQTimer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                    name: timer2Name,
                    preset1: timer2Preset1,
                    preset2: timer2Preset2)
        ]
    }

    var allTimers: [BBQTimer] {
        TimerOrdering.apply(order: timerOrderIds,
                            to: legacyTimersAsBBQTimers + visibleAdditionalTimers)
    }

    /// Persist a full new display order (main-screen drag-to-reorder).
    func setTimerOrder(_ ids: [UUID]) {
        timerOrderIds = ids.map(\.uuidString)
        save()
    }

    func initializeVoiceSettings() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if self.selectedVoiceIdentifier == "com.apple.ttsbundle.Samantha-compact" {
                if let defaultVoice = AVSpeechSynthesisVoice(language: "en-US") {
                    DispatchQueue.main.async {
                        self.selectedVoiceIdentifier = defaultVoice.identifier
                        self.save()
                    }
                }
            }
        }
    }
}

// MARK: - Timer display ordering

/// Pure ordering logic for the main-screen timer list (unit-tested).
enum TimerOrdering {
    /// Reorders `timers` to match `order` (UUID strings). Ids in `order` that
    /// don't match a timer are ignored (e.g. deleted timers); timers missing
    /// from `order` keep their relative order and follow the ordered ones
    /// (e.g. newly added timers). An empty `order` returns `timers` unchanged.
    static func apply(order: [String], to timers: [BBQTimer]) -> [BBQTimer] {
        guard !order.isEmpty else { return timers }
        var remaining = timers
        var ordered: [BBQTimer] = []
        for id in order {
            if let index = remaining.firstIndex(where: { $0.id.uuidString == id }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        return ordered + remaining
    }
}
