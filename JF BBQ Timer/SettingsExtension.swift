import Foundation
import AVFoundation

// Extensions to Settings class for custom sounds support
extension Settings {
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
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedBundledSoundID")
                
                // When bundled sound is selected, clear custom sound
                selectedCustomSoundID = nil
                
                // Set alert sound to system (disabled) when bundled sound is selected
                self.selectedAlertSound = .system
                UserDefaults.standard.set(selectedAlertSound.rawValue, forKey: "selectedAlertSound")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedBundledSoundID")
            }
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
        // Set alert sound to system when custom sound is selected
        self.selectedAlertSound = .system
        // Save the alert sound change
        UserDefaults.standard.set(selectedAlertSound.rawValue, forKey: "selectedAlertSound")
    }
    
    // Select a bundled sound
    func selectBundledSound(id: UUID) {
        self.selectedBundledSoundID = id
        // Set alert sound to system when bundled sound is selected
        self.selectedAlertSound = .system
        // Save the alert sound change
        UserDefaults.standard.set(selectedAlertSound.rawValue, forKey: "selectedAlertSound")
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
            print("[DEBUG] No bundled sound ID selected.")
            return false
        }
        print("[DEBUG] playBundledSound called with ID: \(id), loop: \(loop)")
        // Use the new AudioManager with looping
        let result = AudioManager.shared.playBundledSound(with: id, loop: loop)
        print("[DEBUG] AudioManager.playBundledSound result: \(result)")
        return result
    }
    
    // Try to play the appropriate sound based on settings, with looping
    func playTimerCompletionSound(loop: Bool = false) {
        // If sound is disabled, don't play anything
        guard soundEnabled else { 
            print("[DEBUG] Sound is disabled in settings.")
            return 
        }
        print("[DEBUG] playTimerCompletionSound called. loop: \(loop)")
        // First try the custom sound
        if isUsingCustomSound {
            print("[DEBUG] Attempting to play custom sound.")
            let playedCustom = playCustomSound(loop: loop)
            if playedCustom {
                print("[DEBUG] Custom sound played successfully.")
                return
            }
            print("[DEBUG] Custom sound failed, falling back.")
        }
        // Then try bundled sound
        if isUsingBundledSound {
            print("[DEBUG] Attempting to play bundled sound.")
            let playedBundled = playBundledSound(loop: loop)
            if playedBundled {
                print("[DEBUG] Bundled sound played successfully.")
                return
            }
            print("[DEBUG] Bundled sound failed, falling back.")
        }
        // Otherwise play the selected system sound (cannot loop system sounds)
        print("[DEBUG] Playing system sound: \(selectedAlertSound.displayName)")
        AudioServicesPlaySystemSound(selectedAlertSound.systemSoundID)
    }
    
    // Stop any looping alert sound
    func stopLoopingAlertSound() {
        print("[DEBUG] stopLoopingAlertSound() called on Settings instance: \(Unmanaged.passUnretained(self).toOpaque())")
        AudioManager.shared.stopAlertSound()
    }
}

// Extension for voice announcements
extension Settings {
    // Speech synthesizer for announcements
    static var speechSynthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        // Configure the synthesizer for best results
        // This initialization ensures we have a properly configured instance
        print("Creating shared speech synthesizer")
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
                    print("Bluetooth audio device connected: \(output.portName)")
                    return true
                }
                
                // Check for wired headphones/earbuds
                if output.portType == .headphones {
                    print("Wired headphones connected: \(output.portName)")
                    return true
                }
            }
            
            print("No headphones detected: \(currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ", "))")
            return false
        } catch let error as NSError {
            print("Error checking audio route: \(error.localizedDescription)")
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
        print("Timer completion for timer ID: \(timerId)")
        
        // Get timer name
        if let timerName = getTimerName(for: timerId) {
            // Create message and use the direct announcement
            let message = "\(timerName) timer is complete."
            directAnnouncement(message: message)
        } else {
            print("⚠️ Could not find timer name for ID: \(timerId)")
        }
    }
    
    // Announce when timer completes (by name)
    func announceTimerCompletion(for name: String) {
        print("Timer completion for: \(name)")
        let message = "\(name) timer is complete."
        directAnnouncement(message: message)
    }
    
    // Get the selected voice based on the stored identifier
    func selectedVoice() -> AVSpeechSynthesisVoice? {
        // Try to get the voice with the stored identifier
        return AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier)
    }
    
    // Get list of available voices for the speech synthesizer
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        // Get all available voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Filter to just English voices for simplicity
        let englishVoices = allVoices.filter { 
            $0.language.starts(with: "en")
        }
        
        return englishVoices.sorted { $0.name < $1.name }
    }
    
    // Play sound and make announcement when timer completes
    func playTimerCompletionWithAnnouncement(timerId: UUID) {
        print("===== PLAY TIMER COMPLETION WITH ANNOUNCEMENT =====")
        print("Timer with ID \(timerId) completed")
        
        // Play the sound (looping)
        playTimerCompletionSound(loop: true)
        
        // Check if voice announcements are enabled using class property
        print("Voice announcements enabled: \(voiceAnnouncementsEnabled)")
        
        // Get headphone requirements 
        let requiresHeadphones = announceOnlyWithHeadphones
        let headphonesConnected = hasBluetoothHeadphonesConnected
        print("Headphones required: \(requiresHeadphones), Connected: \(headphonesConnected)")
        
        // Only make announcement if settings allow it
        let shouldAnnounce = voiceAnnouncementsEnabled && (!requiresHeadphones || headphonesConnected)
        
        // FOR TESTING - Always announce regardless of settings
        let forceAnnouncement = false
        
        if shouldAnnounce || forceAnnouncement {
            print("Making announcement after short delay")
            
            // Small delay to let sound finish playing first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { 
                    print("Self was deallocated before announcement could be made")
                    return 
                }
                
                // Get timer name
                if let timerName = self.getTimerName(for: timerId) {
                    let message = "\(timerName) timer is complete."
                    
                    // Use the new simplified direct announcement
                    directAnnouncement(message: message)
                } else {
                    print("Could not find timer name for ID: \(timerId)")
                }
            }
        } else {
            print("Announcement skipped based on settings")
        }
        
        print("===== END PLAY TIMER COMPLETION =====")
    }
}

// Add a delegate class to monitor speech synthesis
class SpeechSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🎙️ Speech started for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🎙️ Speech finished for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("❌ Speech cancelled for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("⏸️ Speech paused for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("▶️ Speech continued for utterance: \(utterance.speechString)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        print("🎙️ Speaking range: \(characterRange) of utterance: \(utterance.speechString)")
    }
}

// Function for direct announcement
func directAnnouncement(message: String) {
    print("🔊 SUPER SIMPLE DIRECT ANNOUNCEMENT 🔊")
    
    // Configure audio session first - this is critical
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio)
        try audioSession.setActive(true)
        print("✓ Audio session active")
    } catch {
        print("✗ Audio session error: \(error)")
    }
    
    // Create a completely fresh synthesizer instance
    let synthesizer = AVSpeechSynthesizer()
    print("✓ Created synthesizer")
    
    // Setup a basic utterance
    let utterance = AVSpeechUtterance(string: message)
    utterance.rate = 0.5  // Slower
    utterance.volume = 1.0  // Maximum volume
    print("✓ Created utterance: \"\(message)\"")
    
    // Try to get a good English voice
    if let voice = AVSpeechSynthesisVoice(language: "en-US") {
        utterance.voice = voice
        print("✓ Using voice: \(voice.name)")
    }
    
    // Keep a reference to prevent deallocation
    DirectSpeech.shared.synthesizer = synthesizer
    
    // Speak!
    print("▶️ Starting speech...")
    synthesizer.speak(utterance)
}

// Class to hold a reference to the speech synthesizer
class DirectSpeech {
    static let shared = DirectSpeech()
    var synthesizer: AVSpeechSynthesizer?
}
