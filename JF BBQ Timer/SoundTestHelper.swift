import Foundation
import AVFoundation

/// A utility class to verify sound resources are properly set up
class SoundTestHelper {
    static let shared = SoundTestHelper()
    
    /// Run a full diagnostic on the sound resource setup
    func runDiagnostic() {
        print("\n====== SOUND SYSTEM DIAGNOSTIC ======\n")
        
        // Check for Documents/Resources/Sounds directory
        if let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let soundsDir = documentsDir.appendingPathComponent("Resources/Sounds")
            
            print("Documents Sound Dir: \(soundsDir.path)")
            print("Directory exists: \(FileManager.default.fileExists(atPath: soundsDir.path) ? "✅ YES" : "❌ NO")")
            
            // List files if directory exists
            if FileManager.default.fileExists(atPath: soundsDir.path) {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)
                    let mp3Files = files.filter { $0.pathExtension.lowercased() == "mp3" }
                    let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
                    
                    print("Found \(mp3Files.count) MP3 files:")
                    for file in mp3Files {
                        print("  - \(file.lastPathComponent)")
                        
                        // Try to load audio file
                        do {
                            let _ = try AVAudioPlayer(contentsOf: file)
                            print("    ✅ Audio loads correctly")
                        } catch {
                            print("    ❌ Audio failed to load: \(error)")
                        }
                    }
                    
                    print("\nFound \(jsonFiles.count) JSON files:")
                    for file in jsonFiles {
                        print("  - \(file.lastPathComponent)")
                        
                        // Try to parse JSON
                        do {
                            let data = try Data(contentsOf: file)
                            let _ = try JSONSerialization.jsonObject(with: data)
                            print("    ✅ JSON parses correctly")
                            
                            // Try to parse as BundledSound array
                            do {
                                let sounds = try JSONDecoder().decode([BundledSoundsManager.BundledSound].self, from: data)
                                print("    ✅ Parsed \(sounds.count) sounds from JSON")
                                
                                // Verify each sound file exists
                                for sound in sounds {
                                    let soundPath = soundsDir.appendingPathComponent(sound.filename)
                                    let fileExists = FileManager.default.fileExists(atPath: soundPath.path)
                                    print("    - \(sound.displayName): \(fileExists ? "✅" : "❌")")
                                }
                            } catch {
                                print("    ❌ Failed to parse as BundledSound array: \(error)")
                            }
                        } catch {
                            print("    ❌ JSON failed to parse: \(error)")
                        }
                    }
                } catch {
                    print("Error listing files: \(error)")
                }
            }
        }
        
        // Check for bundle Resources/Sounds directory
        if let bundleDir = Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds") {
            print("\nBundle Sound Dir: \(bundleDir.path)")
            print("Directory exists: \(FileManager.default.fileExists(atPath: bundleDir.path) ? "✅ YES" : "❌ NO")")
            
            // List files if directory exists
            if FileManager.default.fileExists(atPath: bundleDir.path) {
                do {
                    let files = try FileManager.default.contentsOfDirectory(at: bundleDir, includingPropertiesForKeys: nil)
                    print("Found \(files.count) files in bundle")
                    for file in files {
                        print("  - \(file.lastPathComponent)")
                    }
                } catch {
                    print("Error listing bundle files: \(error)")
                }
            }
        }
        
        // Try direct resource loading
        print("\nDirect Resource Loading Test:")
        if let metadataUrl = Bundle.main.url(forResource: "sound_metadata", withExtension: "json") {
            print("✅ Found sound_metadata.json: \(metadataUrl.path)")
            
            // Try to load a sample sound file
            if let airRaidUrl = Bundle.main.url(forResource: "Air Raid Siren", withExtension: "mp3") {
                print("✅ Found Air Raid Siren.mp3: \(airRaidUrl.path)")
                
                // Try to play it
                do {
                    let _ = try AVAudioPlayer(contentsOf: airRaidUrl)
                    print("✅ Audio loads correctly")
                } catch {
                    print("❌ Audio failed to load: \(error)")
                }
            } else {
                print("❌ Could not find Air Raid Siren.mp3 directly")
            }
        } else {
            print("❌ Could not find sound_metadata.json directly")
        }
        
        // Test BundledSoundsManager
        print("\nTesting BundledSoundsManager:")
        let bundledSoundsManager = BundledSoundsManager()
        print("Categories: \(bundledSoundsManager.categories)")
        print("Total sounds: \(bundledSoundsManager.allSounds.count)")
        
        // Try to find a specific sound
        if let testSound = bundledSoundsManager.allSounds.first {
            print("Testing sound: \(testSound.displayName)")
            if let url = testSound.fileURL {
                print("✅ Found URL: \(url.path)")
                
                // Try to load audio
                do {
                    let _ = try AVAudioPlayer(contentsOf: url)
                    print("✅ Audio loads correctly")
                } catch {
                    print("❌ Audio failed to load: \(error)")
                }
            } else {
                print("❌ Could not resolve URL for sound")
            }
        } else {
            print("❌ No sounds found in manager")
        }
        
        print("\n====== DIAGNOSTIC COMPLETE ======\n")
    }
} 