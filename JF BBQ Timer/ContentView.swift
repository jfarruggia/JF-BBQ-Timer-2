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

class Settings: ObservableObject {
    @Published var timer1Name: String
    @Published var timer2Name: String
    @Published var timer1Preset1: Int
    @Published var timer1Preset2: Int
    @Published var timer2Preset1: Int
    @Published var timer2Preset2: Int
    @Published var preheatDuration: Int
    @Published var soundEnabled: Bool
    @Published var hapticsEnabled: Bool
    
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
    }
    
    func save() {
        UserDefaults.standard.set(timer1Name, forKey: "timer1Name")
        UserDefaults.standard.set(timer2Name, forKey: "timer2Name")
        UserDefaults.standard.set(timer1Preset1, forKey: "timer1Preset1")
        UserDefaults.standard.set(timer1Preset2, forKey: "timer1Preset2")
        UserDefaults.standard.set(timer2Preset1, forKey: "timer2Preset1")
        UserDefaults.standard.set(timer2Preset2, forKey: "timer2Preset2")
        UserDefaults.standard.set(preheatDuration, forKey: "preheatDuration")
        UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
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

// Remove the duplicate NewSettingsView declaration and keep only the most complete version
struct ContentView: View {
    @StateObject private var settings = Settings()
    @State private var showSettings = false
    
    // Timer 1 State
    @State private var timer1IntervalTime: TimeInterval = 0
    @State private var timer1ElapsedTime: TimeInterval = 0
    @State private var timer1: Timer?
    @State private var isTimer1Running = false
    
    // Timer 2 State
    @State private var timer2IntervalTime: TimeInterval = 0
    @State private var timer2ElapsedTime: TimeInterval = 0
    @State private var timer2: Timer?
    @State private var isTimer2Running = false
    
    // Alert State
    @StateObject private var alertState = AlertState()
    
    // Preheat Timer State
    @State private var showPreheatAlert = false
    @State private var preheatTimeRemaining: TimeInterval = 0
    @State private var preheatTimer: Timer?
    
    private func startTimer1() {
        timer1?.invalidate()
        timer1 = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timer1IntervalTime > 0 {
                timer1IntervalTime -= 1
                timer1ElapsedTime += 1
            } else {
                stopTimer1()
                if settings.soundEnabled {
                    playSound()
                }
                if settings.hapticsEnabled {
                    alertState.isPresented = true
                }
            }
        }
        isTimer1Running = true
    }
    
    private func stopTimer1() {
        timer1?.invalidate()
        timer1 = nil
        isTimer1Running = false
    }
    
    private func startTimer2() {
        timer2?.invalidate()
        timer2 = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timer2IntervalTime > 0 {
                timer2IntervalTime -= 1
                timer2ElapsedTime += 1
            } else {
                stopTimer2()
                if settings.soundEnabled {
                    playSound()
                }
                if settings.hapticsEnabled {
                    alertState.isPresented = true
                }
            }
        }
        isTimer2Running = true
    }
    
    private func stopTimer2() {
        timer2?.invalidate()
        timer2 = nil
        isTimer2Running = false
    }
    
    private func startPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimeRemaining = TimeInterval(settings.preheatDuration)
        showPreheatAlert = true
        
        preheatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if preheatTimeRemaining > 0 {
                preheatTimeRemaining -= 1
            } else {
                stopPreheatTimer()
                if settings.soundEnabled {
                    playSound()
                }
                if settings.hapticsEnabled {
                    alertState.isPresented = true
                }
            }
        }
    }
    
    private func stopPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
    }
    
    private func playSound() {
        AudioServicesPlaySystemSound(1005)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
                    
                    // Timer 1 Section
                    VStack(spacing: 12) {
                        Text(settings.timer1Name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        // Interval Timer Display
                        VStack(spacing: 4) {
                            Text("Next Flip In")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            Text(timeString(from: timer1IntervalTime))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                        }
                        
                        // Elapsed Timer Display
                        VStack(spacing: 4) {
                            Text("Time Since You Lit It 🔥")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            Text(timeString(from: timer1ElapsedTime))
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                        }
                        
                        // Timer 1 Preset Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                timer1IntervalTime = TimeInterval(settings.timer1Preset1)
                                stopTimer1()
                                startTimer1()
                            }) {
                                Text(timeString(from: TimeInterval(settings.timer1Preset1)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                            
                            Button(action: {
                                timer1IntervalTime = TimeInterval(settings.timer1Preset2)
                                stopTimer1()
                                startTimer1()
                            }) {
                                Text(timeString(from: TimeInterval(settings.timer1Preset2)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                        }
                        
                        // Timer 1 Control Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                timer1IntervalTime = 0
                                timer1ElapsedTime = 0
                                stopTimer1()
                            }) {
                                Text("Reset")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                if isTimer1Running {
                                    stopTimer1()
                                } else {
                                    startTimer1()
                                }
                            }) {
                                Text(isTimer1Running ? "Stop" : "Start")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(isTimer1Running ? Color.red : Color.green)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    
                    // Timer 2 Section
                    VStack(spacing: 12) {
                        Text(settings.timer2Name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        // Interval Timer Display
                        VStack(spacing: 4) {
                            Text("Next Flip In")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            Text(timeString(from: timer2IntervalTime))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                        }
                        
                        // Elapsed Timer Display
                        VStack(spacing: 4) {
                            Text("Time Since You Lit It 🔥")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.gray)
                            Text(timeString(from: timer2ElapsedTime))
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                        }
                        
                        // Timer 2 Preset Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                timer2IntervalTime = TimeInterval(settings.timer2Preset1)
                                stopTimer2()
                                startTimer2()
                            }) {
                                Text(timeString(from: TimeInterval(settings.timer2Preset1)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                            
                            Button(action: {
                                timer2IntervalTime = TimeInterval(settings.timer2Preset2)
                                stopTimer2()
                                startTimer2()
                            }) {
                                Text(timeString(from: TimeInterval(settings.timer2Preset2)))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                        }
                        
                        // Timer 2 Control Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                timer2IntervalTime = 0
                                timer2ElapsedTime = 0
                                stopTimer2()
                            }) {
                                Text("Reset")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                if isTimer2Running {
                                    stopTimer2()
                                } else {
                                    startTimer2()
                                }
                            }) {
                                Text(isTimer2Running ? "Stop" : "Start")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(isTimer2Running ? Color.red : Color.green)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    
                    // Preheat Button
                    VStack(spacing: 12) {
                        Button(action: {
                            startPreheatTimer()
                        }) {
                            Text("Start Preheat (\(timeString(from: TimeInterval(settings.preheatDuration))))")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 5)
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
                            timeRemaining: preheatTimeRemaining,
                            isPresented: $showPreheatAlert,
                            onDismiss: {
                                stopPreheatTimer()
                                showPreheatAlert = false
                            }
                        )
                    }
                }
            )
        }
    }
}

struct PreheatAlertView: View {
    let timeRemaining: TimeInterval
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                Text("Preheat in Progress")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Time until grill is ready:")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text(timeString(from: timeRemaining))
                    .font(.system(size: 48, weight: .bold))
                    .padding(.vertical, 10)
                
                Button(action: {
                    onDismiss()
                }) {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(width: 120)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding(25)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}

