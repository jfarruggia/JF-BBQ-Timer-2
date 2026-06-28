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

// Add a class to handle app delegate functionality
class AppDelegate: NSObject, UIApplicationDelegate {
    // Single source of truth for allowed orientations. Returned from
    // supportedInterfaceOrientationsFor below to lock the app to portrait —
    // the App Store-safe approach (no private UIDevice key-value hack).
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
        
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

// MARK: - ProbeForwarderHolder
// Retains the ProbeWatchForwarder for the app's lifetime.
// A plain class (not ObservableObject) is enough — we only need stable storage,
// not published-change observation.
#if os(iOS)
private final class ProbeForwarderHolder: ObservableObject {
    var forwarder: ProbeWatchForwarder?
}
#endif

@main
struct JF_BBQ_TimerApp: App {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    // App delegate. Orientation is locked to portrait via the delegate's
    // supportedInterfaceOrientationsFor + the Info.plist orientation settings.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = Settings()
    #if os(iOS)
    /// App-wide probe BLE manager — single instance shared across all screens via the environment.
    @StateObject private var probeManager = ProbeBLEManager()
    /// Retains the ProbeWatchForwarder for the full app lifetime (not just while Settings is open).
    @StateObject private var probeForwarderHolder = ProbeForwarderHolder()
    #endif

    // Initialize app-wide services
    init() {
        // Activate WatchConnectivity session manager and log in debug builds
        WCSessionManager.shared.activate()
        #if DEBUG
        debugLog("WCSession (iOS) activated")
        #endif
    }

    // RevenueCat entitlement check
    private func updatePremiumStatus() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let error = error {
                debugLog("❌ Error fetching customer info: \(error)")
                return
            }
            
            let isPremium = customerInfo?.entitlements["premium_access"]?.isActive == true
            debugLog("📱 Premium status: \(isPremium)")
            debugLog("🔑 Entitlements: \(String(describing: customerInfo?.entitlements))")
            
            DispatchQueue.main.async {
                if Settings.isDevBuild && settings.debugPremiumOverrideEnabled {
                    debugLog("🧪 Premium override active (dev build) — ignoring RevenueCat sync")
                    return
                }
                // Only persist the premium flag here to avoid overwriting
                // onboarding defaults (timer names/presets) with zeros from
                // the initial Settings() instance.
                settings.isPremiumUser = isPremium
                UserDefaults.standard.set(isPremium, forKey: "isPremiumUser")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    ContentView()
                        .environmentObject(settings)
                        #if os(iOS)
                        .environmentObject(probeManager)
                        #endif
                } else {
                    OnboardingFlowView()
                        .environmentObject(settings)
                        #if os(iOS)
                        .environmentObject(probeManager)
                        #endif
                }
            }
            .onAppear {
                updatePremiumStatus()
                // If the app launches and the user has already onboarded,
                // hydrate settings from persisted values so nothing shows as 0.
                if hasOnboarded { hydrateSettingsFromDefaults() }
                // Apply any UI test launch arguments (premium, generate timers)
                applyUITestArguments()
                // Note: Watch sync is handled by ContentView's startWatchSyncTimer(),
                // which builds and sends the real timer snapshot.
                #if os(iOS)
                // Create the app-level probe watch forwarder once. Forwarding runs
                // for the app's lifetime so probe readings reach the watch regardless
                // of which screen is currently visible.
                if probeForwarderHolder.forwarder == nil {
                    probeForwarderHolder.forwarder = ProbeWatchForwarder(bleManager: probeManager)
                }
                #endif
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
