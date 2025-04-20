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
    @ObservedObject var state: TimerState // Direct state reference instead of bindings
    var settings: Settings
    var alertState: AlertState
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Main timer content
            HStack(spacing: 8) {
                // Timer info - vertically stacked
                VStack(alignment: .leading, spacing: 6) {
                    // Flip timer
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flip In")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.blue.opacity(0.8))
                        Text(timeString(from: state.intervalTime))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: state.intervalTime)
                            .id("interval-\(state.intervalTime)")
                    }
                    
                    // Elapsed timer
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Text("Lit Time")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.orange.opacity(0.8))
                            
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                        Text(timeString(from: state.elapsedTime))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: state.elapsedTime)
                            .id("elapsed-\(state.elapsedTime)")
                    }
                }
                
                Spacer()
                
                // Control buttons in a simpler layout
                VStack(spacing: 8) {
                    // Preset buttons - direct actions instead of callbacks
                    HStack(spacing: 8) {
                        Button("P1") {
                            print("Direct P1 tap: \(preset1)")
                            // Ensure interval timer is stopped first
                            state.stop()
                            // Don't reset the elapsed timer, just set new interval time
                            state.setCurrentIntervalTime(preset1)
                            
                            // Ensure we're on the main thread and add a very short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                print("Starting timer with P1 value: \(preset1)")
                                if preset1 > 0 {
                                    state.start {
                                        if settings.soundEnabled {
                                            state.playSound()
                                        }
                                        if settings.hapticsEnabled {
                                            alertState.isPresented = true
                                        }
                                    }
                                    print("Timer started: isRunning=\(state.isRunning)")
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                        
                        Button("P2") {
                            print("Direct P2 tap: \(preset2)")
                            // Ensure interval timer is stopped first
                            state.stop()
                            // Don't reset the elapsed timer, just set new interval time
                            state.setCurrentIntervalTime(preset2)
                            
                            // Ensure we're on the main thread and add a very short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                print("Starting timer with P2 value: \(preset2)")
                                if preset2 > 0 {
                                    state.start {
                                        if settings.soundEnabled {
                                            state.playSound()
                                        }
                                        if settings.hapticsEnabled {
                                            alertState.isPresented = true
                                        }
                                    }
                                    print("Timer started: isRunning=\(state.isRunning)")
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        Button("Reset") {
                            print("Direct reset tap")
                            state.resetToZero()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                        
                        Button(state.isRunning ? "Stop" : "Start") {
                            print("Direct start/stop tap")
                            if state.isRunning {
                                state.stop()
                            } else if state.intervalTime > 0 {
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(state.isRunning ? Color.red : Color.green)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(8)
            .background(Color(UIColor(red: 250/255, green: 166/255, blue: 72/255, alpha: 0.5)))
            .cornerRadius(15)
            .padding(.horizontal, 12) // Add horizontal padding
            .padding(.bottom, 5) // Add more space between containers
            .frame(maxWidth: .infinity) // Use full available width
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

// Add debug visualization to the TimerHeaderView
struct TimerHeaderView: View {
    let name: String
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    var body: some View {
        Text(name)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
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

struct IntervalTimerView: View {
    @ObservedObject var state: TimerState
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("FLIP IN")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
                .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                    view.debugFrame(
                        debugSettings.showFrames,
                        color: .red,
                        showPadding: debugSettings.showPadding,
                        showBackground: debugSettings.showBackgrounds,
                        label: "Label"
                    )
                }
            
            Text(timeString(from: state.intervalTime))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut, value: state.intervalTime)
                .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                    view.debugFrame(
                        debugSettings.showFrames,
                        color: .orange,
                        showPadding: debugSettings.showPadding,
                        showBackground: debugSettings.showBackgrounds,
                        label: "Timer Value"
                    )
                }
        }
        .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
            view.debugFrame(
                debugSettings.showFrames,
                color: .purple,
                showPadding: debugSettings.showPadding,
                showBackground: debugSettings.showBackgrounds,
                label: "Timer Container"
            )
        }
    }
}

struct ElapsedTimerView: View {
    @ObservedObject var state: TimerState
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("TIME SINCE YOU LIT IT")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
            }
            .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                view.debugFrame(
                    debugSettings.showFrames,
                    color: .red,
                    showPadding: debugSettings.showPadding,
                    showBackground: debugSettings.showBackgrounds,
                    label: "Label"
                )
            }
            
            Text(timeString(from: state.elapsedTime))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut, value: state.elapsedTime)
                .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                    view.debugFrame(
                        debugSettings.showFrames,
                        color: .orange,
                        showPadding: debugSettings.showPadding,
                        showBackground: debugSettings.showBackgrounds,
                        label: "Elapsed Value"
                    )
                }
        }
        .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
            view.debugFrame(
                debugSettings.showFrames,
                color: .green,
                showPadding: debugSettings.showPadding,
                showBackground: debugSettings.showBackgrounds,
                label: "Elapsed Container"
            )
        }
    }
}

struct TimerPresetButton: View {
    var presetTime: TimeInterval
    var timeStringConverter: (TimeInterval) -> String
    var action: () -> Void
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    var body: some View {
                    Button(action: {
            // Add haptic feedback when button is pressed
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            
            // Execute action immediately
            action()
        }) {
            Text(timeStringConverter(presetTime))
                .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                .frame(minWidth: 80)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.orange, Color.red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                    view.debugFrame(
                        debugSettings.showFrames,
                        color: .yellow,
                        showPadding: debugSettings.showPadding,
                        showBackground: debugSettings.showBackgrounds,
                        label: "Preset Button"
                    )
                }
        }
    }
}

struct TimerControlButtons: View {
    @ObservedObject var state: TimerState
    var settings: Settings
    var alertState: AlertState
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared
    
    var body: some View {
        HStack(spacing: 20) {
                    Button(action: {
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                if state.isRunning {
                    state.stop()
                } else if state.intervalTime > 0 {
                    state.start {
                        if settings.soundEnabled {
                            state.playSound()
                        }
                        if settings.hapticsEnabled {
                            alertState.isPresented = true
                        }
                    }
                }
            }) {
                Image(systemName: state.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                            .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                view.debugFrame(
                    debugSettings.showFrames,
                    color: .blue,
                    showPadding: debugSettings.showPadding,
                    showBackground: debugSettings.showBackgrounds,
                    label: "Play/Pause"
                )
            }
            
                    Button(action: {
                // Add haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                
                // Reset both timers completely
                state.resetToZero()
                
                // Print debug info to verify reset
                print("Reset button pressed. Interval timer reset to: \(state.intervalTime)")
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.gray.opacity(0.8), Color.gray]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                view.debugFrame(
                    debugSettings.showFrames,
                    color: .gray,
                    showPadding: debugSettings.showPadding,
                    showBackground: debugSettings.showBackgrounds,
                    label: "Reset"
                )
            }
        }
        .padding(.top, 16)
        .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
            view.debugFrame(
                debugSettings.showFrames,
                color: .cyan,
                showPadding: debugSettings.showPadding,
                showBackground: debugSettings.showBackgrounds,
                label: "Controls Container"
            )
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
                HStack {
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
    @StateObject private var settings = Settings()
    @StateObject private var timerStates = TimerStatesManager()
    @State private var showSettings = false
    
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
    
    // For debug panel positioning
    @State private var showDebugPanel = false
    
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
        .background(Color(UIColor(red: 250/255, green: 166/255, blue: 72/255, alpha: 0.5)))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.black, lineWidth: 2)
        )
        .padding(.horizontal, 12) // Add horizontal padding
        .padding(.bottom, 5) // Add more space between containers
        .frame(maxWidth: .infinity) // Use full available width
    }
    
    @ViewBuilder
    private func largeTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        // Use a regular VStack instead of GeometryReader to preserve scrolling behavior
        VStack(spacing: 12) { // Reduced spacing from 20 to 12
            TimerHeaderView(name: timer.name)
            
            IntervalTimerView(state: state)
                .padding(.top, 6) // Reduced padding from 10 to 6
            
            ElapsedTimerView(state: state)
                .padding(.bottom, 6) // Reduced padding from 10 to 6
            
            HStack(spacing: 16) {
                TimerPresetButton(
                    presetTime: TimeInterval(timer.preset1),
                    timeStringConverter: timeString,
                    action: {
                        // First stop any running timer
                        state.stop()
                        
                        // Reset elapsed time
                        state.setElapsedTime(0)
                        
                        // Set new interval time without changing the initial reset value
                        state.setCurrentIntervalTime(TimeInterval(timer.preset1))
                        
                        // Add a small delay to ensure state updates are processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Start the timer after a slight delay
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
                        // First stop any running timer
                        state.stop()
                        
                        // Reset elapsed time
                        state.setElapsedTime(0)
                        
                        // Set new interval time without changing the initial reset value
                        state.setCurrentIntervalTime(TimeInterval(timer.preset2))
                        
                        // Add a small delay to ensure state updates are processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Start the timer after a slight delay
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
            .padding(.top, 4) // Reduced padding from 8 to 4
            
            TimerControlButtons(
                state: state,
                settings: settings,
                alertState: alertState
            )
        }
        .padding()
        .frame(maxWidth: .infinity) // Use full width of parent container
        .background(Color(UIColor(red: 250/255, green: 166/255, blue: 72/255, alpha: 0.5)))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.black, lineWidth: 2)
        )
        .padding(.horizontal, 12) // Add horizontal padding
        .padding(.bottom, 5) // Add more space between containers
    }
    
    // Add a method for the preheat button view with debug visualization
    private func preheatButtonView() -> some View {
        Button(action: {
            startPreheatTimer()
        }) {
            VStack {
                Text("Preheat Grill")
                    .font(.system(size: 20, weight: .bold))
                
                Text(preheatTimeRemaining > 0 ? timeString(from: preheatTimeRemaining) : timeString(from: TimeInterval(settings.preheatDuration)))
                    .font(.system(size: 24, weight: .bold))
            }
            .padding()
            .frame(width: UIScreen.main.bounds.width - 24)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange, Color.red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black, lineWidth: 2)
            )
            .modifier(PreheatCompleteModifier(isPreheatComplete: isPreheatComplete))
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
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main content with timers
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 10) { // Spacing between timer containers
                        // Add a spacer at the top to ensure content starts below the header
                        Spacer()
                            .frame(height: 40)
                            
                        // Timer 1
                        if let timer1 = settings.legacyTimersAsBBQTimers.first,
                           let timer1State = timerStates.state(for: timer1.id) {
                            additionalTimerView(for: timer1, state: timer1State)
                                .id(timer1.id) // Add id to force layout refresh
                        }
                        
                        // Timer 2
                        if settings.legacyTimersAsBBQTimers.count > 1,
                           let timer2State = timerStates.state(for: settings.legacyTimersAsBBQTimers[1].id) {
                            additionalTimerView(for: settings.legacyTimersAsBBQTimers[1], state: timer2State)
                                .id(settings.legacyTimersAsBBQTimers[1].id) // Add id to force layout refresh
                        }
                        
                        // Display additional timers
                        ForEach(settings.additionalTimers.filter { $0.isVisible }) { timer in
                            if let timerState = timerStates.state(for: timer.id) {
                                additionalTimerView(for: timer, state: timerState)
                                    .id(timer.id) // Add id to force layout refresh
                            }
                        }
                        
                        // Add padding at bottom to make room for the fixed buttons
                        Spacer()
                            .frame(height: 100) // Height for preheat button plus padding
                    }
                    .padding(.top, 30) // Increase top padding
                }
                .safeAreaInset(edge: .top) {
                     // Empty view with height to create space below the navigation bar
                      Color.clear.frame(height: 25)
                }
                .scrollIndicators(.hidden)
                .if(debugSettings.isEnabled && debugSettings.showGrid) { view in
                    view.gridOverlay(
                        spacing: debugSettings.gridSpacing,
                        color: .blue.opacity(0.2),
                        lineWidth: 0.5
                    )
                }
                
                // Fixed buttons at the bottom
                VStack(spacing: 16) {
                    // Preheat Button
                    preheatButtonView()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 30)
                .padding(.top, 12)
                .background(Color(UIColor(red: 201/255, green: 48/255, blue: 32/255, alpha: 1.0)))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: -2)
            }
            .background(Color(UIColor(red: 201/255, green: 48/255, blue: 32/255, alpha: 0.75)))
            .edgesIgnoringSafeArea(.all)
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
                
                // Set navigation bar appearance to match the app's background color
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(red: 201/255, green: 48/255, blue: 32/255, alpha: 0.75)
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
            .onChange(of: settings.additionalTimers) {
                // Update timer states when timers are added or removed
                initializeTimerStates()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                
                // Debug toggle button - hidden in release builds
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        debugSettings.isEnabled.toggle()
                        if !debugSettings.isEnabled {
                            showDebugPanel = false
                        }
                    }) {
                        Image(systemName: debugSettings.isEnabled ? "rectangle.dashed" : "rectangle")
                            .foregroundColor(debugSettings.isEnabled ? .red : .gray)
                    }
                }
                
                if debugSettings.isEnabled {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showDebugPanel.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(showDebugPanel ? .green : .gray)
                        }
                    }
                }
            }
            .navigationTitle("JF BBQ Timer")
            .navigationBarTitleDisplayMode(.inline)
            
            // Add debug panel overlay when debug mode is enabled
            if debugSettings.isEnabled && showDebugPanel {
                VStack {
                    DebugPanel(settings: debugSettings)
                    Spacer()
                }
                .zIndex(100) // Make sure it's on top
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
class TimerState: ObservableObject {
    let id: UUID
    @Published var intervalTime: TimeInterval
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    
    private var intervalTimer: Timer?
    private var elapsedTimer: Timer?
    private var onCompleteAction: (() -> Void)?
    private var initialIntervalTime: TimeInterval
    
    init(id: UUID, interval: TimeInterval) {
        self.id = id
        self.intervalTime = interval
        self.initialIntervalTime = interval
    }
    
    func setIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.initialIntervalTime = time  // Also update initial time when setting a preset
            self.objectWillChange.send()
        }
    }
    
    // Add a new method to set only the current interval time without changing the initial time
    func setCurrentIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.objectWillChange.send()
        }
    }
    
    func setElapsedTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = time
            self.objectWillChange.send()  // Explicitly notify observers
        }
    }
    
    func start(onComplete: @escaping () -> Void) {
        print("Starting timer with interval: \(intervalTime)")
        
        // Make absolutely sure interval timer is in a clean state
        // But don't touch the elapsed timer
        intervalTimer?.invalidate()
        intervalTimer = nil
        self.isRunning = false
        
        // Store completion handler
        self.onCompleteAction = onComplete
        
        // Ensure interval timer is invalidated before creating a new one
        stopIntervalTimer()
        
        // Only start interval timer if we have time to count down
        guard intervalTime > 0 else {
            print("⚠️ Cannot start timer - interval time is \(intervalTime)")
            return
        }
        
        // Start elapsed timer if not already running, but don't reset it
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
            
            // Ensure timer updates happen on main thread
            DispatchQueue.main.async {
                if self.intervalTime > 0 {
                    self.intervalTime -= 1
                    print("Interval timer tick: \(self.intervalTime)")
                    // Explicitly notify observers of changes
                    self.objectWillChange.send()
                } else {
                    print("Interval timer complete")
                    self.stopIntervalTimer() // Only stop the interval timer
                    self.onCompleteAction?()
                }
            }
        }
        
        // Add timer to RunLoop to ensure it runs while scrolling
        if let timer = self.intervalTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("Timer added to RunLoop")
        } else {
            print("⚠️ Failed to create timer")
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
    
    func stop() {
        // Only stop the interval timer, leave the elapsed timer running
        stopIntervalTimer()
    }
    
    func reset() {
        // Stop both timers and reset elapsed time
        stopIntervalTimer()
        stopElapsedTimer()
        
        // Reset on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reset both timers - set elapsed to zero and interval to zero
            self.elapsedTime = 0
            self.intervalTime = 0 // Set to zero instead of initialIntervalTime
            self.isRunning = false
            
            // Explicitly notify observers
            self.objectWillChange.send()
        }
    }
    
    func playSound() {
        // Implementation for sound playing
        let systemSoundID: SystemSoundID = 1005
        AudioServicesPlaySystemSound(systemSoundID)
    }
    
    // Add this method to explicitly set the interval time and update the initial value
    func setPresetIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.initialIntervalTime = time  // Also update initial time when setting a preset
            self.objectWillChange.send()
        }
    }
    
    func resetToZero() {
        // Stop both timers
        stopIntervalTimer()
        stopElapsedTimer()
        
        // Reset on main thread - ensure all values go to zero
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reset both timers - set everything to zero
            self.elapsedTime = 0
            self.intervalTime = 0
            self.isRunning = false
            
            // Explicitly notify observers
            self.objectWillChange.send()
            
            print("Timer reset to zero. Interval time is now: \(self.intervalTime)")
        }
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
        // Each timer state's initialIntervalTime will be set to preset1
        // This becomes the default value used when resetting the timer
        for timer in timers {
            states.append(TimerState(id: timer.id, interval: TimeInterval(timer.preset1)))
        }
    }
    
    // Add a new timer state for a new BBQTimer
    func addTimerState(for timer: BBQTimer) -> TimerState {
        let state = TimerState(id: timer.id, interval: TimeInterval(timer.preset1))
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


