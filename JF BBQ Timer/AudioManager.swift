import Foundation
import AVFoundation

/// A class to handle all audio playback in the app
class AudioManager {
    /// Shared instance for singleton access
    static let shared = AudioManager()
    
    /// Audio player for playing alert sounds
    private var audioPlayer: AVAudioPlayer?
    
    /// Audio session for configuring system audio behavior
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Store system sound completion handlers by sound ID
    private var systemSoundCompletions: [SystemSoundID: () -> Void] = [:]
    
    /// Initialize the audio manager
    init() {
        print("[DEBUG] AudioManager.init called. Singleton instance: \(Unmanaged.passUnretained(self).toOpaque())")
        configureAudioSession()
    }
    
    /// Configure the audio session for optimal playback
    func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    /// Play a sound from a URL, with optional looping
    /// - Parameters:
    ///   - url: The URL of the sound file to play
    ///   - loop: Whether to loop the sound indefinitely
    ///   - completion: Optional completion handler called when playback finishes
    /// - Returns: Whether the sound was successfully played
    @discardableResult
    func playSound(from url: URL, loop: Bool = false, completion: (() -> Void)? = nil) -> Bool {
        print("🎵 Playing sound from: \(url.path), loop: \(loop)")
        // Stop any existing playback
        stopSound()
        // Make sure audio session is active
        do {
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
        } catch {
            print("❌ Error activating audio session: \(error)")
        }
        // Create and play the audio
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AudioPlayerDelegate.shared
            audioPlayer?.numberOfLoops = loop ? -1 : 0
            if let completion = completion {
                AudioPlayerDelegate.shared.completionHandler = completion
            }
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("✅ Started playing sound")
            return true
        } catch {
            print("❌ Error playing sound: \(error)")
            return false
        }
    }
    
    /// Play a bundled sound by ID, with optional looping
    /// - Parameters:
    ///   - soundId: The UUID of the bundled sound to play
    ///   - loop: Whether to loop the sound indefinitely
    ///   - completion: Optional completion handler called when playback finishes
    /// - Returns: Whether the sound was successfully played
    @discardableResult
    func playBundledSound(with soundId: UUID, loop: Bool = false, completion: (() -> Void)? = nil) -> Bool {
        let manager = BundledSoundsManager()
        guard let sound = manager.getSound(with: soundId),
              let url = sound.fileURL else {
            print("❌ Failed to find bundled sound with ID: \(soundId)")
            return false
        }
        print("🎵 Playing bundled sound: \(sound.displayName), loop: \(loop)")
        return playSound(from: url, loop: loop, completion: completion)
    }
    
    /// Play a custom sound by URL, with optional looping
    @discardableResult
    func playCustomSound(from url: URL, loop: Bool = false, completion: (() -> Void)? = nil) -> Bool {
        return playSound(from: url, loop: loop, completion: completion)
    }
    
    /// Play a system sound
    /// - Parameters:
    ///   - soundID: The system sound ID to play
    ///   - completion: Optional completion handler called when playback finishes
    func playSystemSound(_ soundID: SystemSoundID, completion: (() -> Void)? = nil) {
        print("🎵 Playing system sound: \(soundID)")
        
        // Stop any existing custom sound
        stopSound()
        
        // For iOS 9 and later, we can use AudioServicesPlaySystemSoundWithCompletion
        if #available(iOS 9.0, *) {
            AudioServicesPlaySystemSoundWithCompletion(soundID) {
                completion?()
            }
        } else {
            // Fallback for older iOS versions
            AudioServicesPlaySystemSound(soundID)
            
            // Approximate the completion callback with a delay
            if let completion = completion {
                // Most system sounds are short (less than 3 seconds)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    completion()
                }
            }
        }
    }
    
    /// Stop the currently playing sound
    func stopSound() {
        if let player = audioPlayer, player.isPlaying {
            print("⏹️ Stopping audio playback")
            player.stop()
        }
        audioPlayer = nil
    }
    
    /// Stop the currently playing alert sound (public for use by UI)
    func stopAlertSound() {
        print("[DEBUG] AudioManager.stopAlertSound() called. audioPlayer: \(audioPlayer != nil ? "exists" : "nil")")
        audioPlayer?.stop()
        audioPlayer = nil
        // Forcefully deactivate audio session to ensure all playback stops
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("[DEBUG] Audio session deactivated after stopping alert sound.")
        } catch {
            print("[DEBUG] Error deactivating audio session: \(error)")
        }
    }
}

/// Delegate to handle audio player events
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    /// Shared instance for singleton access
    static let shared = AudioPlayerDelegate()
    
    /// Completion handler to call when playback finishes
    var completionHandler: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 Audio player finished playing, success: \(flag)")
        
        if let completion = completionHandler {
            completion()
            completionHandler = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Audio player decode error: \(error?.localizedDescription ?? "unknown")")
        
        if let completion = completionHandler {
            completion()
            completionHandler = nil
        }
    }
} 
