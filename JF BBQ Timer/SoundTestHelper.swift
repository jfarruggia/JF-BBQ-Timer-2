import Foundation
import AVFoundation

/// A utility class to verify sound resources are properly set up
class SoundTestHelper {
    static let shared = SoundTestHelper()
    
    /// Run a full diagnostic on the sound resource setup
    func runDiagnostic() {
        debugLog("\n====== SOUND SYSTEM DIAGNOSTIC ======\n")
        
        // Check for Documents/Resources/Sounds directory
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let soundsDir = documentsDir.appendingPathComponent("Resources/Sounds")
            
            debugLog("Documents Sound Dir: \(soundsDir.path)")
            debugLog("Directory exists: \(FileManager.default.fileExists(atPath: soundsDir.path) ? "✅ YES" : "❌ NO")")
            
            // List files if directory exists
            if FileManager.default.fileExists(atPath: soundsDir.path) {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)
                    let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
                    let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
                    
                    debugLog("Found \(mp3Files.count) MP3 files:")
                    for file in mp3Files {
                        debugLog("  - \(file.lastPathComponent)")
                        
                        // Try to load audio file
                        do {
                            let _ = try AVAudioPlayer(contentsOf: file)
                            debugLog("    ✅ Audio loads correctly")
                        } catch {
                            debugLog("    ❌ Audio failed to load: \(error)")
                        }
                    }
                    
                    debugLog("\nFound \(jsonFiles.count) JSON files:")
                    for file in jsonFiles {
                        debugLog("  - \(file.lastPathComponent)")
                        
                        // Try to parse JSON
                        do {
                            let data = try Data(contentsOf: file)
                            let _ = try JSONSerialization.jsonObject(with: data)
                            debugLog("    ✅ JSON parses correctly")
                            
                            // Try to parse as BundledSound array
                            do {
                                let sounds = try JSONDecoder().decode([BundledSoundsManager.BundledSound].self, from: data)
                                debugLog("    ✅ Parsed \(sounds.count) sounds from JSON")
                                
                                // Verify each sound file exists
                                for sound in sounds {
                                    let soundPath = soundsDir.appendingPathComponent(sound.filename)
                                    let fileExists = FileManager.default.fileExists(atPath: soundPath.path)
                                    debugLog("    - \(sound.displayName): \(fileExists ? "✅" : "❌")")
                                }
                            } catch {
                                debugLog("    ❌ Failed to parse as BundledSound array: \(error)")
                            }
                        } catch {
                            debugLog("    ❌ JSON failed to parse: \(error)")
                        }
                    }
                } catch {
                    debugLog("Error listing files: \(error)")
                }
            }
        }
        
        // Check for bundle Resources/Sounds directory
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds") {
            debugLog("\nBundle Sound Dir: \(bundleDir.path)")
            debugLog("Directory exists: \(FileManager.default.fileExists(atPath: bundleDir.path) ? "✅ YES" : "❌ NO")")
            
            // List files if directory exists
            if FileManager.default.fileExists(atPath: bundleDir.path) {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: bundleDir, includingPropertiesForKeys: nil)
                    debugLog("Found \(files.count) files in bundle")
                    for file in files {
                        debugLog("  - \(file.lastPathComponent)")
                    }
                } catch {
                    debugLog("Error listing bundle files: \(error)")
                }
            }
        }
        
        // Try direct resource loading
        debugLog("\nDirect Resource Loading Test:")
        if let metadataUrl = Bundle.main.url(forResource: "sound_metadata", withExtension: "json") {
            debugLog("✅ Found sound_metadata.json: \(metadataUrl.path)")
            
            // Try to load a sample sound file
            if let airRaidUrl = Bundle.main.url(forResource: "Air Raid Siren", withExtension: "mp3") {
                debugLog("✅ Found Air Raid Siren.mp3: \(airRaidUrl.path)")
                
                // Try to play it
                do {
                    let _ = try AVAudioPlayer(contentsOf: airRaidUrl)
                    debugLog("✅ Audio loads correctly")
                } catch {
                    debugLog("❌ Audio failed to load: \(error)")
                }
            } else {
                debugLog("❌ Could not find Air Raid Siren.mp3 directly")
            }
        } else {
            debugLog("❌ Could not find sound_metadata.json directly")
        }
        
        // Test BundledSoundsManager
        debugLog("\nTesting BundledSoundsManager:")
        let bundledSoundsManager = BundledSoundsManager()
        debugLog("Categories: \(bundledSoundsManager.categories)")
        debugLog("Total sounds: \(bundledSoundsManager.allSounds.count)")
        
        // Try to find a specific sound
        if let testSound = bundledSoundsManager.allSounds.first {
            debugLog("Testing sound: \(testSound.displayName)")
            if let url = testSound.fileURL {
                debugLog("✅ Found URL: \(url.path)")
                
                // Try to load audio
                do {
                    let _ = try AVAudioPlayer(contentsOf: url)
                    debugLog("✅ Audio loads correctly")
                } catch {
                    debugLog("❌ Audio failed to load: \(error)")
                }
            } else {
                debugLog("❌ Could not resolve URL for sound")
            }
        } else {
            debugLog("❌ No sounds found in manager")
        }
        
        debugLog("\n====== DIAGNOSTIC COMPLETE ======\n")
    }
} 