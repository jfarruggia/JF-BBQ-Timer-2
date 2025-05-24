//
//  JF_BBQ_TimerApp.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import UIKit

// This class will handle the orientation lock
class OrientationLock: ObservableObject {
    init() {
        // Lock the orientation to portrait on launch
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        AppDelegate.orientationLock = .portrait
    }
}

// Add a class to handle app delegate functionality
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register default values for UserDefaults
        let defaults: [String: Any] = [
            "soundEnabled": true,
            "hapticsEnabled": true
        ]
        UserDefaults.standard.register(defaults: defaults)
        
        // Set up sound resources if needed
        setupSoundResources()
        
        // Run sound diagnostic on a slight delay (after UI is loaded)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            SoundTestHelper.shared.runDiagnostic()
        }
        
        return true
    }
    
    // Copy sound resources to Documents directory for easier access
    private func setupSoundResources() {
        print("=== Setting up sound resources ===")
        
        // Get the Documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Documents directory")
            return
        }
        
        print("📁 Documents directory: \(documentsDirectory.path)")
        
        // Create a Resources/Sounds directory inside documents if it doesn't exist
        let soundsDirectory = documentsDirectory.appendingPathComponent("Resources/Sounds")
        
        do {
            // Create the directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: soundsDirectory.path) {
                try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
                print("✅ Created directory: \(soundsDirectory.path)")
            } else {
                print("ℹ️ Directory already exists: \(soundsDirectory.path)")
            }
            
            // List of potential source directories to check
            let potentialSourceDirs = [
                Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds"),
                Bundle.main.resourceURL?.appendingPathComponent("Sounds"),
                Bundle.main.bundleURL.appendingPathComponent("Resources/Sounds"),
                Bundle.main.bundleURL.appendingPathComponent("Sounds")
            ].compactMap { $0 }
            
            print("🔍 Checking \(potentialSourceDirs.count) potential source directories")
            
            var foundSourceDir = false
            
            for (index, sourceDir) in potentialSourceDirs.enumerated() {
                print("📂 Checking source directory \(index + 1): \(sourceDir.path)")
                
                if FileManager.default.fileExists(atPath: sourceDir.path) {
                    print("✅ Source directory exists")
                    
                    do {
                        let files = try FileManager.default.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
                        let soundFiles = files.filter { $0.pathExtension.lowercased() == "mp3" }
                        
                        if soundFiles.isEmpty {
                            print("ℹ️ No MP3 files found in directory")
                            continue
                        }
                        
                        print("🎵 Found \(soundFiles.count) sound files:")
                        
                        // Copy each sound file to the Documents directory
                        for fileURL in soundFiles {
                            print("  - \(fileURL.lastPathComponent)")
                            let destURL = soundsDirectory.appendingPathComponent(fileURL.lastPathComponent)
                            
                            if !FileManager.default.fileExists(atPath: destURL.path) {
                                try FileManager.default.copyItem(at: fileURL, to: destURL)
                                print("  ✅ Copied to Documents")
                            } else {
                                print("  ℹ️ Already exists in Documents")
                            }
                        }
                        
                        // Also look for metadata file
                        let metadataSource = sourceDir.appendingPathComponent("sound_metadata.json")
                        let metadataDest = soundsDirectory.appendingPathComponent("sound_metadata.json")
                        
                        if FileManager.default.fileExists(atPath: metadataSource.path) {
                            print("📄 Found metadata file")
                            
                            if !FileManager.default.fileExists(atPath: metadataDest.path) {
                                try FileManager.default.copyItem(at: metadataSource, to: metadataDest)
                                print("✅ Copied metadata to Documents")
                            } else {
                                print("ℹ️ Metadata already exists in Documents")
                            }
                        } else {
                            print("❓ No metadata file found at: \(metadataSource.path)")
                        }
                        
                        foundSourceDir = true
                        break
                    } catch {
                        print("❌ Error copying files: \(error)")
                    }
                } else {
                    print("❌ Source directory does not exist")
                }
            }
            
            if !foundSourceDir {
                print("⚠️ Could not find any sound source directory in the bundle")
                
                // Try direct resource loading as a fallback
                print("🔍 Attempting direct resource loading fallback...")
                
                if let soundMetadata = Bundle.main.url(forResource: "sound_metadata", withExtension: "json") {
                    print("✅ Found sound_metadata.json directly in bundle: \(soundMetadata.path)")
                    
                    let destMetadata = soundsDirectory.appendingPathComponent("sound_metadata.json")
                    if !FileManager.default.fileExists(atPath: destMetadata.path) {
                        try FileManager.default.copyItem(at: soundMetadata, to: destMetadata)
                        print("✅ Copied metadata file to Documents")
                    }
                    
                    // Look for sound files directly in bundle
                    let soundsFromJSON = try Data(contentsOf: soundMetadata)
                    if let soundsArray = try? JSONSerialization.jsonObject(with: soundsFromJSON) as? [[String: Any]] {
                        print("✅ Parsed \(soundsArray.count) sounds from JSON")
                        
                        for sound in soundsArray {
                            if let filename = sound["filename"] as? String,
                               let fileURL = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), 
                                                             withExtension: "mp3") {
                                print("✅ Found sound file directly in bundle: \(filename)")
                                
                                let destURL = soundsDirectory.appendingPathComponent(filename)
                                if !FileManager.default.fileExists(atPath: destURL.path) {
                                    try FileManager.default.copyItem(at: fileURL, to: destURL)
                                    print("✅ Copied \(filename) to Documents")
                                }
                            }
                        }
                    }
                } else {
                    print("❌ Could not find sound_metadata.json directly in bundle")
                }
            }
            
            // Verify the results
            do {
                let files = try FileManager.default.contentsOfDirectory(at: soundsDirectory, includingPropertiesForKeys: nil)
                let soundFiles = files.filter { $0.pathExtension.lowercased() == "mp3" }
                let hasMetadata = files.contains { $0.lastPathComponent == "sound_metadata.json" }
                
                print("=== Final Results ===")
                print("📂 \(soundFiles.count) sound files in Documents/Resources/Sounds")
                print("📄 Metadata file in Documents: \(hasMetadata ? "Yes" : "No")")
            } catch {
                print("❌ Error verifying results: \(error)")
            }
        } catch {
            print("❌ Error setting up sound resources: \(error)")
        }
        
        print("=== Sound resources setup complete ===")
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

@main
struct JF_BBQ_TimerApp: App {
    // Add the app delegate and orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var orientationLock = OrientationLock()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light) // Force light mode for consistent appearance
        }
    }
}
