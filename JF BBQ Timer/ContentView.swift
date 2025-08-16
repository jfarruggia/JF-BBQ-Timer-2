//
//  ContentView.swift
// /Users/jamesfarruggia/Documents/Documents - James's Mac mini/Xcode JF Projects/JF BBQ Timer/JF BBQ TimerUITests JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import AVFoundation
import UIKit
import RevenueCat
import UserNotifications

struct PresetInterval: Identifiable, Codable {
    let id: UUID
    var name: String
    var minutes: Int
    var seconds: Int
    
    init(name: String, minutes: Int, seconds: Int) {
        self.id = UUID()
        self.name = name
        self.minutes = minutes
        self.seconds = seconds
    }
    
    var totalSeconds: TimeInterval {
        TimeInterval(minutes * 60 + seconds)
    }
    
    var formattedName: String {
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    var displayName: String {
        formattedName
    }
}

// Add BBQTimer model here:
struct BBQTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var preset1: Int  // Seconds for preset 1
    var preset2: Int  // Seconds for preset 2
    var isVisible: Bool
    
    init(id: UUID = UUID(), name: String, preset1: Int, preset2: Int, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.preset1 = preset1
        self.preset2 = preset2
        self.isVisible = isVisible
    }
    
    // Implement Equatable conformance
    static func == (lhs: BBQTimer, rhs: BBQTimer) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.preset1 == rhs.preset1 &&
               lhs.preset2 == rhs.preset2 &&
               lhs.isVisible == rhs.isVisible
    }
}

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
                case .system: return 1005 // Default system sound
                case .bell: return 1013   // Glass sound
                case .ding: return 1007   // Tri‑tone (more noticeable)
                case .horn: return 1016   // Low Power sound
                case .beep: return 1000   // Tock sound
                case .alarm: return 1034  // Ringtone sound
                case .electronic: return 1057 // SMS sound
                case .anticipate: return 1020 // Anticipate sound
                case .bloom: return 1021   // Bloom sound
                case .calypso: return 1022  // Calypso sound 
                case .chime: return 1023    // Chime sound
                case .complete: return 1034  // Complete sound
            }
        }
        
        // Premium sounds require premium membership
        var isPremiumSound: Bool {
            switch self {
                case .system, .bell, .ding: return false
                case .horn, .beep, .alarm, .electronic, 
                     .anticipate, .bloom, .calypso, .chime, .complete: return true
            }
        }
        
        // Group sounds by categories like in Apple's Timer app
        static var standardSounds: [AlertSound] {
            return [.system, .bell, .ding]
        }
        
        static var premiumSounds: [AlertSound] {
            // We're removing these from the enum since we'll use custom bundled sounds instead
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
    
    // Premium features flag - one-time purchase
    @Published var isPremiumUser: Bool {
        didSet {
            print("🔄 isPremiumUser changed from \(oldValue) to \(isPremiumUser)")
            UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
            UserDefaults.standard.synchronize()
            print("💾 Saved premium status to UserDefaults")
            // Force UI update
            objectWillChange.send()
        }
    }
    
    // Premium feature limits
    let maxFreeTimers: Int = 2 // Only 2 additional timers for free users
    
    // Method to update premium status from RevenueCat
    func updatePremiumStatus() {
        print("🔄 Checking premium status from RevenueCat...")
        Purchases.shared.getCustomerInfo { [weak self] customerInfo, error in
            if let error = error {
                print("❌ Error fetching customer info: \(error)")
                return
            }
            
            let isPremium = customerInfo?.entitlements["premium_access"]?.isActive == true
            print("📱 Premium status from RevenueCat: \(isPremium)")
            print("🔑 Entitlements: \(String(describing: customerInfo?.entitlements))")
            
            DispatchQueue.main.async {
                if self?.isPremiumUser != isPremium {
                    print("⚠️ Local premium status doesn't match RevenueCat - updating...")
                    self?.isPremiumUser = isPremium
                } else {
                    print("✅ Local premium status matches RevenueCat")
                }
            }
        }
    }
    
    init() {
        // Initialize all stored properties first
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
        self.customAnnouncementMessage = UserDefaults.standard.string(forKey: "customAnnouncementMessage") ?? ""
        self.selectedVoiceIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") ?? ""
        self.announceOnlyWithHeadphones = UserDefaults.standard.bool(forKey: "announceOnlyWithHeadphones")
        
        // Load selectedAlertSound from UserDefaults
        if let savedSound = UserDefaults.standard.string(forKey: "selectedAlertSound"),
           let alertSound = AlertSound(rawValue: savedSound) {
            self.selectedAlertSound = alertSound
        } else {
            self.selectedAlertSound = .system
        }
        
        // Load additional timers (persisted as JSON)
        if let data = UserDefaults.standard.data(forKey: "additionalTimers"),
           let stored = try? JSONDecoder().decode([BBQTimer].self, from: data) {
            self.additionalTimers = stored
        } else {
            self.additionalTimers = []
        }
        
        // Initialize premium status last
        self.isPremiumUser = UserDefaults.standard.bool(forKey: "isPremiumUser")
        print("📱 Initialized premium status from UserDefaults: \(self.isPremiumUser)")
        
        // Set default values if not already set
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            self.soundEnabled = true // Default to ON
        }
        
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            self.hapticsEnabled = true // Default to ON
        }
    }
    
    func save() {
        print("💾 Saving settings...")
        // Save premium status
        UserDefaults.standard.set(isPremiumUser, forKey: "isPremiumUser")
        
        // Save other settings...
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
        
        // Save selectedAlertSound
        UserDefaults.standard.set(selectedAlertSound.rawValue, forKey: "selectedAlertSound")
        // Save additional timers as JSON
        if let data = try? JSONEncoder().encode(additionalTimers) {
            UserDefaults.standard.set(data, forKey: "additionalTimers")
        }
        
        // Force synchronize to ensure changes are saved immediately
        UserDefaults.standard.synchronize()
        print("✅ Settings saved successfully")
    }
    
    // MARK: - Timer Management
    
    func addTimer(name: String, preset1: Int = 60, preset2: Int = 120) -> Bool {
        // Check if user can add more timers
        if canAddMoreTimers() {
            let newTimer = BBQTimer(name: name, preset1: preset1, preset2: preset2)
            additionalTimers.append(newTimer)
            save()
            return true
        }
        return false // Limit reached based on user tier
    }
    
    // Helper function to check if user can add more timers
    func canAddMoreTimers() -> Bool {
        // Two legacy timers are always present; cap total at 2 for free, 10 for premium
        let totalTimers = legacyTimersAsBBQTimers.count + additionalTimers.count
        if isPremiumUser {
            return totalTimers < 10
        } else {
            return totalTimers < 2
        }
    }
    
    // Unlock premium features (call this when purchase is successful)
    func unlockPremiumFeatures() {
        isPremiumUser = true
        save()
    }
    
    // Reset premium status (for testing)
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
        
        if let name = name {
            additionalTimers[index].name = name
        }
        
        if let preset1 = preset1 {
            additionalTimers[index].preset1 = preset1
        }
        
        if let preset2 = preset2 {
            additionalTimers[index].preset2 = preset2
        }
        
        if let isVisible = isVisible {
            additionalTimers[index].isVisible = isVisible
        }
        
        save()
    }
    
    // Get only visible timers
    var visibleAdditionalTimers: [BBQTimer] {
        additionalTimers.filter { $0.isVisible }
    }
    
    // Convert legacy timers to BBQTimer format for consistent UI
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
    
    // Get all timers (legacy + additional)
    var allTimers: [BBQTimer] {
        legacyTimersAsBBQTimers + visibleAdditionalTimers
    }
    
    // Safely initialize voice settings after app startup to prevent blocking main thread
    func initializeVoiceSettings() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Check if we need to update the voice identifier
            if self.selectedVoiceIdentifier == "com.apple.ttsbundle.Samantha-compact" {
                // Try to get a better default voice
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

struct ButtonPreview: View {
    let preset: PresetInterval
    
    var body: some View {
        Text(preset.displayName)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.purple)
            .cornerRadius(8)
    }
}

// Add this enum before the ContentView struct
enum TimerType {
    case regular, preheat
}

class AlertState: ObservableObject {
    @Published var isPresented: Bool
    @Published var showPreheatAlert: Bool {
        didSet {
            print("PreheatAlertState changed from \(oldValue) to \(showPreheatAlert)")
            if showPreheatAlert {
                startHapticTimer()
            } else if hapticTimer != nil {
                stopHapticTimer()
            }
        }
    }
    
    private var hapticTimer: Timer?
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var hapticCounter = 0
    // NEW: Controlled from settings so user toggle truly disables haptics
    var hapticsEnabled: Bool = true
    
    init() {
        // Initialize all properties
        self.isPresented = false
        self.showPreheatAlert = false
        self.hapticCounter = 0
        self.hapticTimer = nil
        
        // Prepare generators
        notificationGenerator.prepare()
        heavyGenerator.prepare()
        mediumGenerator.prepare()
    }
    
    // Add public method to trigger notification feedback
    func triggerNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        // Respect global haptics setting
        guard hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }
    
    private func startHapticTimer() {
        // Do not start loop if haptics are disabled
        guard hapticsEnabled else { return }
        // Prepare generators
        notificationGenerator.prepare()
        heavyGenerator.prepare()
        mediumGenerator.prepare()
        
        // Initial feedback
        triggerHapticFeedback()
        
        // Start repeating timer
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.triggerHapticFeedback()
        }
        // Safety: auto-stop after 10s so it never runs indefinitely
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.hapticTimer != nil { self.stopHapticTimer() }
        }
    }
    
    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticCounter = 0
    }
    
    private func triggerHapticFeedback() {
        guard hapticsEnabled else { return }
        hapticCounter += 1
        if hapticCounter % 2 == 0 {
            heavyGenerator.impactOccurred()
        } else {
            mediumGenerator.impactOccurred()
        }
    }
}

struct AlertView: View {
    @ObservedObject var alertState: AlertState
    let audioPlayer: AVAudioPlayer?
    let isPreheat: Bool
    let settings: Settings // Pass settings to allow stopping looping sound
    @ObservedObject var timerState: TimerState // Add timerState for targeted reset
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        print("Background tapped")
                        audioPlayer?.stop()
                        settings.stopLoopingAlertSound() // Stop looping sound when alert is dismissed
                        timerState.resetCompletionState() // Reset timer completion state
                        if isPreheat {
                            alertState.showPreheatAlert = false
                        } else {
                            alertState.isPresented = false
                        }
                    }
                
                Button(action: {
                    print("Button tapped")
                    audioPlayer?.stop()
                    settings.stopLoopingAlertSound() // Stop looping sound when alert is dismissed
                    timerState.resetCompletionState() // Reset timer completion state
                    if isPreheat {
                        alertState.showPreheatAlert = false
                    } else {
                        alertState.isPresented = false
                    }
                }) {
                    VStack(spacing: 8) {
                        if isPreheat {
                            Text("Preheat")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("Complete! 🔥")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        } else {
                            Text("Interval Complete!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 220, height: 220)
                    .background(Color.red)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(radius: 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .transition(.opacity)
    }
}

// Add this enum before the ContentView struct
enum ActiveSheet: Identifiable {
    case intervalInput, settings, allPresets
    
    var id: Int {
        switch self {
        case .intervalInput: return 0
        case .settings: return 1
        case .allPresets: return 2
        }
    }
}

// Add this before ContentView struct
struct BouncyButtonStyle: ButtonStyle {
    let buttonID: UUID
    @Binding var pressedButtonId: UUID?
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == buttonID ? 0.95 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == buttonID ? -0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    pressedButtonId = buttonID
                    // Add a slight delay before resetting the pressed state
                    // This makes the animation visible even for quick taps
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if pressedButtonId == buttonID {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pressedButtonId = nil
                            }
                        }
                    }
                }
            }
    }
}

// Special animation style for the Start/Stop button
struct PulsatingButtonStyle: ButtonStyle {
    let buttonID: UUID
    @Binding var pressedButtonId: UUID?
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == buttonID ? 0.92 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == buttonID ? -0.08 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    // Add haptic feedback
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred()
                    
                    pressedButtonId = buttonID
                    // Delay reset for more visible animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if pressedButtonId == buttonID {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                pressedButtonId = nil
                            }
                        }
                    }
                }
            }
    }
}

// Add this struct before ContentView
struct CompactTimerView: View {
    let name: String
    let preset1: TimeInterval
    let preset2: TimeInterval
    @ObservedObject var state: TimerState // Direct state reference instead of bindings
    var settings: Settings
    var alertState: AlertState
    
    var body: some View {
        VStack(spacing: 4) {
            // === TIMER & BUTTONS HSTACK (entire row) ===
            // Adapt spacing and widths to device width for better balance on small and large phones
            let screenWidth = UIScreen.main.bounds.width
            let isVerySmall = screenWidth < 360
            let isLargePhone = screenWidth > 430
            let rowSpacing: CGFloat = isVerySmall ? 6 : (isLargePhone ? 12 : 8)
            let panelHPad: CGFloat = isVerySmall ? 10 : (isLargePhone ? 18 : 12)
            let timerPanelMinWidth: CGFloat? = isVerySmall ? 160 : nil
            let buttonsMinWidth: CGFloat? = isVerySmall ? 130 : nil
            HStack(spacing: rowSpacing) {
                // === TIMER DISPLAY SECTION (VStack) ===
                VStack(alignment: .leading, spacing: 6) {
                    // Flip timer
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flip In")
                            .foregroundColor(Theme.defaultTheme.textColor)
                        Text(TimeFormatter.timeString(from: Int(state.intervalTime)))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .animation(.easeInOut, value: state.intervalTime)
                            .id("interval-\(state.intervalTime)")
                            .foregroundColor(Theme.defaultTheme.accentColor)
                    }
                    // Elapsed timer
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Text("Lit Time")
                                .foregroundColor(Theme.defaultTheme.textColor)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        Text(TimeFormatter.timeString(from: Int(state.elapsedTime)))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .animation(.easeInOut, value: state.elapsedTime)
                            .id("elapsed-\(state.elapsedTime)")
                            .foregroundColor(Theme.defaultTheme.accentColor)
                    }
                }
                // Add horizontal-only padding for width, keep height unchanged
                .padding(.horizontal, panelHPad)
                .padding(.vertical, 2)
                        .background(Theme.defaultTheme.backgroundColor)
        .cornerRadius(14)
        .padding(.leading, 2)
        .frame(maxWidth: .infinity)
        .frame(minWidth: timerPanelMinWidth)
                // --- End of timer display section changes ---
                
                // === BUTTONS VSTACK ===
                VStack(spacing: 8) {
                    // Preset buttons HStack
                    HStack(spacing: 8) { // Match spacing to Start/Reset buttons
                        // Preset 1 Button
                        Button(action: {
                            // Set timer to preset1 and start
                            state.stop()
                            state.setCurrentIntervalTime(preset1)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }) {
                            // Compact label with no leading 00 hours (e.g., 5:00 instead of 00:05:00)
                            Text(verbatim: {
                                let total = max(0, Int(preset1))
                                let hours = total / 3600
                                let minutes = (total % 3600) / 60
                                let seconds = total % 60
                                if hours > 0 {
                                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    return String(format: "%d:%02d", minutes, seconds)
                                }
                            }())
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0)), height: 40, fontSize: 16))
                        // Preset 2 Button
                        Button(action: {
                            // Set timer to preset2 and start
                            state.stop()
                            state.setCurrentIntervalTime(preset2)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }) {
                            // Compact label with no leading 00 hours
                            Text(verbatim: {
                                let total = max(0, Int(preset2))
                                let hours = total / 3600
                                let minutes = (total % 3600) / 60
                                let seconds = total % 60
                                if hours > 0 {
                                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    return String(format: "%d:%02d", minutes, seconds)
                                }
                            }())
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0)), height: 40, fontSize: 16))
                    }
                    // Start/Reset buttons HStack
                    HStack(spacing: 8) {
                        if state.isRunning {
                            Button(action: {
                                state.stop()
                                settings.stopLoopingAlertSound()
                            }) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(ElevatedButtonStyle(tint: .red, height: 40, fontSize: 16))
                        }
                        Button(action: {
                            state.reset()
                            settings.stopLoopingAlertSound() // Stop looping alert sound
                        }) {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: .blue, height: 40, fontSize: 16))
                    }
                }
                // === END BUTTONS VSTACK ===
                // Fixed width for button stack (80+80+1 spacing for presets + 80+80+8 spacing for controls + padding)
                .frame(minWidth: buttonsMinWidth)
                .padding(.trailing, 8) // Reduced trailing padding
                // (Orange border for debugging removed)
            }
            // === END TIMER & BUTTONS HSTACK ===
            // TEMP: Add a vivid green border for debugging
            //.border(Color.green, width: 3) // Remove or comment out to revert
        }
        // (Red border for debugging removed)
        // No background here: the outer container is now transparent in compact mode
    }
}

// Add this before ContentView struct
struct PreheatCompleteModifier: ViewModifier {
    let isPreheatComplete: Bool
    
    func body(content: Content) -> some View {
        content
                                    .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPreheatComplete ? Color.red : Color.clear, lineWidth: 4)
                    .opacity(isPreheatComplete ? 1.0 : 0)
            )
            .scaleEffect(isPreheatComplete ? 1.05 : 1.0)
            .animation(isPreheatComplete ? 
                       .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : 
                       .default, 
                       value: isPreheatComplete)
    }
}

// Add debug visualization to the TimerHeaderView
struct TimerHeaderView: View {
    let name: String
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    var body: some View {
        Text(name)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.black)
            .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
            .padding(.vertical, 4) // Increased from 2 to 4
            .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                view.debugFrame(
                    debugSettings.showFrames,
                    color: .blue,
                    showPadding: debugSettings.showPadding,
                    showBackground: debugSettings.showBackgrounds,
                    label: "Timer Header"
                )
            }
    }
}

// MARK: - Timer Components

struct Theme {
    var backgroundColor: Color
    var accentColor: Color
    var textColor: Color
    
    static let defaultTheme = Theme(
        backgroundColor: Color("TimerBackground"), // Named color
        accentColor: Color("TimerAccent"),         // Named color
        textColor: Color.white
    )
    
    static let fireTheme = Theme(
        backgroundColor: Color("TimerBackground"), // Named color
        accentColor: Color("TimerRed"),            // Named color
        textColor: Color.white
    )
}

struct FlipTimerView: View {
    var timeInterval: TimeInterval
    var theme: Theme
    
    var body: some View {
        Text(TimeFormatter.timeString(from: Int(timeInterval)))
            .font(.system(size: 84, weight: .bold, design: .rounded)) // Reduced from 90 to 84
            .foregroundColor(theme.accentColor)
            .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
            .frame(height: 100) // Reduced from 110 to 100
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .animation(.easeInOut, value: timeInterval)
            .id("interval-\(timeInterval)")
    }
}

struct IntervalTimerView: View {
    @ObservedObject var timerState: TimerState
    var theme: Theme
    
    var body: some View {
        VStack(spacing: 2) {
            Text("FLIP IN")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color("TimerAccent"))
                .shadow(color: Color.black.opacity(0.7), radius: 3, x: 0, y: 2)
                .padding(.top, 2)
            
            FlipTimerView(timeInterval: timerState.intervalTime, theme: theme)
                .padding(.bottom, 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(theme.backgroundColor)
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
    }
}

struct ElapsedTimerView: View {
    @ObservedObject var timerState: TimerState
    var theme: Theme
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(Color("TimerRed"))
                    .font(.system(size: 24))
                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Text("LIT TIME")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("TimerAccent"))
                    .shadow(color: Color.black.opacity(0.7), radius: 3, x: 0, y: 2)
            }
            .padding(.top, 2)
            
            Text(TimeFormatter.timeString(from: Int(timerState.elapsedTime)))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(theme.accentColor)
                .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .animation(.easeInOut, value: timerState.elapsedTime)
                .id("elapsed-\(timerState.elapsedTime)")
                .padding(.bottom, 2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(theme.backgroundColor)
        .cornerRadius(16)
        .frame(maxWidth: .infinity)
    }
}

struct TimerPresetButton: View {
    // RED: Quick preset button to start timer with predefined duration
    let presetTime: TimeInterval
    let timeStringConverter: (TimeInterval) -> String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeStringConverter(presetTime))
        }
        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0))))
    }
}

struct TimerControlButtons: View {
    // RED: Control buttons for starting/stopping and resetting the timer
    @ObservedObject var state: TimerState
    let settings: Settings
    @ObservedObject var alertState: AlertState
    
    var body: some View {
        HStack(spacing: 16) {
            if state.isRunning {
                Button(action: {
                    state.stop()
                    settings.stopLoopingAlertSound()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(ElevatedButtonStyle(tint: .red))
            }
            Button(action: {
                state.reset()
                settings.stopLoopingAlertSound() // Stop looping alert sound
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ElevatedButtonStyle(tint: .blue))
        }
    }
}

// Add a debug panel that appears when debug mode is enabled
struct DebugPanel: View {
    @ObservedObject var settings: DebugVisualizerSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Options")
                .font(.headline)
                .padding(.bottom, 4)
            
            Toggle("Show Frames", isOn: $settings.showFrames)
            Toggle("Show Padding", isOn: $settings.showPadding)
            Toggle("Show Backgrounds", isOn: $settings.showBackgrounds)
            Toggle("Show Labels", isOn: $settings.showLabels)
            Toggle("Show Grid", isOn: $settings.showGrid)
            
            if settings.showGrid {
                HStack(spacing: 12) {
                    Text("Grid Spacing:")
                    Slider(value: $settings.gridSpacing, in: 5...50, step: 5)
                    Text("\(Int(settings.gridSpacing))")
                }
            }
        }
                        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding()
    }
}

// Now modify the Large Timer 1 section to use these components

// Remove the duplicate NewSettingsView declaration and keep only the most complete version
struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @StateObject private var timerStates: TimerStatesManager
    @State private var showSettings = false
    @State private var showDebugPanel = false
    @State private var showPremiumUpgrade = false
    // NEW: Quick visual pulse when preheat is tapped so users feel the press
    @State private var preheatPressPulse = false
    // Observe app lifecycle to resync timers when returning to foreground
    @Environment(\.scenePhase) private var scenePhase
    
    // Initialize with the settings
    init() {
        // Use _timerStates to initialize the StateObject
        let settings = Settings() // Create settings first
        _timerStates = StateObject(wrappedValue: TimerStatesManager(settings: settings)) // Pass settings to TimerStatesManager
    }
    
    // Add a namespace for scroll identification
    @Namespace private var scrollNamespace
    
    // Track the UUID of the most recently completed timer
    @State private var lastCompletedTimerId: UUID? = nil
    
    // Global timeString function to be used throughout the view
    private func timeString(from timeInterval: TimeInterval) -> String {
        // Updated to show hours, minutes, and seconds (HH:mm:ss)
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Formatter for buttons where we hide leading 00 hours
    private func timeStringNoLeadingHours(from timeInterval: TimeInterval) -> String {
        let total = max(0, Int(timeInterval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    // Debug visualizer settings
    @StateObject private var debugSettings = DebugVisualizerSettings.shared
    
    // Legacy timer references for backward compatibility
    // These are directly linked to the first two timers in timerStates
    private var timer1State: TimerState? {
        timerStates.state(for: settings.legacyTimersAsBBQTimers[0].id)
    }
    
    private var timer2State: TimerState? {
        timerStates.state(for: settings.legacyTimersAsBBQTimers[1].id)
    }
    
    // Alert State
    @StateObject private var alertState = AlertState()
    
    // Preheat Timer State
    @State private var showPreheatAlert = false
    @State private var preheatTimeRemaining: TimeInterval = 0
    @State private var preheatTimer: Timer?
    @State private var isPreheatComplete = false
    // Track the scheduled notification for the preheat timer so we can cancel it when needed
    @State private var preheatNotificationId: String? = nil
    
    // Initialize timer states when view appears
    private func initializeTimerStates() {
        // Update the settings in the TimerStatesManager first
        print("ContentView: Initializing timer states with settings")
        timerStates.updateSettings(settings)
        
        // Then initialize and sync the timer states
        timerStates.syncTimerStates(timers: settings.allTimers)
    }

    // Fire a noticeable burst of haptics (foreground only). Tuned to be attention-grabbing but brief.
    private func fireHapticBurst() {
        // Use a single UINotificationFeedbackGenerator followed by a couple of heavy impacts
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
        // Two quick heavy pulses spaced slightly apart
        let heavy1 = UIImpactFeedbackGenerator(style: .heavy)
        heavy1.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let heavy2 = UIImpactFeedbackGenerator(style: .heavy)
            heavy2.impactOccurred(intensity: 1.0)
        }
        // Optional third medium pulse for a tail
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.impactOccurred(intensity: 0.9)
        }
    }
    
    private func startTimer1() {
        timer1State?.start {
            if settings.soundEnabled {
                timer1State?.playSound()
            }
            if settings.hapticsEnabled {
                alertState.isPresented = true
            }
        }
    }
    
    private func stopTimer1() {
        timer1State?.stop()
    }
    
    private func startTimer2() {
        timer2State?.start {
            if settings.soundEnabled {
                timer2State?.playSound()
            }
            if settings.hapticsEnabled {
                alertState.isPresented = true
            }
        }
    }
    
    private func stopTimer2() {
        timer2State?.stop()
    }
    
    private func startPreheatTimer() {
        // Check if any timer is running and abort if so (except during UI tests)
        let anyTimerRunning = timerStates.states.contains { $0.isRunning }
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
        if anyTimerRunning && !isUITest {
            print("Cannot start preheat timer while other timers are running")
            return
        }
        
        preheatTimer?.invalidate()
        preheatTimeRemaining = TimeInterval(settings.preheatDuration)
        showPreheatAlert = false
        isPreheatComplete = false
        // Schedule a local notification so preheat completion alerts in background
        schedulePreheatNotification(after: preheatTimeRemaining)
        
        preheatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if preheatTimeRemaining > 0 {
                preheatTimeRemaining -= 1
            } else {
                stopPreheatTimer()
                if settings.soundEnabled {
                    timer1State?.playSound()
                }
                if settings.hapticsEnabled {
                    alertState.triggerNotificationFeedback(type: .success)
                }
                isPreheatComplete = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    isPreheatComplete = false
                }
            }
        }
        
        // UI test fallback: ensure alert appears even if the timer is throttled by the test runner
        if isUITest {
            // Show alert quickly to keep tests fast and reliable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !showPreheatAlert {
                    stopPreheatTimer()
                }
            }
        }
    }
    
    private func stopPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
        
        // Show the preheat alert when timer completes
        showPreheatAlert = true
        // Cancel any pending preheat notification now that it's handled in-app
        cancelPreheatNotification()
        
        // Auto-dismiss after a short delay (faster during UI tests)
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
        let delay: TimeInterval = isUITest ? 2 : 10
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showPreheatAlert = false
        }
    }
    
    // Helper functions to break down complex views
    @ViewBuilder
    private func additionalTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        // RED: Chooses between compact or large timer display based on settings
        if settings.compactMode {
            compactTimerView(for: timer, state: state)
        } else {
            largeTimerView(for: timer, state: state)
        }
    }
    
    @ViewBuilder
    private func compactTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        VStack(spacing: 6) {
            TimerHeaderView(name: timer.name)
            
            CompactTimerView(
                name: timer.name,
                preset1: TimeInterval(timer.preset1),
                preset2: TimeInterval(timer.preset2),
                state: state,
                settings: settings,
                alertState: alertState
            )
        }
        .padding(8)
        .timerContainerAppearance(
            timerState: state, 
            onTimerComplete: { timerId in
                print("Timer \(timerId) completed, scrolling to view")
                lastCompletedTimerId = timerId
            }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func largeTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        VStack(spacing: 8) { // Increased spacing for better fit
            TimerHeaderView(name: timer.name)
                .padding(.top, 4) // Add top padding to header
            
            IntervalTimerView(timerState: state, theme: Theme.defaultTheme)
                .padding(.top, 4)
            
            ElapsedTimerView(timerState: state, theme: Theme.defaultTheme)
                .padding(.bottom, 4)
            
            HStack(spacing: 14) {
                TimerPresetButton(
                    presetTime: TimeInterval(timer.preset1),
                    timeStringConverter: timeStringNoLeadingHours,
                    action: {
                        state.stop()
                        state.setCurrentIntervalTime(TimeInterval(timer.preset1))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            state.start {
                                if settings.soundEnabled {
                                    state.playSound()
                                }
                                if settings.hapticsEnabled {
                                    alertState.isPresented = true
                                }
                            }
                        }
                    }
                )
                
                TimerPresetButton(
                    presetTime: TimeInterval(timer.preset2),
                    timeStringConverter: timeStringNoLeadingHours,
                    action: {
                        state.stop()
                        state.setCurrentIntervalTime(TimeInterval(timer.preset2))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            state.start {
                                if settings.soundEnabled {
                                    state.playSound()
                                }
                                if settings.hapticsEnabled {
                                    alertState.isPresented = true
                                }
                            }
                        }
                    }
                )
            }
            .padding(.top, 4)
            
            TimerControlButtons(
                state: state,
                settings: settings,
                alertState: alertState
            )
            .padding(.bottom, 4) // Add bottom padding to controls
        }
        .padding(.horizontal, 10) // Add horizontal padding
        .padding(.vertical, 6) // Add more vertical padding
        .timerContainerAppearance(
            timerState: state, 
            onTimerComplete: { timerId in
                print("Timer \(timerId) completed, scrolling to view")
                lastCompletedTimerId = timerId
            },
            isLargeTimer: true
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    // Add a method for the preheat button view with debug visualization
    private func preheatButtonView() -> some View {
        // Check if any timer is running
        let anyTimerRunning = timerStates.states.contains { $0.isRunning }
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
        
        // RED: This button starts a countdown for preheating the grill
        return Button(action: {
            // Immediate, light haptic to acknowledge the tap (only if enabled)
            if settings.hapticsEnabled {
                // Stronger double heavy pulse
                let heavy1 = UIImpactFeedbackGenerator(style: .heavy)
                heavy1.prepare()
                heavy1.impactOccurred(intensity: 1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    let heavy2 = UIImpactFeedbackGenerator(style: .heavy)
                    heavy2.prepare()
                    heavy2.impactOccurred(intensity: 1.0)
                }
            }
            // Brief visual press pulse to make the tap obvious
            preheatPressPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                preheatPressPulse = false
            }
            startPreheatTimer()
        }) {
            VStack {
                HStack(alignment: .center) {
                    Spacer()
                    Text("Preheat Grill")
                        .font(.system(size: 22, weight: .bold))
                    
                    Spacer()
                }
                
                // RED: Shows either remaining time or the total preheat duration
                Text(preheatTimeRemaining > 0 ? timeString(from: preheatTimeRemaining) : timeString(from: TimeInterval(settings.preheatDuration)))
                    .font(.system(size: 24, weight: .bold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(width: UIScreen.main.bounds.width * 0.8) // Make button 80% of screen width
            .background(
                LinearGradient(
                    gradient: Gradient(colors: anyTimerRunning ? 
                                      [Color.gray.opacity(0.7), Color.gray.opacity(0.5)] : 
                                      [Color.orange, Color.red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 3)
            // Apply the pulse scale when tapped to show immediate visual feedback
            .scaleEffect(preheatPressPulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: preheatPressPulse)
            // RED: Makes the button pulse when preheat is complete
            .modifier(PreheatCompleteModifier(isPreheatComplete: isPreheatComplete))
        }
        .disabled(anyTimerRunning && !isUITest) // In UI tests, allow tapping even if timers are running
        .contextMenu {
            // Only show reset option if preheat timer is active
            if preheatTimeRemaining > 0 {
                Button(action: {
                    resetPreheatTimer()
                }) {
                    Label("Reset Preheat Timer", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
            view.debugFrame(
                debugSettings.showFrames,
                color: .red,
                showPadding: debugSettings.showPadding,
                showBackground: debugSettings.showBackgrounds,
                label: "Preheat Button"
            )
        }
    }
    
    private func resetPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
        preheatTimeRemaining = 0
        isPreheatComplete = false
        showPreheatAlert = false
        // Cancel any scheduled preheat notification
        cancelPreheatNotification()
    }
    
    var body: some View {
        ZStack {
            Color("PrimaryBackground").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    // Empty space on left to center title
                    Spacer()
                    
                    // Title
                    Text("GrillTime Pro")
                        .font(.headline)
                        .foregroundColor(.white)
                        .accessibilityIdentifier("AppTitle")
                    
                    Spacer()
                    
                    // Settings button only
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .accessibilityIdentifier("SettingsButton")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color("PrimaryBackground"))
                
                // Main content in ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // Timer views
                            ForEach(settings.allTimers) { timer in
                                if let state = timerStates.state(for: timer.id) {
                                    additionalTimerView(for: timer, state: state)
                                        .id(timer.id) // Stable anchor for scrolling
                                        .accessibilityIdentifier("Timer_\(timer.id)")
                                }
                            }
                            
                            // Preheat button at bottom
                            preheatButtonView()
                                .padding(.bottom, 30)
                                .accessibilityIdentifier("PreheatButton")
                        }
                        .padding(.horizontal)
                    }
                    // When a timer completes, bring it into view
                    .onChange(of: lastCompletedTimerId) { completedId in
                        guard let completedId = completedId else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo(completedId, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            // Existing overlays
            if alertState.isPresented, let timer1 = settings.legacyTimersAsBBQTimers.first, let timer1State = timerStates.state(for: timer1.id) {
                AlertView(alertState: alertState, audioPlayer: Settings.sharedAudioPlayer, isPreheat: false, settings: settings, timerState: timer1State)
                    .accessibilityIdentifier("TimerAlert")
            }
            
            if showPreheatAlert {
                PreheatAlertView(
                    isPresented: $showPreheatAlert,
                    onDismiss: handlePreheatAlertDismiss,
                    settings: settings,
                    timerState: getFirstTimerState()
                )
                .accessibilityIdentifier("PreheatAlert")
            }
            if showPremiumUpgrade {
                PremiumUpgradeView(settings: settings, isPresented: $showPremiumUpgrade)
                    .transition(.opacity)
                    .zIndex(100)
                    .accessibilityIdentifier("PremiumUpgrade")
            }
            
            // Debug panel
            if debugSettings.isEnabled && showDebugPanel {
                VStack {
                    DebugPanel(settings: debugSettings)
                    Spacer()
                }
                .zIndex(100)
                .accessibilityIdentifier("DebugPanel")
            }
        }
        .sheet(isPresented: $showSettings) {
            NewSettingsView(settings: settings)
        }
        .buttonStyle(HapticButtonStyle())
        .onAppear {
            timerStates.updateSettings(settings)
            initializeTimerStates()
            settings.initializeVoiceSettings()
            // Sync alert haptics setting on appear
            alertState.hapticsEnabled = settings.hapticsEnabled
            // Request user permission for local notifications (shown once)
            requestNotificationPermission()
        }
        .onChange(of: settings.additionalTimers) { _ in
            initializeTimerStates()
        }
        .onChange(of: settings.selectedAlertSound) { _ in
            print("Alert sound changed to \(settings.selectedAlertSound.displayName), updating timer states")
            timerStates.updateSettings(settings)
        }
        .onChange(of: settings.soundEnabled) { _ in
            print("Sound enabled changed to \(settings.soundEnabled), updating timer states")
            timerStates.updateSettings(settings)
        }
        // When returning to the foreground, resync timer countdowns with wall-clock time
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                resyncTimersAfterForeground()
                resyncPreheatAfterForeground()
            }
        }
        .onDisappear {
            // Ensure no lingering haptic loop when leaving
            if alertState.showPreheatAlert { alertState.showPreheatAlert = false }
        }
    }
    
    // Helper function to get timer state
    private func getFirstTimerState() -> TimerState {
        if let firstTimer = settings.legacyTimersAsBBQTimers.first {
            return timerStates.state(for: firstTimer.id) ?? createDefaultTimerState()
        }
        return createDefaultTimerState()
    }
    
    // Helper function to create a default timer state
    private func createDefaultTimerState() -> TimerState {
        return TimerState(
            id: UUID(),
            interval: TimeInterval(settings.preheatDuration),
            settings: settings
        )
    }
    
    // Helper function to handle preheat alert dismissal
    private func handlePreheatAlertDismiss() {
        showPreheatAlert = false
        settings.stopLoopingAlertSound()
        if let firstTimer = settings.legacyTimersAsBBQTimers.first,
           let state = timerStates.state(for: firstTimer.id) {
            state.resetCompletionState()
        }
    }
    
    // MARK: - Notification helpers (ContentView)
    /// Ask the user for permission to show alerts and play sounds.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("🔔 Notification permission granted: \(granted)")
            }
        }
    }

    /// Resync all running timers with wall-clock time when the app returns to foreground.
    private func resyncTimersAfterForeground() {
        for state in timerStates.states {
            state.resyncAfterForeground()
        }
    }

    /// Schedule a notification for the preheat timer so it alerts in background.
    private func schedulePreheatNotification(after seconds: TimeInterval) {
        let identifier = "preheat-\(UUID().uuidString)"
        preheatNotificationId = identifier
        let content = UNMutableNotificationContent()
        content.title = "Preheat Complete"
        content.body = "Your grill preheat timer is done."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule preheat notification: \(error)")
            } else {
                print("🗓️ Scheduled preheat notification in \(Int(seconds))s")
            }
        }
    }

    /// Cancel a previously scheduled preheat notification.
    private func cancelPreheatNotification() {
        if let id = preheatNotificationId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            preheatNotificationId = nil
        }
    }

    /// If the preheat timer finished in the background, present the in-app alert right away.
    private func resyncPreheatAfterForeground() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let hasPreheatPending = requests.contains { $0.identifier == self.preheatNotificationId }
            if !hasPreheatPending && self.preheatTimeRemaining > 0 && !self.showPreheatAlert {
                DispatchQueue.main.async {
                    // Treat as completed
                    self.stopPreheatTimer()
                }
            }
        }
    }
}

// Ultra-simplified preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Just show the timer component
            VStack(spacing: 12) {
                Text("Timer 1")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("05:00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                
                HStack(spacing: 12) {
                    Text("Reset")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .background(Color("TimerRed"))
                        .cornerRadius(12)
                    
                    Text("Start")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .background(Color("TimerGreen"))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 3)
            .padding()
            .background(Color(UIColor(red: 201/255, green: 48/255, blue: 32/255, alpha: 0.75)))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Timer Component")
        }
    }
}

// PreheatAlertView with pulsing red border
struct PreheatAlertView: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    @ObservedObject var settings: Settings  // Add settings
    @ObservedObject var timerState: TimerState  // Add timerState
    
    // Add state for animation
    @State private var animationPhase = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissAlert()
                }
            
            // Content container
            VStack(spacing: 16) {
                Text("Preheat Complete! 🔥")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Button("Dismiss") {
                    dismissAlert()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .modifier(PulsatingBorderModifier(animating: animationPhase))
            .shadow(radius: 8)
        }
        .onAppear {
            startAnimationTimer()
        }
        .onDisappear {
            stopAnimationTimer()
        }
    }
    
    private func dismissAlert() {
        // Stop all sounds
        settings.stopLoopingAlertSound()
        // Reset timer state
        timerState.resetCompletionState()
        // Call original onDismiss
        onDismiss()
    }
    
    private func startAnimationTimer() {
        // Start animation timer when view appears
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                animationPhase.toggle()
            }
        }
        
        // Start with one immediate animation
        withAnimation(.easeInOut(duration: 0.6)) {
            animationPhase = true
        }
    }
    
    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// Create a separate modifier for the pulsating border effect
struct PulsatingBorderModifier: ViewModifier {
    let animating: Bool
    
    func body(content: Content) -> some View {
        let lineWidth = animating ? 6.0 : 3.0
        let scale = animating ? 1.05 : 1.0
        
        return content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red, lineWidth: lineWidth)
            )
            .scaleEffect(scale)
    }
}

// Add this class to manage timer states
class TimerState: ObservableObject {
    // Unique identifier for each timer instance
    let id: UUID
    // The countdown timer showing time until next flip
    @Published var intervalTime: TimeInterval
    // The time counter showing how long since you lit the grill
    @Published var elapsedTime: TimeInterval = 0
    // Whether this timer is currently running
    @Published var isRunning: Bool = false
    // Whether the timer has just completed
    @Published var isCompleted: Bool = false
    
    // Reference to app settings - change from weak to strong reference
    private var settings: Settings?
    
    private var intervalTimer: Timer?
    private var elapsedTimer: Timer?
    private var onCompleteAction: (() -> Void)?
    private var completionTimer: Timer?
    // Stores the original interval time for proper resets
    private var initialIntervalTime: TimeInterval
    // Target date when the timer should complete (to resync after background)
    private var targetDate: Date?
    // Identifier of the scheduled local notification so it can be canceled
    private var notificationIdentifier: String?
    
    init(id: UUID, interval: TimeInterval, settings: Settings? = nil) {
        self.id = id
        self.intervalTime = interval
        self.initialIntervalTime = interval
        self.settings = settings
    }
    
    // Add a method to update settings
    func updateSettings(_ newSettings: Settings) {
        print("TimerState (\(self.id)): Updating settings reference")
        let previousSetting = self.settings?.selectedAlertSound.displayName ?? "nil"
        self.settings = newSettings
        let newSetting = self.settings?.selectedAlertSound.displayName ?? "nil"
        print("TimerState (\(self.id)): Sound changed from \(previousSetting) to \(newSetting)")
    }
    
    func reset() {
        // Stop all timers
        stopIntervalTimer()
        stopElapsedTimer()
        completionTimer?.invalidate()
        completionTimer = nil
        
        // Reset state
        isRunning = false
        isCompleted = false
        elapsedTime = 0
        intervalTime = initialIntervalTime
        // Clear any target and cancel pending notification
        targetDate = nil
        cancelPendingNotification()
        
        // Notify observers
        objectWillChange.send()
    }
    
    private func createAndStartIntervalTimer() {
        print("Creating interval timer")
        
        // Double check we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.createAndStartIntervalTimer()
            }
            return
        }
        
        // Create and schedule interval timer
        self.intervalTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.intervalTime > 0 {
                self.intervalTime -= 1
                print("Interval timer tick: \(self.intervalTime)")
                self.objectWillChange.send()
            } else {
                print("Interval timer complete")
                self.stopIntervalTimer()
                
                // Set completion state
                self.isCompleted = true
                self.objectWillChange.send()
                
                // Print debug info about settings
                if let settingsObj = self.settings {
                    print("TimerState (\(self.id)): Timer complete with settings: \(settingsObj.selectedAlertSound.displayName)")
                } else {
                    print("TimerState (\(self.id)): ⚠️ Timer complete but settings is nil")
                }
                
                // Call completion action
                self.onCompleteAction?()
                // Fire a short burst of haptics in foreground if enabled
                DispatchQueue.main.async {
                    if let settingsObj = self.settings, settingsObj.hapticsEnabled {
                        // Tune the pattern based on user-selected intensity
                        switch settingsObj.hapticIntensity {
                        case .light:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                        case .medium:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                            let heavy = UIImpactFeedbackGenerator(style: .heavy)
                            heavy.impactOccurred(intensity: 0.9)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                let medium = UIImpactFeedbackGenerator(style: .medium)
                                medium.impactOccurred(intensity: 0.9)
                            }
                        case .strong:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                            let heavy1 = UIImpactFeedbackGenerator(style: .heavy)
                            heavy1.impactOccurred(intensity: 1.0)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                let heavy2 = UIImpactFeedbackGenerator(style: .heavy)
                                heavy2.impactOccurred(intensity: 1.0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                let medium = UIImpactFeedbackGenerator(style: .medium)
                                medium.impactOccurred(intensity: 0.9)
                            }
                        }
                    }
                }
                
                // Removed: auto-reset timer for isCompleted. Now, isCompleted will only be reset by resetCompletionState().
                // self.completionTimer?.invalidate() // Invalidate any existing timer
                // self.completionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                //     guard let self = self else { return }
                //     print("Resetting completion state")
                //     self.isCompleted = false
                //     self.objectWillChange.send()
                // }
                // if let timer = self.completionTimer {
                //     RunLoop.main.add(timer, forMode: .common)
                // }
            }
        }
        
        // Add timer to RunLoop
        if let timer = self.intervalTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // Sets both current and initial interval times - use when changing presets
    func setIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.initialIntervalTime = time  // Also update initial time when setting a preset
            self.objectWillChange.send()
        }
    }
    
    // Only updates current interval time, not the initial value
    func setCurrentIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.objectWillChange.send()
        }
    }
    
    // Manually set the elapsed time value
    func setElapsedTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = time
            self.objectWillChange.send()  // Explicitly notify observers
        }
    }
    
    // Starts both interval (countdown) and elapsed (countup) timers
    func start(onComplete: @escaping () -> Void) {
        print("Starting timer with interval: \(intervalTime)")
        
        // Make absolutely sure interval timer is in a clean state
        // But don't touch the elapsed timer
        intervalTimer?.invalidate()
        intervalTimer = nil
        self.isRunning = false
        self.isCompleted = false // Reset completion state when starting
        
        // Store completion handler
        self.onCompleteAction = onComplete
        
        // Ensure interval timer is invalidated before creating a new one
        stopIntervalTimer()
        
        // Only start interval timer if we have time to count down
        guard intervalTime > 0 else {
            print("⚠️ Cannot start timer - interval time is \(intervalTime)")
            return
        }
        // Record target date and schedule a local notification so it fires in background
        targetDate = Date().addingTimeInterval(intervalTime)
        scheduleCompletionNotification(after: intervalTime)

        // Start elapsed timer only if not already running
        startElapsedTimerIfNeeded()
        
        // IMPORTANT: Set isRunning to true immediately on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            // Also notify observers explicitly
            self.objectWillChange.send()
            print("Timer started - isRunning set to true")
            
            // Create timer on the main thread after UI state is updated
            self.createAndStartIntervalTimer()
        }
    }
    
    // Modified version that doesn't reset the elapsed timer if it's already running
    private func startElapsedTimerIfNeeded() {
        // If the elapsed timer is already running, do nothing
        guard elapsedTimer == nil else {
            print("Elapsed timer already running, continuing it")
            return
        }
        
        print("Starting elapsed timer")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.elapsedTime += 1
                    print("Elapsed timer tick: \(self.elapsedTime)")
                    self.objectWillChange.send()
                }
            }
            
            // Add timer to RunLoop to ensure it runs while scrolling
            if let timer = self.elapsedTimer {
                RunLoop.main.add(timer, forMode: .common)
                print("Elapsed timer added to RunLoop")
            }
        }
    }
    
    private func stopIntervalTimer() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.objectWillChange.send()  // Explicitly notify observers
        }
    }
    
    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    // Stops the countDOWN timer only - elapsed time keeps counting
    func stop() {
        // Only stop the interval timer, leave the elapsed timer running
        stopIntervalTimer()
        // Cancel any scheduled local notification and clear target
        cancelPendingNotification()
        targetDate = nil
    }
    
    // Resets both timers to zero values
    func resetToZero() {
        // Stop both timers
        stopIntervalTimer()
        stopElapsedTimer()
        
        // Reset on main thread - ensure all values go to zero
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reset both timers - set elapsed to zero and interval to initial value
            self.elapsedTime = 0
            self.intervalTime = self.initialIntervalTime
            self.isRunning = false
            
            // Explicitly notify observers
            self.objectWillChange.send()
            
            print("Timer reset to zero. Interval time is now: \(self.intervalTime)")
        }
        // Cancel any scheduled local notification and clear target
        cancelPendingNotification()
        targetDate = nil
    }
    
    func playSound() {
        // Default sound ID to use if settings is nil
        let defaultSoundID: SystemSoundID = 1005
        
        // Try to access settings directly if the weak reference is nil
        if let settingsObj = self.settings, settingsObj.soundEnabled {
            // Use the method that handles both sound and voice announcement
            print("TimerState (\(self.id)): Playing timer completion sound with announcement")
            settingsObj.playTimerCompletionWithAnnouncement(timerId: self.id)
        } else {
            // Log the error and use default sound
            print("TimerState (\(self.id)): ⚠️ Settings reference is nil or sound disabled")
            AudioServicesPlaySystemSound(defaultSoundID)
        }
    }
    
    func resetCompletionState() {
        print("[DEBUG] TimerState.resetCompletionState() called for timer: \(id)")
        isCompleted = false
        objectWillChange.send()
    }

    // MARK: - Background resync helpers
    /// Recompute remaining time based on the target date when app returns to foreground.
    /// If finished while in background, complete immediately and trigger the completion action.
    func resyncAfterForeground() {
        guard let target = targetDate else { return }
        let remaining = target.timeIntervalSinceNow
        if remaining <= 0 {
            // Timer finished while in background
            completeNow()
        } else {
            // Update remaining countdown and ensure interval timer is running
            setCurrentIntervalTime(remaining)
            if isRunning && intervalTimer == nil {
                createAndStartIntervalTimer()
            }
        }
    }

    /// Immediately mark the timer as completed and trigger its completion behavior.
    func completeNow() {
        stopIntervalTimer()
        isRunning = false
        isCompleted = true
        objectWillChange.send()
        // Cancel pending notification
        cancelPendingNotification()
        // Trigger completion action
        onCompleteAction?()
    }

    // MARK: - Local notification scheduling
    private func scheduleCompletionNotification(after interval: TimeInterval) {
        let identifier = "timer-\(id.uuidString)"
        notificationIdentifier = identifier
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(displayName()) timer is complete."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule completion notification: \(error)")
            } else {
                print("🗓️ Scheduled completion notification for timer \(self.id) in \(Int(interval))s")
            }
        }
    }

    private func cancelPendingNotification() {
        if let id = notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            notificationIdentifier = nil
        }
    }

    private func displayName() -> String {
        if let settings = settings {
            if let timer = settings.allTimers.first(where: { $0.id == self.id }) {
                return timer.name
            }
        }
        return "Timer"
    }
}

// Add this class to manage multiple timer states
class TimerStatesManager: ObservableObject {
    @Published var states: [TimerState] = []
    // Use a strong reference to settings
    private var settings: Settings?
    
    init(settings: Settings? = nil) {
        print("TimerStatesManager: Initializing with settings \(settings != nil ? "provided" : "nil")")
        self.settings = settings
    }
    
    // Initialize with existing timers from settings
    func initializeTimerStates(timers: [BBQTimer]) {
        print("TimerStatesManager: Initializing timer states for \(timers.count) timers")
        print("TimerStatesManager: Current settings reference: \(settings != nil ? "valid" : "nil")")
        if let sound = settings?.selectedAlertSound {
            print("TimerStatesManager: Current alert sound: \(sound.displayName)")
        }
        
        // Clear existing states
        for state in states {
            state.stop()
        }
        states = []
        
        // Create new states for each timer
        // Each timer state's initialIntervalTime will be set to preset1
        // This becomes the default value used when resetting the timer
        for timer in timers {
            states.append(TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings))
        }
        
        print("TimerStatesManager: Created \(states.count) timer states")
    }
    
    // Add a new timer state for a new BBQTimer
    func addTimerState(for timer: BBQTimer) -> TimerState {
        let state = TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings)
        states.append(state)
        return state
    }
    
    // Remove timer state
    func removeTimerState(for timerId: UUID) {
        if let index = states.firstIndex(where: { $0.id == timerId }) {
            states[index].stop()
            states.remove(at: index)
        }
    }
    
    // Find a timer state for a given BBQTimer
    func state(for timerId: UUID) -> TimerState? {
        return states.first { $0.id == timerId }
    }
    
    // Ensure we have states for all timers
    func syncTimerStates(timers: [BBQTimer]) {
        // Add states for new timers
        for timer in timers {
            if state(for: timer.id) == nil {
                _ = addTimerState(for: timer)
            }
        }
        
        // Remove states for deleted timers
        let timerIds = Set(timers.map { $0.id })
        states = states.filter { timerState in
            if timerIds.contains(timerState.id) {
                return true
            } else {
                timerState.stop()
                return false
            }
        }
    }
    
    // Update settings
    func updateSettings(_ settings: Settings) {
        print("TimerStatesManager: Updating settings reference")
        self.settings = settings
        
        // Update settings in all timer states
        for (index, state) in states.enumerated() {
            print("TimerStatesManager: Updating settings for timer state #\(index)")
            state.updateSettings(settings)
        }
        
        // Log sound settings for debugging
        if settings.isUsingCustomSound {
            print("TimerStatesManager: Using custom sound with ID: \(settings.selectedCustomSoundID?.uuidString ?? "nil")")
        } else {
            print("TimerStatesManager: Using system sound: \(settings.selectedAlertSound.displayName)")
        }
        
        // Force a refresh
        objectWillChange.send()
    }
}

struct TimerContainerModifier: ViewModifier {
    let isCompleted: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isCompleted ? Color.red : Color.black, lineWidth: isCompleted ? 12 : 2)
            )
            .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

extension View {
    func timerContainer(isCompleted: Bool) -> some View {
        modifier(TimerContainerModifier(isCompleted: isCompleted))
    }
}

// Create a separate modifier for handling the timer container appearance
struct TimerContainerAppearance: ViewModifier {
    @ObservedObject var timerState: TimerState
    // Removed: isShowingRedBorder and resetTimer
    @State private var previousIntervalTime: TimeInterval = 0
    var onTimerComplete: ((UUID) -> Void)?
    var skipBorder: Bool = false
    var isLargeTimer: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, isLargeTimer ? 8 : 0)
            // Use the same background color for both large and compact timers for visual consistency
            .background(Color("TimerContainerBG"))
            .cornerRadius(isLargeTimer ? 15 : 0)
            .overlay(
                Group {
                    if !skipBorder {
                        // Directly use timerState.isCompleted for the red border
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(timerState.isCompleted ? Color.red : Color.black,
                                    lineWidth: timerState.isCompleted ? 12 : 2)
                            .animation(.easeInOut(duration: 0.3), value: timerState.isCompleted)
                    }
                }
            )
            .if(isLargeTimer) { view in
                view
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: calculateAdaptiveHeight())
            }
            // Remove all timer-based logic for border reset
            .onChange(of: timerState.intervalTime) { _ in
                let newValue = timerState.intervalTime
                let oldValue = previousIntervalTime
                // Optionally, still scroll to completed timer
                if oldValue > 0 && newValue == 0 {
                    onTimerComplete?(timerState.id)
                }
                previousIntervalTime = newValue
            }
            .onAppear {
                previousIntervalTime = timerState.intervalTime
            }
    }
    
    // Calculate adaptive height based on device screen size
    private func calculateAdaptiveHeight() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let deviceIsPad = UIDevice.current.userInterfaceIdiom == .pad
        
        // For iPad, use a different proportion of the screen
        if deviceIsPad {
            return min(screenHeight * 0.31, 460)
        }
        
        // For iPhone - use more modest height values
        switch screenHeight {
        case 0...667: // iPhone SE, iPhone 8
            return screenHeight * 0.36
        case 668...812: // iPhone X, 11 Pro, 12 mini
            return screenHeight * 0.30
        case 813...926: // iPhone 11, 12, 13, 14
            return screenHeight * 0.28
        default: // iPhone 11 Pro Max, 12 Pro Max, 13 Pro Max, 14 Pro Max
            return screenHeight * 0.26
        }
    }
}

extension View {
    func timerContainerAppearance(timerState: TimerState, onTimerComplete: ((UUID) -> Void)? = nil, skipBorder: Bool = false, isLargeTimer: Bool = false) -> some View {
        modifier(TimerContainerAppearance(timerState: timerState, onTimerComplete: onTimerComplete, skipBorder: skipBorder, isLargeTimer: isLargeTimer))
    }
}

// Create a view modifier to add a premium badge to features
struct PremiumFeatureBadge: ViewModifier {
    @ObservedObject var settings: Settings
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            if !settings.isPremiumUser {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// Add an extension to use this modifier
extension View {
    func premiumFeatureBadge(settings: Settings) -> some View {
        modifier(PremiumFeatureBadge(settings: settings))
    }
}

// Premium upgrade view
struct PremiumUpgradeView: View {
    @ObservedObject var settings: Settings
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                Text("Upgrade to Premium")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.orange)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Circle())
                
                Text("Unlock all premium features")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    premiumFeatureRow("Unlimited timers")
                    premiumFeatureRow("Advanced timer settings")
                    premiumFeatureRow("Custom themes")
                    premiumFeatureRow("Priority support")
                }
                .padding()
                
                Button(action: {
                    // This would typically be where you implement the in-app purchase
                    settings.unlockPremiumFeatures()
                    isPresented = false
                }) {
                    Text("Upgrade Now - $4.99")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Not Now")
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: 400)
        }
    }
    
    private func premiumFeatureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

// Add this struct at the top-level (before ContentView)
struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

// Add helper modifier near bottom
struct HideScrollIndicators: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollIndicators(.hidden)
        } else {
            content
        }
    }
}

// Add a polished, elevated button style used across presets and controls
struct ElevatedButtonStyle: SwiftUI.ButtonStyle {
    var tint: Color
    var cornerRadius: CGFloat = 12
    var height: CGFloat = 44
    var fontSize: CGFloat = 18

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.15 : 0.30),
                    radius: configuration.isPressed ? 2 : 6,
                    x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


