//
//  ContentView.swift
// /Users/jamesfarruggia/Documents/Documents - James's Mac mini/Xcode JF Projects/JF BBQ Timer/JF BBQ TimerUITests JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import AVFoundation
import UIKit

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
        
        // Set default values if not previously set
        if timer1Preset1 == 0 {
            timer1Preset1 = 60 // 1 minute
        }
        if timer1Preset2 == 0 {
            timer1Preset2 = 120 // 2 minutes
        }
        if timer2Preset1 == 0 {
            timer2Preset1 = 180 // 3 minutes
        }
        if timer2Preset2 == 0 {
            timer2Preset2 = 240 // 4 minutes
        }
        if preheatDuration == 0 {
            preheatDuration = 900 // 15 minutes
        }
        
        // Load additional timers
        if let savedTimersData = UserDefaults.standard.data(forKey: "additionalTimers") {
            if let decodedTimers = try? JSONDecoder().decode([BBQTimer].self, from: savedTimersData) {
                self.additionalTimers = decodedTimers
            }
        }
    }
    
    func save() {
        // Save legacy timer settings
        UserDefaults.standard.set(timer1Name, forKey: "timer1Name")
        UserDefaults.standard.set(timer2Name, forKey: "timer2Name")
        UserDefaults.standard.set(timer1Preset1, forKey: "timer1Preset1")
        UserDefaults.standard.set(timer1Preset2, forKey: "timer1Preset2")
        UserDefaults.standard.set(timer2Preset1, forKey: "timer2Preset1")
        UserDefaults.standard.set(timer2Preset2, forKey: "timer2Preset2")
        
        // Save other settings
        UserDefaults.standard.set(preheatDuration, forKey: "preheatDuration")
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
        UserDefaults.standard.set(compactMode, forKey: "compactMode")
        
        // Save additional timers
        if let encodedData = try? JSONEncoder().encode(additionalTimers) {
            UserDefaults.standard.set(encodedData, forKey: "additionalTimers")
        }
    }
    
    // MARK: - Timer Management
    
    func addTimer(name: String, preset1: Int = 60, preset2: Int = 120) {
        let newTimer = BBQTimer(name: name, preset1: preset1, preset2: preset2)
        additionalTimers.append(newTimer)
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
    @Published var isPresented: Bool = false {
        didSet {
            print("AlertState changed from \(oldValue) to \(isPresented)")
            if isPresented {
                startHapticTimer()
            } else if hapticTimer != nil {
                stopHapticTimer()
            }
        }
    }
    
    @Published var showPreheatAlert: Bool = false {
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
        notificationGenerator.notificationOccurred(type)
    }
    
    private func startHapticTimer() {
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
    }
    
    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticCounter = 0
    }
    
    private func triggerHapticFeedback() {
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        print("Background tapped")
                        audioPlayer?.stop()
                        if isPreheat {
                            alertState.showPreheatAlert = false
                        } else {
                            alertState.isPresented = false
                        }
                    }
                
                Button(action: {
                    print("Button tapped")
                    audioPlayer?.stop()
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
    let id: UUID
    @Binding var pressedButtonId: UUID?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == id ? 0.95 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == id ? -0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    pressedButtonId = id
                    // Add a slight delay before resetting the pressed state
                    // This makes the animation visible even for quick taps
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if pressedButtonId == id {
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
    let id: UUID
    @Binding var pressedButtonId: UUID?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == id ? 0.92 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == id ? -0.08 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    // Add haptic feedback
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred()
                    
                    pressedButtonId = id
                    // Delay reset for more visible animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if pressedButtonId == id {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0.3)) {
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
    @Binding var intervalTime: TimeInterval
    @Binding var elapsedTime: TimeInterval
    @Binding var isRunning: Bool
    let onStartStop: () -> Void
    let onReset: () -> Void
    let onPreset1Tap: () -> Void
    let onPreset2Tap: () -> Void
    
    // For button animations
    @State private var pressedButtonId: UUID?
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header with timer name
            HStack {
                Text(name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 10)
            
            // Main timer display and controls in a horizontal layout
            HStack(alignment: .top, spacing: 10) {
                // Left side: timer displays
                VStack(alignment: .leading, spacing: 6) {
                    // Interval timer
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Next Flip:")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                        Text(timeString(from: intervalTime))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                    }
                    
                    // Elapsed timer
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Time Elapsed:")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.purple)
                        Text(timeString(from: elapsedTime))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                }
                .frame(width: 140)
                
                Spacer()
                
                // Right side: buttons in a vertical layout
                VStack(spacing: 8) {
                    // Preset buttons in a row
                    HStack(spacing: 8) {
                        // Preset 1 button
                        Button(action: onPreset1Tap) {
                            Text(timeString(from: preset1))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(height: 40)
                                .frame(minWidth: 70)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                        
                        // Preset 2 button
                        Button(action: onPreset2Tap) {
                            Text(timeString(from: preset2))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(height: 40)
                                .frame(minWidth: 70)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(10)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                    }
                    
                    // Control buttons in a row
                    HStack(spacing: 8) {
                        // Reset button
                        Button(action: onReset) {
                            Text("Reset")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(height: 40)
                                .frame(minWidth: 70)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                        
                        // Start/Stop button
                        Button(action: onStartStop) {
                            Text(isRunning ? "Stop" : "Start")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(height: 40)
                                .frame(minWidth: 70)
                                .background(isRunning ? Color.red : Color.green)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PulsatingButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 3)
        }
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

// Add these helper views before ContentView to break up complex expressions
struct TimerHeaderView: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
    }
}

struct IntervalTimerView: View {
    let intervalTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Next Flip In")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
            
            Text(timeString(from: intervalTime))
                .font(.system(size: 46, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ElapsedTimerView: View {
    let elapsedTime: TimeInterval
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Time Elapsed")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
            
            Text(timeString(from: elapsedTime))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct TimerPresetButton: View {
    let presetTime: TimeInterval
    let timeStringConverter: (TimeInterval) -> String
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Use main thread for UI updates
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = true
                }
                
                // Delay to show button press animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation {
                        isPressed = false
                    }
                    action()
                }
            }
        }) {
            Text(timeStringConverter(presetTime))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(minWidth: 80)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle()) // Use plain style to enable custom animations
    }
}

struct TimerControlButtons: View {
    @ObservedObject var state: TimerState
    var settings: Settings
    var alertAction: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            // Start/Stop Button
            Button(action: {
                // Use main thread for UI updates
                DispatchQueue.main.async {
                    if state.isRunning {
                        state.stop()
                    } else {
                        if state.intervalTime > 0 {
                            state.start {
                                if settings.soundEnabled {
                                    state.playSound()
                                }
                                alertAction()
                            }
                        }
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(state.isRunning ? Color.red : Color.green)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: state.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Reset Button
            Button(action: {
                DispatchQueue.main.async {
                    state.reset()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.7))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// Now modify the Large Timer 1 section to use these components

// Remove the duplicate NewSettingsView declaration and keep only the most complete version
struct ContentView: View {
    @StateObject private var settings = Settings()
    @StateObject private var timerStates = TimerStatesManager()
    @State private var showSettings = false
    
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
    
    // Initialize timer states when view appears
    private func initializeTimerStates() {
        timerStates.syncTimerStates(timers: settings.allTimers)
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
        preheatTimer?.invalidate()
        preheatTimeRemaining = TimeInterval(settings.preheatDuration)
        showPreheatAlert = false
        isPreheatComplete = false
        
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
    }
    
    private func stopPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
        
        // Show the preheat alert when timer completes
        showPreheatAlert = true
        
        // Auto-dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            showPreheatAlert = false
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Helper functions to break down complex views
    @ViewBuilder
    private func additionalTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        if settings.compactMode {
            compactTimerView(for: timer, state: state)
        } else {
            largeTimerView(for: timer, state: state)
        }
    }
    
    @ViewBuilder
    private func compactTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        VStack(spacing: 10) {
            TimerHeaderView(name: timer.name)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Timer")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(timeString(from: state.intervalTime))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(timeString(from: state.elapsedTime))
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            
            HStack(spacing: 10) {
                TimerPresetButton(
                    presetTime: TimeInterval(timer.preset1),
                    timeStringConverter: timeString,
                    action: {
                        state.intervalTime = TimeInterval(timer.preset1)
                        state.stop()
                        // Ensure the UI updates before starting
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
                    timeStringConverter: timeString,
                    action: {
                        state.intervalTime = TimeInterval(timer.preset2)
                        state.stop()
                        // Ensure the UI updates before starting
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
                
                Spacer()
                
                TimerControlButtons(
                    state: state,
                    settings: settings,
                    alertAction: { alertState.isPresented = true }
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private func largeTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        VStack(spacing: 20) {
            TimerHeaderView(name: timer.name)
            
            IntervalTimerView(intervalTime: state.intervalTime)
            
            HStack(spacing: 20) {
                TimerPresetButton(
                    presetTime: TimeInterval(timer.preset1),
                    timeStringConverter: timeString,
                    action: {
                        state.intervalTime = TimeInterval(timer.preset1)
                        state.stop()
                        // Ensure the UI updates before starting
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
                    timeStringConverter: timeString,
                    action: {
                        state.intervalTime = TimeInterval(timer.preset2)
                        state.stop()
                        // Ensure the UI updates before starting
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
            
            ElapsedTimerView(elapsedTime: state.elapsedTime)
            
            TimerControlButtons(
                state: state,
                settings: settings,
                alertAction: { alertState.isPresented = true }
            )
        }
        .padding()
        .background(Color.black.opacity(0.5))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private func preheatButtonView() -> some View {
        VStack(spacing: 12) {
            Button(action: {
                startPreheatTimer()
            }) {
                HStack {
                    if preheatTimeRemaining > 0 {
                        Text("Preheat: \(timeString(from: preheatTimeRemaining))")
                    } else {
                        Text(isPreheatComplete ? "Preheat Done!" : "Preheat Grill")
                    }
                }
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isPreheatComplete ? Color.green : Color.orange)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red, lineWidth: isPreheatComplete ? 3 : 0)
                .scaleEffect(isPreheatComplete ? 1.03 : 1.0)
                .opacity(isPreheatComplete ? 1.0 : 0.0)
                .animation(isPreheatComplete ? Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isPreheatComplete)
        )
    }
    
    @ViewBuilder
    private func resetButtonView() -> some View {
        VStack(spacing: 12) {
            Button(action: {
                // Reset the UserDefaults values
                let defaults = UserDefaults.standard
                
                // Reset timer presets
                defaults.set(60, forKey: "timer1Preset1") // 1 minute
                defaults.set(120, forKey: "timer1Preset2") // 2 minutes
                defaults.set(180, forKey: "timer2Preset1") // 3 minutes
                defaults.set(240, forKey: "timer2Preset2") // 4 minutes
                
                // Reset timer names
                defaults.set("Timer 1", forKey: "timer1Name")
                defaults.set("Timer 2", forKey: "timer2Name")
                
                // Reset compact mode
                defaults.set(false, forKey: "compactMode")
                
                // Reset other settings
                defaults.set(900, forKey: "preheatDuration") // 15 minutes
                defaults.set(true, forKey: "soundEnabled")
                defaults.set(true, forKey: "hapticsEnabled")
                
                // Clear additional timers
                defaults.removeObject(forKey: "additionalTimers")
                settings.additionalTimers = []
                
                // Update the settings object
                settings.timer1Preset1 = 60
                settings.timer1Preset2 = 120
                settings.timer2Preset1 = 180
                settings.timer2Preset2 = 240
                settings.timer1Name = "Timer 1"
                settings.timer2Name = "Timer 2"
                settings.compactMode = false
                settings.preheatDuration = 900
                settings.soundEnabled = true
                settings.hapticsEnabled = true
                
                // Reset timer states
                initializeTimerStates()
            }) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Reset Settings")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.gray)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Settings Button
                    HStack {
                        Spacer()
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gear")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                    
                    // Timer 1
                    if let timer1 = settings.legacyTimersAsBBQTimers.first,
                       let timer1State = timerStates.state(for: timer1.id) {
                        additionalTimerView(for: timer1, state: timer1State)
                    }
                    
                    // Timer 2
                    if settings.legacyTimersAsBBQTimers.count > 1,
                       let timer2State = timerStates.state(for: settings.legacyTimersAsBBQTimers[1].id) {
                        additionalTimerView(for: settings.legacyTimersAsBBQTimers[1], state: timer2State)
                    }
                    
                    // Preheat Button
                    preheatButtonView()
                    
                    // Display additional timers
                    ForEach(settings.additionalTimers.filter { $0.isVisible }) { timer in
                        if let timerState = timerStates.state(for: timer.id) {
                            additionalTimerView(for: timer, state: timerState)
                        }
                    }
                    
                    // Reset Button
                    resetButtonView()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGray6))
            .sheet(isPresented: $showSettings) {
                NewSettingsView(settings: settings)
            }
            .overlay(
                Group {
                    if alertState.isPresented {
                        AlertView(alertState: alertState, audioPlayer: nil, isPreheat: false)
                    }
                    
                    if showPreheatAlert {
                        PreheatAlertView(
                            isPresented: $showPreheatAlert,
                            onDismiss: {
                                showPreheatAlert = false
                            }
                        )
                    }
                }
            )
            .onAppear {
                // Initialize timer states when view appears
                initializeTimerStates()
            }
            .onChange(of: settings.additionalTimers) {
                // Update timer states when timers are added or removed
                initializeTimerStates()
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
                        .background(Color.red)
                        .cornerRadius(12)
                    
                    Text("Start")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 3)
            .padding()
            .background(Color(.systemGray6))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Timer Component")
        }
    }
}

// PreheatAlertView with pulsing red border
struct PreheatAlertView: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    
    // Add state for animation
    @State private var animationPhase = false
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            // Content container
            VStack(spacing: 16) {
                Text("Preheat Complete! 🔥")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Button("Dismiss") {
                    onDismiss()
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
            .onAppear {
                startAnimationTimer()
            }
            .onDisappear {
                stopAnimationTimer()
            }
        }
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
        // Clean up timer when view disappears
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
class TimerState: Identifiable, ObservableObject {
    let id: UUID
    @Published var intervalTime: TimeInterval
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning = false
    
    private var timer: Timer?
    private var onCompleteAction: (() -> Void)?
    
    init(id: UUID, intervalTime: TimeInterval = 0) {
        self.id = id
        self.intervalTime = intervalTime
    }
    
    func start(onComplete: @escaping () -> Void) {
        // Store completion handler
        self.onCompleteAction = onComplete
        
        // Ensure timer is invalidated before creating a new one
        timer?.invalidate()
        
        // Only start if we have time to count down
        guard intervalTime > 0 else { return }
        
        // Create and schedule timer on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                if self.intervalTime > 0 {
                    self.intervalTime -= 1
                    self.elapsedTime += 1
                } else {
                    self.stop()
                    self.onCompleteAction?()
                }
            }
            
            // Add timer to RunLoop to ensure it runs while scrolling
            if let timer = self.timer {
                RunLoop.current.add(timer, forMode: .common)
            }
            
            self.isRunning = true
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
        }
    }
    
    func reset() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.elapsedTime = 0
        }
    }
    
    // Helper function to play sound
    func playSound() {
        AudioServicesPlaySystemSound(1005)
    }
}

// Add this class to manage multiple timer states
class TimerStatesManager: ObservableObject {
    @Published var states: [TimerState] = []
    
    // Initialize with existing timers from settings
    func initializeTimerStates(timers: [BBQTimer]) {
        // Clear existing states
        for state in states {
            state.stop()
        }
        states = []
        
        // Create new states for each timer
        for timer in timers {
            states.append(TimerState(id: timer.id))
        }
    }
    
    // Add a new timer state for a new BBQTimer
    func addTimerState(for timer: BBQTimer) -> TimerState {
        let state = TimerState(id: timer.id)
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
}


