//
//  ContentView.swift
// /Users/jamesfarruggia/Documents/Documents - James's Mac mini/Xcode JF Projects/JF BBQ Timer/JF BBQ TimerUITests JF BBQ Timer
//
//  Created by James Farruggia on 3/29/25.
//

import SwiftUI
import AVFoundation

struct PresetInterval: Identifiable, Codable {
    var id: UUID
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
    @Published var presetIntervals: [PresetInterval] {
        didSet {
            // Ensure we never exceed 9 presets
            if presetIntervals.count > 9 {
                presetIntervals = Array(presetIntervals.prefix(9))
            }
            savePresets()
        }
    }
    
    init() {
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
            // Save the initial presets
            savePresets()
        }
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
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
            .navigationTitle("Preset Intervals")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

class AlertState: ObservableObject {
    @Published var isPresented: Bool = false {
        didSet {
            print("AlertState changed from \(oldValue) to \(isPresented)")
        }
    }
}

struct AlertView: View {
    @ObservedObject var alertState: AlertState
    let audioPlayer: AVAudioPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        print("Background tapped")
                        audioPlayer?.stop()
                        alertState.isPresented = false
                    }
                
                Button(action: {
                    print("Button tapped")
                    audioPlayer?.stop()
                    alertState.isPresented = false
                }) {
                    Text("Interval Complete!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 200, height: 200)
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

struct ContentView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var intervalTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var selectedMinutes = 0
    @State private var selectedSeconds = 0
    @State private var showingIntervalInput = false
    @State private var showingSettings = false
    @State private var audioPlayer: AVAudioPlayer?
    @StateObject private var settings = Settings()
    @StateObject private var alertState = AlertState()
    @State private var isSettingTime = false
    @State private var showConfirmation = false
    
    var sortedPresets: [PresetInterval] {
        settings.presetIntervals.sorted { $0.totalSeconds < $1.totalSeconds }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 222/255, green: 123/255, blue: 91/255),
                    Color(red: 221/255, green: 41/255, blue: 50/255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Settings Button at the top
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                    .padding(.top)
                }
                
                // Interval Timer (now prominent)
                VStack {
                    Text("Interval Time")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(timeString(from: intervalTime))
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 5)
                }
                .padding(.top, 20)
                
                // Elapsed Timer (now smaller)
                VStack {
                    Text("Elapsed Time")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Text(timeString(from: elapsedTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.top, 5)
                
                Spacer()
                
                // Preset Intervals Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    ForEach(sortedPresets.prefix(9)) { preset in
                        Button(action: {
                            intervalTime = preset.totalSeconds
                            if !isRunning {
                                startTimer()
                            }
                        }) {
                            Text(preset.displayName)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    (isRunning && intervalTime > 0) ? Color.gray :
                                        (intervalTime == preset.totalSeconds ? Color.orange : Color.purple)
                                )
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(intervalTime == preset.totalSeconds ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .opacity(isRunning && intervalTime > 0 ? 0.7 : 1.0)
                        }
                        .disabled(isRunning && intervalTime > 0)
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 30)
                
                HStack(spacing: 15) {
                    // Reset Elapsed Button
                    Button(action: {
                        elapsedTime = 0
                    }) {
                        Text("Reset Elapsed")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 110, height: 44)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    
                    // Reset Interval Button
                    Button(action: {
                        intervalTime = 0
                    }) {
                        Text("Reset Interval")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 110, height: 44)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                    
                    // Set Custom Interval Button
                    Button(action: {
                        showingIntervalInput = true
                    }) {
                        Text("Set Interval")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 110, height: 44)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                // Start/Stop Button
                Button(action: {
                    if isRunning {
                        stopTimer()
                    } else {
                        startTimer()
                    }
                }) {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(isRunning ? Color.red : Color.green)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
                .padding(.bottom)
            }
            .padding(.horizontal)
            
            if alertState.isPresented {
                AlertView(alertState: alertState, audioPlayer: audioPlayer)
            }
        }
        .sheet(isPresented: $showingIntervalInput) {
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
                        showingIntervalInput = false
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
                            showingIntervalInput = false
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
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
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
            elapsedTime += 1
            if intervalTime > 0 {
                intervalTime -= 1
                if intervalTime == 0 {
                    print("Timer reached zero")
                    DispatchQueue.main.async {
                        playAlertSound()
                        alertState.isPresented = true
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func playAlertSound() {
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

