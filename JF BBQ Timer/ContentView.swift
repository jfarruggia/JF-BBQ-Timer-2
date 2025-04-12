//
//  ContentView.swift
// /Users/jamesfarruggia/Documents/Documents - James's Mac mini/Xcode JF Projects/JF BBQ Timer/JF BBQ TimerUITests JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import AVFoundation

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

class Settings: ObservableObject {
    @Published var presetIntervals: [PresetInterval]
    @Published var preheatDuration: TimeInterval {
        didSet {
            UserDefaults.standard.set(preheatDuration, forKey: "preheatDuration")
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
        }
    }
    
    init() {
        // Initialize all stored properties first
        self.presetIntervals = []
        self.preheatDuration = 900 // Default 15 minutes
        self.soundEnabled = false
        self.hapticsEnabled = false
        
        // Now we can safely use self
        if let data = UserDefaults.standard.data(forKey: "presetIntervals"),
           let decoded = try? JSONDecoder().decode([PresetInterval].self, from: data) {
            print("Loading saved presets: \(decoded.count)")
            // Ensure we never exceed 9 presets when loading
            self.presetIntervals = Array(decoded.prefix(9))
        } else {
            print("Initializing with default presets")
            // Initialize with 9 default presets
            self.presetIntervals = [
                PresetInterval(name: "1m", minutes: 1, seconds: 0),
                PresetInterval(name: "2m", minutes: 2, seconds: 0),
                PresetInterval(name: "5m", minutes: 5, seconds: 0),
                PresetInterval(name: "10m", minutes: 10, seconds: 0),
                PresetInterval(name: "15m", minutes: 15, seconds: 0),
                PresetInterval(name: "20m", minutes: 20, seconds: 0),
                PresetInterval(name: "30m", minutes: 30, seconds: 0),
                PresetInterval(name: "45m", minutes: 45, seconds: 0),
                PresetInterval(name: "1h", minutes: 60, seconds: 0)
            ]
            print("Default presets initialized: \(self.presetIntervals.count)")
            
            // Save initial presets
            if let encoded = try? JSONEncoder().encode(self.presetIntervals) {
                UserDefaults.standard.set(encoded, forKey: "presetIntervals")
            }
        }
        
        // Load other settings
        self.preheatDuration = UserDefaults.standard.double(forKey: "preheatDuration") > 0 ? 
            UserDefaults.standard.double(forKey: "preheatDuration") : 900 // Default 15 minutes
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.hapticsEnabled = UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    private func savePresets() {
        print("Saving presets: \(presetIntervals.count)")
        if let encoded = try? JSONEncoder().encode(presetIntervals) {
            UserDefaults.standard.set(encoded, forKey: "presetIntervals")
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

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    @State private var preheatMinutes: Int = 0
    @State private var preheatSeconds: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Preheat Timer Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preheat Timer Duration")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 20) {
                            // Minutes Picker
                            Picker("Minutes", selection: $preheatMinutes) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute)")
                                        .tag(minute)
                                        .foregroundColor(preheatMinutes == minute ? .blue : .primary)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                            
                            Text("min")
                                .foregroundColor(.gray)
                            
                            // Seconds Picker
                            Picker("Seconds", selection: $preheatSeconds) {
                                ForEach(0..<60) { second in
                                    Text("\(second)")
                                        .tag(second)
                                        .foregroundColor(preheatSeconds == second ? .blue : .primary)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            .clipped()
                            
                            Text("sec")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 100)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    
                    // Existing preset intervals
                    ForEach($settings.presetIntervals) { $preset in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preset.formattedName)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Duration:")
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 20) {
                                    // Minutes Picker
                                    Picker("Minutes", selection: $preset.minutes) {
                                        ForEach(0..<60) { minute in
                                            Text("\(minute)")
                                                .tag(minute)
                                                .foregroundColor(preset.minutes == minute ? .blue : .primary)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100)
                                    .clipped()
                                    
                                    Text("min")
                                        .foregroundColor(.gray)
                                    
                                    // Seconds Picker
                                    Picker("Seconds", selection: $preset.seconds) {
                                        ForEach(0..<60) { second in
                                            Text("\(second)")
                                                .tag(second)
                                                .foregroundColor(preset.seconds == second ? .blue : .primary)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100)
                                    .clipped()
                                    
                                    Text("sec")
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 100)
                            }
                            
                            Text("Preview:")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            
                            ButtonPreview(preset: preset)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                // Save preheat duration when done
                settings.preheatDuration = TimeInterval(preheatMinutes * 60 + preheatSeconds)
                dismiss()
            })
            .onAppear {
                // Initialize pickers with current preheat duration
                preheatMinutes = Int(settings.preheatDuration) / 60
                preheatSeconds = Int(settings.preheatDuration) % 60
            }
        }
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

struct ContentView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var intervalTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var selectedMinutes = 0
    @State private var selectedSeconds = 0
    @State private var audioPlayer: AVAudioPlayer?
    @StateObject private var settings = Settings()
    @StateObject private var alertState = AlertState()
    @State private var isSettingTime = false
    @State private var showConfirmation = false
    @State private var currentTimerType: TimerType = .regular
    
    // Replace the individual sheet state booleans with a single activeSheet optional
    @State private var activeSheet: ActiveSheet?
    @State private var pressedButtonId: UUID? // Track which button is being pressed
    
    var sortedPresets: [PresetInterval] {
        settings.presetIntervals.sorted { $0.totalSeconds < $1.totalSeconds }
    }
    
    var body: some View {
        ZStack {
            // Background gradient with #2E2E2E base
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.7, green: 0.55, blue: 0.45), // Brown/bronze at top
                    Color(hex: "#2E2E2E")   // Dark gray at bottom (#2E2E2E)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Settings Gear Icon - moved to the very top
                HStack {
                    Spacer()
                    Button(action: {
                        activeSheet = .settings
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color(hex: "#3B3B3B").opacity(0.7))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                }
                .padding(.horizontal)
                .padding(.top, 5)
                
                // Interval Timer
                VStack {
                    Text("Next Flip In")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(timeString(from: intervalTime))
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(
                            Color(hex: "#3B3B3B")
                                .overlay(
                                    Color(hex: "#FF6A00").opacity(0.2)
                                )
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 5)
                }
                .padding(.top, 1)
                .padding(.bottom, 10)
                
                // Elapsed Timer
                VStack(spacing: 2) {
                    Text("Time Since You Lit It 🔥")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text(timeString(from: elapsedTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 10)
                .padding(.bottom, 80)
                
                // Preset Intervals Grid
                VStack(spacing: 30) {
                    // Show just top 2 presets in a row
                    HStack(spacing: 20) {
                        ForEach(sortedPresets.prefix(2)) { preset in
                            Button(action: {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                // Set timer
                                intervalTime = preset.totalSeconds
                                if !isRunning {
                                    startTimer()
                                }
                            }) {
                                Text(preset.displayName)
                                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                    .background(
                                        // Gradient background instead of solid color
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                (intervalTime == preset.totalSeconds ? Color(hex: "#FF6A00").opacity(0.9) : Color(hex: "#7C4DFF").opacity(0.8)),
                                                (intervalTime == preset.totalSeconds ? Color(hex: "#FF6A00").opacity(0.7) : Color(hex: "#7C4DFF").opacity(0.6))
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .opacity(isRunning && intervalTime > 0 ? 0.7 : 1.0)
                                    )
                                    // Add a subtle blur for glassmorphism
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .blur(radius: 1)
                                    )
                                    .cornerRadius(12)
                                    // Overlay to create a glass-like border
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.6),
                                                        Color.white.opacity(0.2)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    // Add shadow for depth
                                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                            }
                            .buttonStyle(BouncyButtonStyle(id: preset.id, pressedButtonId: $pressedButtonId))
                            .disabled(isRunning && intervalTime > 0)
                        }
                    }
                    .padding(.top, 15)
                    
                    // More button - styled as a card/popup tab
                    HStack(spacing: 15) {
                        Button(action: {
                            activeSheet = .allPresets
                        }) {
                            HStack {
                                Text("Explore More Times ⏲")
                                    .font(.system(size: 22, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.trailing, 5)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                // Card background using 3B3B3B
                                Color(hex: "#3B3B3B")
                            )
                            .overlay(
                                // Top border highlight for card effect
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.horizontal, 1),
                                alignment: .top
                            )
                            .cornerRadius(15)
                            // Card-like shadow
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                        
                        // Preheat Timer Button
                        Button(action: {
                            currentTimerType = .preheat
                            intervalTime = settings.preheatDuration
                            elapsedTime = 0 // Reset elapsed timer
                            if !isRunning {
                                startTimer()
                            }
                        }) {
                            Text("Preheat 🔥")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    // Card background using 3B3B3B
                                    Color(hex: "#3B3B3B")
                                )
                                .overlay(
                                    // Top border highlight for card effect
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 1)
                                        .padding(.horizontal, 1),
                                    alignment: .top
                                )
                                .cornerRadius(15)
                                // Card-like shadow
                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 15)
                    .padding(.bottom, 5)
                    
                    // Reset buttons row - dark gray as in the image
                    HStack(spacing: 15) {
                        // Reset Elapsed Button
                        Button(action: {
                            elapsedTime = 0
                        }) {
                            Text("Reset Elapsed")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 150, height: 44)
                                .background(Color(hex: "#3B3B3B"))
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                        
                        // Reset Interval Button
                        Button(action: {
                            intervalTime = 0
                        }) {
                            Text("Reset Interval")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 150, height: 44)
                                .background(Color(hex: "#3B3B3B"))
                                .cornerRadius(15)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(BouncyButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                    }
                    .padding(.top, 10)
                    
                    // Start/Stop Button - blue as in the image
                    Button(action: {
                        if isRunning {
                            stopTimer()
                        } else {
                            startTimer()
                        }
                    }) {
                        Text(isRunning ? "Stop" : "Start")
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 250, height: 70)
                            .background(isRunning ? Color(hex: "#D72638") : Color(hex: "#FF6A00"))
                            .cornerRadius(35)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                            // Add a subtle pulsing animation when not running
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    .scaleEffect(!isRunning ? 1.04 : 1.0)
                                    .opacity(!isRunning ? 0.6 : 0)
                                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isRunning)
                            )
                    }
                    .buttonStyle(PulsatingButtonStyle(id: UUID(), pressedButtonId: $pressedButtonId))
                    .padding(.top, 20)
                    .padding(.bottom)
                }
            }
            .padding(.horizontal)
            
            if alertState.isPresented || alertState.showPreheatAlert {
                AlertView(alertState: alertState, audioPlayer: audioPlayer, isPreheat: alertState.showPreheatAlert)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                NewSettingsView(settings: settings)
            case .intervalInput:
                VStack(spacing: 20) {
                    Text("Set Custom Interval")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    // Preview of selected time
                    Text(timeString(from: TimeInterval(selectedMinutes * 60 + selectedSeconds)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                    
                    HStack(spacing: 20) {
                        // Minutes Picker
                        Picker("Minutes", selection: $selectedMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)")
                                    .tag(minute)
                                    .foregroundColor(selectedMinutes == minute ? .blue : .primary)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("min")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        
                        // Seconds Picker
                        Picker("Seconds", selection: $selectedSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)")
                                    .tag(second)
                                    .foregroundColor(selectedSeconds == second ? .blue : .primary)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("sec")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .frame(height: 100)
                    
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            activeSheet = nil
                        }
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 100)
                        .background(Color.gray)
                        .cornerRadius(8)
                        
                        Button("Set") {
                            withAnimation {
                                isSettingTime = true
                                showConfirmation = true
                            }
                            
                            // Add haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            
                            // Set the time after a brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                intervalTime = TimeInterval(selectedMinutes * 60 + selectedSeconds)
                                activeSheet = nil
                            }
                        }
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 100)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .scaleEffect(isSettingTime ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSettingTime)
                    }
                    
                    if showConfirmation {
                        Text("Time Set!")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding()
                
            case .allPresets:
                NavigationView {
                    ScrollView {
                        VStack(spacing: 15) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 15) {
                                ForEach(sortedPresets) { preset in
                                    Button(action: {
                                        intervalTime = preset.totalSeconds
                                        if !isRunning {
                                            startTimer()
                                        }
                                        activeSheet = nil
                                    }) {
                                        Text(preset.displayName)
                                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                intervalTime == preset.totalSeconds ? Color.orange : Color.purple
                                            )
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("All Presets")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                activeSheet = nil
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            setupAudioPlayer()
        }
    }
    
    private func setupAudioPlayer() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
        
        guard let soundURL = Bundle.main.url(forResource: "beep", withExtension: "mp3") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error setting up audio player: \(error.localizedDescription)")
        }
    }
    
    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if intervalTime > 0 {
                intervalTime -= 1
                elapsedTime += 1
            } else {
                stopTimer()
                // Play sound and show appropriate alert
                playSound()
                if currentTimerType == .preheat {
                    alertState.showPreheatAlert = true
                    elapsedTime = 0 // Reset elapsed timer when preheat completes
                } else {
                    alertState.isPresented = true
                }
            }
        }
    }
    
    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func playSound() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

#Preview {
    ContentView()
}

