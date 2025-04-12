import SwiftUI

struct NewSettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Timer Settings Section
                Section("Timer Settings") {
                    NavigationLink {
                        PreheatSettingsView(settings: settings)
                    } label: {
                        HStack {
                            Text("Preheat Duration")
                            Spacer()
                            Text(formatTime(settings.preheatDuration))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink("Manage Timer Presets") {
                        PresetIntervalsView(settings: settings)
                    }
                }
                
                // Sound Settings Section
                Section("Alerts") {
                    Toggle("Sound Alerts", isOn: $settings.soundEnabled)
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if seconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}

struct PreheatSettingsView: View {
    @ObservedObject var settings: Settings
    @State private var minutes: Int
    @State private var seconds: Int
    @Environment(\.dismiss) var dismiss
    
    init(settings: Settings) {
        self.settings = settings
        _minutes = State(initialValue: Int(settings.preheatDuration) / 60)
        _seconds = State(initialValue: Int(settings.preheatDuration) % 60)
    }
    
    var body: some View {
        Form {
            Section("Preheat Duration") {
                HStack {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Text("min")
                        .foregroundColor(.gray)
                    
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60) { second in
                            Text("\(second)").tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Text("sec")
                        .foregroundColor(.gray)
                }
                .frame(height: 100)
            }
        }
        .navigationTitle("Preheat Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    settings.preheatDuration = TimeInterval(minutes * 60 + seconds)
                    dismiss()
                }
            }
        }
    }
}

struct PresetIntervalsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            ForEach($settings.presetIntervals) { $preset in
                VStack(alignment: .leading, spacing: 8) {
                    Text(preset.formattedName)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 20) {
                        // Minutes Picker
                        Picker("Minutes", selection: $preset.minutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)")
                                    .tag(minute)
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
            }
        }
        .navigationTitle("Timer Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
} 