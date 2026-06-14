//
//  JF_BBQ_TimerApp.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import UIKit
import RevenueCat
import WatchConnectivity

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
        // Configure RevenueCat
        // Use verbose logs in Debug builds, and lighter logs in Release for cleaner production consoles
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: "appl_sAvUVfGNwMiLQcFzVhzsEJBNixy")
        
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
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    // Add the app delegate and orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var orientationLock = OrientationLock()
    @StateObject private var settings = Settings()

    // Initialize app-wide services
    init() {
        // Activate WatchConnectivity session manager and log in debug builds
        WCSessionManager.shared.activate()
        // Ensure TimerCenter is initialized so it can receive watch commands
        _ = TimerCenter.shared
        #if DEBUG
        print("WCSession (iOS) activated")
        #endif
    }

    // RevenueCat entitlement check
    private func updatePremiumStatus() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                print("❌ Error fetching customer info: \(error)")
                return
            }
            
            let isPremium = customerInfo?.entitlements["premium_access"]?.isActive == true
            print("📱 Premium status: \(isPremium)")
            print("🔑 Entitlements: \(String(describing: customerInfo?.entitlements))")
            
            DispatchQueue.main.async {
                // Only persist the premium flag here to avoid overwriting
                // onboarding defaults (timer names/presets) with zeros from
                // the initial Settings() instance.
                settings.isPremiumUser = isPremium
                UserDefaults.standard.set(isPremium, forKey: "isPremiumUser")
                UserDefaults.standard.synchronize()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    ContentView()
                        .environmentObject(settings)
                } else {
                    OnboardingFlowView()
                        .environmentObject(settings)
                }
            }
            .onAppear {
                updatePremiumStatus()
                // If the app launches and the user has already onboarded,
                // hydrate settings from persisted values so nothing shows as 0.
                if hasOnboarded { hydrateSettingsFromDefaults() }
                // Apply any UI test launch arguments (premium, generate timers)
                applyUITestArguments()
                // Note: Watch sync is handled by ContentView's startWatchSyncTimer()
                // which sends proper timer data. TimerCenter.publishTimersToWatch()
                // was removed because it sent empty snapshots.
            }
            .onChange(of: hasOnboarded) { didOnboard in
                if didOnboard {
                    // When onboarding flips to true, copy the values the user set
                    // into the shared settings object used by the main UI.
                    hydrateSettingsFromDefaults()
                    // Re-apply test args after onboarding if present
                    applyUITestArguments()
                }
            }
        }
    }

    private func hydrateSettingsFromDefaults() {
        let defaults = UserDefaults.standard
        settings.timer1Name = defaults.string(forKey: "timer1Name") ?? "Timer 1"
        settings.timer2Name = defaults.string(forKey: "timer2Name") ?? "Timer 2"
        settings.timer1Preset1 = defaults.integer(forKey: "timer1Preset1").nonZeroOr(300)
        settings.timer1Preset2 = defaults.integer(forKey: "timer1Preset2").nonZeroOr(60)
        settings.timer2Preset1 = defaults.integer(forKey: "timer2Preset1").nonZeroOr(300)
        settings.timer2Preset2 = defaults.integer(forKey: "timer2Preset2").nonZeroOr(60)
        settings.preheatDuration = defaults.integer(forKey: "preheatDuration").nonZeroOr(600)
    }

    // Configure app for UI performance tests
    private func applyUITestArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-UITEST_MODE") || args.contains("-UITEST_GENERATE_TIMERS") || args.contains("-UITEST_PREMIUM") || args.contains("-UITEST_PREHEAT_SECONDS") || args.contains("-UITEST_SKIP_ONBOARDING") else { return }
        // Force premium if requested
        if args.contains("-UITEST_PREMIUM") {
            settings.isPremiumUser = true
            UserDefaults.standard.set(true, forKey: "isPremiumUser")
        }
        // Skip onboarding if requested
        if args.contains("-UITEST_SKIP_ONBOARDING") {
            hasOnboarded = true
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            hydrateSettingsFromDefaults()
        }
        // Desired total timers (including the 2 legacy timers)
        var desiredTotal: Int? = nil
        if let idx = args.firstIndex(of: "-UITEST_GENERATE_TIMERS"), idx + 1 < args.count, let n = Int(args[idx + 1]) {
            desiredTotal = max(0, min(n, 10)) // Cap at 10 overall
        }
        if let total = desiredTotal {
            // Make sure additionalTimers matches desired count (total includes 2 legacy timers)
            let desiredAdditional = max(0, total - 2)
            // Reset additional timers for a clean test run
            settings.additionalTimers.removeAll()
            // Create the requested number of additional timers
            for i in 1...desiredAdditional {
                _ = settings.addTimer(name: "Stress \(i)", preset1: 300, preset2: 60)
            }
            settings.save()
        }
        // Optional: override preheat duration to a short test value
        if let idx = args.firstIndex(of: "-UITEST_PREHEAT_SECONDS"), idx + 1 < args.count, let s = Int(args[idx + 1]) {
            settings.preheatDuration = max(1, min(3600, s))
            settings.save()
        }
    }
}

// Small helper to keep defaults if integers are zero/missing
private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
