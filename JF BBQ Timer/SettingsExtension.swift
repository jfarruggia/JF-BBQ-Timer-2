import Foundation
import AVFoundation

// Extensions to Settings class for custom sounds support
extension Settings {
    // MARK: - Haptic intensity preference
    enum HapticIntensity: Int {
        case light = 0
        case medium = 1
        case strong = 2
    }

    // Persisted haptic intensity (default: .medium)
    var hapticIntensity: HapticIntensity {
        get {
            let raw = UserDefaults.standard.object(forKey: "hapticIntensityLevel") as? Int ?? 1
            return HapticIntensity(rawValue: raw) ?? .medium
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "hapticIntensityLevel")
            UserDefaults.standard.synchronize()
            self.objectWillChange.send()
        }
    }

    // Helper raw value for SwiftUI bindings
    var hapticIntensityRaw: Int {
        get { hapticIntensity.rawValue }
        set { hapticIntensity = HapticIntensity(rawValue: newValue) ?? .medium }
    }
    // Whether to play alert audio even when the Silent (ringer) switch is ON.
    // Default is false (respect Silent Mode). Stored in UserDefaults so it persists.
    var playSoundInSilentMode: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "playSoundInSilentMode")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "playSoundInSilentMode")
            UserDefaults.standard.synchronize()
            // Notify SwiftUI that something observable changed
            self.objectWillChange.send()
        }
    }

    /// Configure the app's audio session for alert playback respecting the user's Silent Mode preference.
    /// - If playSoundInSilentMode is true: use .playback (bypasses Silent switch) and mix with others
    /// - Else: use .ambient (respects Silent switch) so sounds are muted when ringer is OFF
    func configureAudioSessionForAlerts() {
        let session = AVAudioSession.sharedInstance()
        do {
            if playSoundInSilentMode {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            } else {
                try session.setCategory(.ambient, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
            debugLog("🔊 Audio session configured. Bypass Silent: \(playSoundInSilentMode)")
        } catch {
            debugLog("❌ Failed to set audio session: \(error)")
        }
    }
    // The ID of the selected custom sound (if any)
    var selectedCustomSoundID: UUID? {
        get {
            if let uuidString = UserDefaults.standard.string(forKey: "selectedCustomSoundID"),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            return nil
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedCustomSoundID")
                
                // When custom sound is selected, clear bundled sound
                selectedBundledSoundID = nil
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedCustomSoundID")
            }
            // Notify SwiftUI that the object has changed
            self.objectWillChange.send()
        }
    }
    
    // The ID of the selected bundled sound (if any)
    var selectedBundledSoundID: UUID? {
        get {
            if let uuidString = UserDefaults.standard.string(forKey: "selectedBundledSoundID"),
               let uuid = UUID(uuidString: uuidString) {
                return uuid
            }
            return nil
        }
        set {
            // Clear any existing selection
            UserDefaults.standard.removeObject(forKey: "selectedBundledSoundID")
            
            // Set the new selection if provided
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedBundledSoundID")
                // When bundled sound is selected, clear custom sound
                selectedCustomSoundID = nil
            }
            
            // Force UserDefaults to save immediately
            UserDefaults.standard.synchronize()
            
            // Notify SwiftUI that the object has changed
            self.objectWillChange.send()
        }
    }
    
    // Audio player for custom sounds - needs to be a static property in an extension
    public static var sharedAudioPlayer: AVAudioPlayer?
    
    // Load the selected custom sound ID - method is now unnecessary, kept for compatibility
    func loadCustomSoundSelection() {
        // No-op: selectedCustomSoundID is now a computed property that reads directly from UserDefaults
    }
    
    // Save the selected custom sound ID - method is now unnecessary, kept for compatibility 
    func saveCustomSoundSelection() {
        // No-op: selectedCustomSoundID is now a computed property that writes directly to UserDefaults
    }
    
    // Select a custom sound
    func selectCustomSound(id: UUID) {
        self.selectedCustomSoundID = id
        // Do NOT set selectedAlertSound = .system here
    }
    
    // Select a bundled sound
    func selectBundledSound(id: UUID) {
        // If this sound is already selected, deselect it
        if selectedBundledSoundID == id {
            self.selectedBundledSoundID = nil
            // When deselecting bundled sound, set system sound as default
            self.selectedAlertSound = .system
        } else {
            // Select the new bundled sound
            self.selectedBundledSoundID = id
            // Clear any custom sound selection
            self.selectedCustomSoundID = nil
        }
        // Save changes
        UserDefaults.standard.synchronize()
        // Notify SwiftUI that the object has changed
        self.objectWillChange.send()
    }
    
    // Select a system sound (centralized helper)
    func selectSystemSound(_ sound: AlertSound) {
        // Set the system sound and clear any premium/custom selection
        self.selectedAlertSound = sound
        self.selectedBundledSoundID = nil
        self.selectedCustomSoundID = nil
    }
    
    // Deselect custom sound
    func deselectCustomSound() {
        self.selectedCustomSoundID = nil
    }
    
    // Deselect bundled sound
    func deselectBundledSound() {
        self.selectedBundledSoundID = nil
    }
    
    // Check if a custom sound is selected
    var isUsingCustomSound: Bool {
        return selectedCustomSoundID != nil
    }
    
    // Check if a bundled sound is selected
    var isUsingBundledSound: Bool {
        return selectedBundledSoundID != nil
    }
    
    // Play the custom sound if one is selected
    func playCustomSound(loop: Bool = false) -> Bool {
        guard let id = selectedCustomSoundID else {
            return false
        }
        // Look up the sound file
        let soundsManager = CustomSoundsManager()
        guard let sound = soundsManager.getSound(with: id),
              let url = sound.fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            // Fallback to system sound if custom sound not found
            deselectCustomSound()
            return false
        }
        return AudioManager.shared.playCustomSound(from: url, loop: loop)
    }
    
    // Play the bundled sound if one is selected
    func playBundledSound(loop: Bool = false) -> Bool {
        guard let id = selectedBundledSoundID else {
            debugLog("[DEBUG] No bundled sound ID selected.")
            return false
        }
        // The selected sound may have been removed from the catalog by an app
        // update (e.g. the retired novelty sounds). Deselect so the picker
        // shows System honestly, and let the caller fall back — mirrors the
        // missing-file handling in playCustomSound above.
        guard BundledSoundsManager().allSounds.contains(where: { $0.id == id }) else {
            debugLog("[DEBUG] Selected bundled sound no longer exists — deselecting.")
            deselectBundledSound()
            return false
        }
        debugLog("[DEBUG] playBundledSound called with ID: \(id), loop: \(loop)")
        // Use the new AudioManager with looping
        let result = AudioManager.shared.playBundledSound(with: id, loop: loop)
        debugLog("[DEBUG] AudioManager.playBundledSound result: \(result)")
        return result
    }
    
    // Try to play the appropriate sound based on settings, with looping
    func playTimerCompletionSound(loop: Bool = false) {
        // If sound is disabled, don't play anything
        guard soundEnabled else { 
            debugLog("[DEBUG] Sound is disabled in settings.")
            return 
        }
        // Configure audio session according to user's Silent Mode preference
        configureAudioSessionForAlerts()
        debugLog("[DEBUG] playTimerCompletionSound called. loop: \(loop)")
        // First try the custom sound
        if isUsingCustomSound {
            debugLog("[DEBUG] Attempting to play custom sound.")
            let playedCustom = playCustomSound(loop: loop)
            if playedCustom {
                debugLog("[DEBUG] Custom sound played successfully.")
                return
            }
            debugLog("[DEBUG] Custom sound failed, falling back.")
        }
        // Then try bundled sound
        if isUsingBundledSound {
            debugLog("[DEBUG] Attempting to play bundled sound.")
            let playedBundled = playBundledSound(loop: loop)
            if playedBundled {
                debugLog("[DEBUG] Bundled sound played successfully.")
                return
            }
            debugLog("[DEBUG] Bundled sound failed, falling back.")
        }
        // Otherwise play the selected system sound (cannot loop system sounds)
        debugLog("[DEBUG] Playing system sound: \(selectedAlertSound.displayName)")
        AudioServicesPlaySystemSound(selectedAlertSound.systemSoundID)
    }
    
   
}

// Extension for voice announcements
extension Settings {
    // Speech synthesizer for announcements
    static var speechSynthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        // Configure the synthesizer for best results
        // This initialization ensures we have a properly configured instance
        debugLog("Creating shared speech synthesizer")
        return synthesizer
    }()
    
    // Updated to include AirPods and wired headphones detection with caching
    var hasBluetoothHeadphonesConnected: Bool {
        // Use the AVAudioSession to check if headphones are connected
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setActive(true)
            
            // Get current route
            let currentRoute = session.currentRoute
            for output in currentRoute.outputs {
                // Check if output is a Bluetooth device (AirPods, Bluetooth headphones)
                if output.portType == .bluetoothA2DP || 
                   output.portType == .bluetoothHFP || 
                   output.portType == .bluetoothLE ||
                   output.portType == .airPlay {
                    debugLog("Bluetooth audio device connected: \(output.portName)")
                    return true
                }
                
                // Check for wired headphones/earbuds
                if output.portType == .headphones {
                    debugLog("Wired headphones connected: \(output.portName)")
                    return true
                }
            }
            
            debugLog("No headphones detected: \(currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))")
            return false
        } catch let error as NSError {
            debugLog("Error checking audio route: \(error.localizedDescription)")
            if error.code == AVAudioSession.ErrorCode.isBusy.rawValue {
                // If session is busy, there might be another audio app using it
                // Try to check routes without setting session active
                for output in session.currentRoute.outputs {
                    if output.portType == .bluetoothA2DP || 
                       output.portType == .bluetoothHFP || 
                       output.portType == .bluetoothLE ||
                       output.portType == .airPlay ||
                       output.portType == .headphones {
                        return true
                    }
                }
            }
            return false
        }
    }
    
    // Find timer name by ID
    func getTimerName(for timerId: UUID) -> String? {
        // Check legacy timers first
        if timerId == legacyTimersAsBBQTimers[0].id {
            return timer1Name
        } else if timerId == legacyTimersAsBBQTimers[1].id {
            return timer2Name
        }
        
        // Check additional timers
        for timer in additionalTimers {
            if timer.id == timerId {
                return timer.name
            }
        }
        
        return nil
    }
    
    // Announce when timer completes
    func announceTimerCompletion(timerId: UUID) {
        debugLog("Timer completion for timer ID: \(timerId)")

        // Get timer name
        if let timerName = getTimerName(for: timerId) {
            let message = AnnouncementMessage.spoken(custom: customAnnouncementMessage, timerName: timerName)
            directAnnouncement(message: message, settings: self)
        } else {
            debugLog("⚠️ Could not find timer name for ID: \(timerId)")
        }
    }

    // Announce when timer completes (by name)
    func announceTimerCompletion(for name: String) {
        debugLog("Timer completion for: \(name)")
        let message = AnnouncementMessage.spoken(custom: customAnnouncementMessage, timerName: name)
        directAnnouncement(message: message, settings: self)
    }
    
    // Get the selected voice based on the stored identifier
    func selectedVoice() -> AVSpeechSynthesisVoice? {
        // Try to get the voice with the stored identifier
        return AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier)
    }

    /// The voice announcements should actually use: the user's explicit pick,
    /// or — when nothing is picked — the highest-quality English voice on the
    /// device (Premium > Enhanced > compact), preferring the current locale.
    /// iOS defaults to the compact robot voice unless an app asks for better.
    func bestAnnouncementVoice() -> AVSpeechSynthesisVoice? {
        if let chosen = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) {
            return chosen
        }
        let preferred = AVSpeechSynthesisVoice.currentLanguageCode()   // e.g. "en-US"
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        return english.max { a, b in
            VoiceRanking.score(qualityRaw: a.quality.rawValue, language: a.language,
                               preferredLanguage: preferred)
                < VoiceRanking.score(qualityRaw: b.quality.rawValue, language: b.language,
                                     preferredLanguage: preferred)
        } ?? AVSpeechSynthesisVoice(language: nil)
    }
    
    // Get list of available voices for the speech synthesizer
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        // Add safety check to prevent crashes on iPad when voice services are not available
        guard Thread.isMainThread else {
            // If not on main thread, dispatch to main thread
            var result: [AVSpeechSynthesisVoice] = []
            DispatchQueue.main.sync {
                result = self.availableVoices()
            }
            return result
        }
        
        // Get all available voices with safety checks
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // If no voices are available (voice services not ready), return empty array
        guard !allVoices.isEmpty else {
            debugLog("Warning: No speech voices available - voice services may not be ready")
            return []
        }
        
        // Filter to just English voices for simplicity
        let englishVoices = allVoices.filter {
            $0.language.starts(with: "en")
        }

        // Best voices first (Premium > Enhanced > compact), then by name
        return englishVoices.sorted {
            if $0.quality.rawValue != $1.quality.rawValue {
                return $0.quality.rawValue > $1.quality.rawValue
            }
            return $0.name < $1.name
        }
    }
    
    // Manages repeating announcements. Rewritten (2026-08): the old version
    // fired on a fixed 2 s wall timer and created a FRESH synthesizer per
    // repeat — phrases longer than 2 s were cut off mid-word by the next
    // repeat, and per-repeat audio-session re-activation swallowed the first
    // syllables on Bluetooth (the "terrible with AirPods" report). Now: one
    // long-lived synthesizer, session configured once, and the next repeat is
    // scheduled only AFTER the previous utterance finishes, plus a short gap.
    class AnnouncementRepeater: NSObject, AVSpeechSynthesizerDelegate {
        static let shared = AnnouncementRepeater()

        /// Silence between the end of one announcement and the next.
        private static let gapSeconds: TimeInterval = 1.5

        private let synthesizer = AVSpeechSynthesizer()
        private var message: String = ""
        private weak var settings: Settings?
        private var active = false
        private var nextRepeat: DispatchWorkItem?

        override private init() {
            super.init()
            synthesizer.delegate = self
        }

        func startRepeating(message: String, settings: Settings) {
            stopRepeating()
            self.message = message
            self.settings = settings
            active = true
            configureSpeechSession(settings: settings)   // once, not per repeat
            speakOnce()
        }

        func stopRepeating() {
            active = false
            nextRepeat?.cancel()
            nextRepeat = nil
            synthesizer.stopSpeaking(at: .immediate)
        }

        private func speakOnce() {
            guard active, let settings else { return }
            let utterance = AVSpeechUtterance(string: message)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.volume = 1.0
            utterance.voice = settings.bestAnnouncementVoice()
            synthesizer.speak(utterance)
        }

        // Repeat only after the sentence actually finished.
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                               didFinish utterance: AVSpeechUtterance) {
            guard active else { return }
            let task = DispatchWorkItem { [weak self] in self?.speakOnce() }
            nextRepeat = task
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.gapSeconds, execute: task)
        }
    }
    
    // Start repeating announcement
    func startRepeatingAnnouncement(message: String) {
        AnnouncementRepeater.shared.startRepeating(message: message, settings: self)
    }
    
    // Stop repeating announcement
    func stopRepeatingAnnouncement() {
        AnnouncementRepeater.shared.stopRepeating()
    }
    
    // Play sound and make announcement when timer completes
    func playTimerCompletionWithAnnouncement(timerId: UUID) {
        debugLog("===== PLAY TIMER COMPLETION WITH ANNOUNCEMENT =====")
        debugLog("Timer with ID \(timerId) completed")
        // Configure audio session once up front based on the user's preference
        configureAudioSessionForAlerts()
        
        // Check if voice announcements are enabled using class property
        debugLog("Voice announcements enabled: \(voiceAnnouncementsEnabled)")
        
        // Get headphone requirements 
        let requiresHeadphones = announceOnlyWithHeadphones
        let headphonesConnected = hasBluetoothHeadphonesConnected
        debugLog("Headphones required: \(requiresHeadphones), Connected: \(headphonesConnected)")
        
        let shouldAnnounce = voiceAnnouncementsEnabled && (!requiresHeadphones || headphonesConnected)
        let forceAnnouncement = false
        
        // Name-first phrase, shared with the Settings test button.
        func announcementMessage(for timerName: String) -> String {
            AnnouncementMessage.spoken(custom: customAnnouncementMessage, timerName: timerName)
        }
        
        if shouldAnnounce || forceAnnouncement {
            if headphonesConnected {
                debugLog("[LOGIC] Headphones connected: Only playing repeating voice announcement, skipping sound alert.")
                // Only play the repeating announcement
                if let timerName = getTimerName(for: timerId) {
                    let message = announcementMessage(for: timerName)
                    startRepeatingAnnouncement(message: message)
                } else {
                    debugLog("Could not find timer name for ID: \(timerId)")
                }
                debugLog("===== END PLAY TIMER COMPLETION =====")
                return
            } else {
                // Play both sound and announcement (repeating announcement)
                playTimerCompletionSound(loop: true)
                debugLog("[LOGIC] No headphones: Playing both sound and repeating announcement.")
                if let timerName = getTimerName(for: timerId) {
                    let message = announcementMessage(for: timerName)
                    startRepeatingAnnouncement(message: message)
                } else {
                    debugLog("Could not find timer name for ID: \(timerId)")
                }
                debugLog("===== END PLAY TIMER COMPLETION =====")
                return
            }
        } else {
            // Play only the sound
            playTimerCompletionSound(loop: true)
            debugLog("[LOGIC] Announcements not enabled: Playing only sound alert.")
            debugLog("===== END PLAY TIMER COMPLETION =====")
        }
    }
    
    // Stop any looping alert sound and repeating announcement
    func stopLoopingAlertSound() {
        debugLog("[DEBUG] stopLoopingAlertSound() called on Settings instance: \(Unmanaged.passUnretained(self).toOpaque())")
        AudioManager.shared.stopAlertSound()
        stopRepeatingAnnouncement()
    }
}

// Add a delegate class to monitor speech synthesis
class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        debugLog("🎙️ Speech started for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        debugLog("🎙️ Speech finished for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        debugLog("❌ Speech cancelled for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        debugLog("⏸️ Speech paused for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        debugLog("▶️ Speech continued for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        debugLog("🎙️ Speaking range: \(characterRange) of utterance: \(utterance.speechString)")
    }
}

// MARK: - Speech session + voice ranking

/// Configure the shared audio session for spoken announcements, honoring the
/// user's Silent Mode preference. Called once per announcement session — NOT
/// per repeat; re-activation glitches the first syllables on Bluetooth routes.
func configureSpeechSession(settings: Settings) {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        if settings.playSoundInSilentMode {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        } else {
            try audioSession.setCategory(.ambient, mode: .spokenAudio, options: [])
        }
        try audioSession.setActive(true)
        debugLog("✓ Speech session active (bypass Silent: \(settings.playSoundInSilentMode))")
    } catch {
        debugLog("✗ Speech session error: \(error)")
    }
}

/// Pure ranking for picking the best announcement voice — unit-tested.
/// AVSpeechSynthesisVoiceQuality rawValues: default 1, enhanced 2, premium 3.
enum VoiceRanking {
    /// Higher wins. Quality dominates; matching the user's locale breaks ties.
    static func score(qualityRaw: Int, language: String, preferredLanguage: String) -> Int {
        let localeBonus = (language == preferredLanguage) ? 1 : 0
        return qualityRaw * 10 + localeBonus
    }

    /// Suffix for the voice picker, e.g. "Enhanced" / "Premium"; nil for compact.
    static func qualityLabel(forRaw raw: Int) -> String? {
        switch raw {
        case 2:  return "Enhanced"
        case 3:  return "Premium"
        default: return nil
        }
    }
}

// One-shot announcement (used by the Test Speech button). Reuses a persistent
// synthesizer and the same best-voice logic as the repeater.
func directAnnouncement(message: String, settings: Settings) {
    configureSpeechSession(settings: settings)
    let utterance = AVSpeechUtterance(string: message)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    utterance.volume = 1.0
    utterance.voice = settings.bestAnnouncementVoice()
    DirectSpeech.shared.synthesizer.stopSpeaking(at: .immediate)
    DirectSpeech.shared.synthesizer.speak(utterance)
}

// Holds the long-lived one-shot synthesizer (creating a fresh instance per
// utterance risks deallocation mid-speech).
class DirectSpeech {
    static let shared = DirectSpeech()
    let synthesizer = AVSpeechSynthesizer()
}
