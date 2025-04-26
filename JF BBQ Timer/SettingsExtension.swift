import Foundation
import AVFoundation

// Extensions to Settings class for custom sounds support
extension Settings {
    // The ID of the selected custom sound (if any)
    var selectedCustomSoundID: UUID? {
        get {
            do {
                if let uuidString = UserDefaults.standard.string(forKey: "selectedCustomSoundID"),
                   let uuid = UUID(uuidString: uuidString) {
                    return uuid
                }
                return nil
            } catch {
                print("Error retrieving custom sound ID: \(error)")
                return nil
            }
        }
        set {
            do {
                if let id = newValue {
                    UserDefaults.standard.set(id.uuidString, forKey: "selectedCustomSoundID")
                } else {
                    UserDefaults.standard.removeObject(forKey: "selectedCustomSoundID")
                }
            } catch {
                print("Error saving custom sound ID: \(error)")
            }
        }
    }
    
    // Audio player for custom sounds - needs to be a static property in an extension
    private static var sharedAudioPlayer: AVAudioPlayer?
    
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
    
    // Deselect custom sound
    func deselectCustomSound() {
        self.selectedCustomSoundID = nil
    }
    
    // Check if a custom sound is selected
    var isUsingCustomSound: Bool {
        do {
            return selectedCustomSoundID != nil
        } catch {
            print("Error checking custom sound: \(error)")
            return false
        }
    }
    
    // Play the custom sound if one is selected
    func playCustomSound() -> Bool {
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
        
        do {
            Settings.sharedAudioPlayer = try AVAudioPlayer(contentsOf: url)
            Settings.sharedAudioPlayer?.prepareToPlay()
            Settings.sharedAudioPlayer?.play()
            return true
        } catch {
            print("Error playing custom sound: \(error)")
            return false
        }
    }
    
    // Try to play the appropriate sound based on settings
    func playTimerCompletionSound() {
        // If sound is disabled, don't play anything
        guard soundEnabled else { return }
        
        // First try the custom sound
        if isUsingCustomSound {
            let playedCustom = playCustomSound()
            if playedCustom {
                return
            }
            // If custom sound fails, fall back to system sound
        }
        
        // Otherwise play the selected system sound
        AudioServicesPlaySystemSound(selectedAlertSound.systemSoundID)
    }
}
