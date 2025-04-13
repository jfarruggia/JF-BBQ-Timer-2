import SwiftUI

struct NewSettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    @State private var showTimer1Preset1Picker = false
    @State private var showTimer1Preset2Picker = false
    @State private var showTimer2Preset1Picker = false
    @State private var showTimer2Preset2Picker = false
    @State private var showPreheatDurationPicker = false
    
    var body: some View {
        NavigationView {
            List {
                // Timer Names Section
                Section(header: Text("Timer Names")) {
                    TextField("Timer 1 Name", text: $settings.timer1Name)
                    TextField("Timer 2 Name", text: $settings.timer2Name)
                }
                
                // Timer 1 Presets Section
                Section(header: Text("Timer 1 Presets")) {
                    Button(action: {
                        showTimer1Preset1Picker = true
                    }) {
                        HStack {
                            Text("Preset 1")
                            Spacer()
                            Text(timeString(from: settings.timer1Preset1))
                                .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showTimer1Preset1Picker) {
                        TimerPickerSheet(
                            title: "Timer 1 Preset 1",
                            seconds: Binding(
                                get: { settings.timer1Preset1 },
                                set: { settings.timer1Preset1 = $0 }
                            ),
                            isPresented: $showTimer1Preset1Picker
                        )
                    }
                    
                    Button(action: {
                        showTimer1Preset2Picker = true
                    }) {
                        HStack {
                            Text("Preset 2")
                            Spacer()
                            Text(timeString(from: settings.timer1Preset2))
                                .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showTimer1Preset2Picker) {
                        TimerPickerSheet(
                            title: "Timer 1 Preset 2",
                            seconds: Binding(
                                get: { settings.timer1Preset2 },
                                set: { settings.timer1Preset2 = $0 }
                            ),
                            isPresented: $showTimer1Preset2Picker
                        )
                    }
                }
                
                // Timer 2 Presets Section
                Section(header: Text("Timer 2 Presets")) {
                    Button(action: {
                        showTimer2Preset1Picker = true
                    }) {
                        HStack {
                            Text("Preset 1")
                            Spacer()
                            Text(timeString(from: settings.timer2Preset1))
                                .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showTimer2Preset1Picker) {
                        TimerPickerSheet(
                            title: "Timer 2 Preset 1",
                            seconds: Binding(
                                get: { settings.timer2Preset1 },
                                set: { settings.timer2Preset1 = $0 }
                            ),
                            isPresented: $showTimer2Preset1Picker
                        )
                    }
                    
                    Button(action: {
                        showTimer2Preset2Picker = true
                    }) {
                        HStack {
                            Text("Preset 2")
                            Spacer()
                            Text(timeString(from: settings.timer2Preset2))
                                .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showTimer2Preset2Picker) {
                        TimerPickerSheet(
                            title: "Timer 2 Preset 2",
                            seconds: Binding(
                                get: { settings.timer2Preset2 },
                                set: { settings.timer2Preset2 = $0 }
                            ),
                            isPresented: $showTimer2Preset2Picker
                        )
                    }
                }
                
                // Preheat Duration Section
                Section(header: Text("Preheat Duration")) {
                    Button(action: {
                        showPreheatDurationPicker = true
                    }) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(timeString(from: settings.preheatDuration))
                                .foregroundColor(.gray)
                        }
                    }
                    .sheet(isPresented: $showPreheatDurationPicker) {
                        TimerPickerSheet(
                            title: "Preheat Duration",
                            seconds: Binding(
                                get: { settings.preheatDuration },
                                set: { settings.preheatDuration = $0 }
                            ),
                            isPresented: $showPreheatDurationPicker
                        )
                    }
                }
                
                // Alerts Section
                Section(header: Text("Alerts")) {
                    Toggle("Sound Alerts", isOn: $settings.soundEnabled)
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                }
                
                // Future Features Section
                Section(header: Text("Future Features")) {
                    NavigationLink(destination: Text("Multiple timer profiles - Coming Soon")) {
                        Text("Multiple Timer Profiles")
                    }
                    NavigationLink(destination: Text("Custom alert sounds - Coming Soon")) {
                        Text("Custom Alert Sounds")
                    }
                    NavigationLink(destination: Text("Temperature monitoring - Coming Soon")) {
                        Text("Temperature Monitoring")
                    }
                    NavigationLink(destination: Text("Recipe integration - Coming Soon")) {
                        Text("Recipe Integration")
                    }
                    NavigationLink(destination: Text("Cloud sync - Coming Soon")) {
                        Text("Cloud Sync")
                    }
                }
                
                // Timer Preset Styles Preview Link
                Section {
                    NavigationLink(destination: TimerPresetStylesPreview()) {
                        Text("View Timer Preset Style Options")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                settings.save()
                dismiss()
            })
        }
    }
}

struct TimerPickerSheet: View {
    let title: String
    @Binding var seconds: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .bold()
            }
            .padding()
            
            HStack(spacing: 8) {
                Picker("Minutes", selection: Binding(
                    get: { seconds / 60 },
                    set: { seconds = $0 * 60 + seconds % 60 }
                )) {
                    ForEach(0..<60) { minute in
                        Text("\(minute)").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                
                Text("min")
                
                Picker("Seconds", selection: Binding(
                    get: { seconds % 60 },
                    set: { seconds = (seconds / 60) * 60 + $0 }
                )) {
                    ForEach(0..<60) { second in
                        Text("\(second)").tag(second)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                
                Text("sec")
            }
            .padding(.bottom, 40)
            Spacer()
        }
    }
}

struct TimeTextField: View {
    @Binding var seconds: Int
    @State private var text: String = ""
    
    var body: some View {
        TextField("MM:SS", text: $text, onCommit: {
            let timeComponents = text.split(separator: ":")
            if timeComponents.count == 2,
               let minutes = Int(timeComponents[0]),
               let seconds = Int(timeComponents[1]) {
                self.seconds = minutes * 60 + seconds
            }
        })
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .onAppear {
            let minutes = seconds / 60
            let secs = seconds % 60
            text = String(format: "%d:%02d", minutes, secs)
        }
    }
}

// Helper function to convert seconds to formatted time string
func timeString(from seconds: Int) -> String {
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d", minutes, secs)
}

struct TimerPresetStylesPreview: View {
    @State private var preset1: Int = 300 // 5 minutes
    @State private var preset2: Int = 180 // 3 minutes
    @State private var showCustomPicker = false
    
    var body: some View {
        List {
            Section(header: Text("Option 1: Stepper with Time Display")) {
                HStack {
                    Text("Preset Time")
                    Spacer()
                    Text(timeString(from: preset1))
                        .font(.system(.body, design: .monospaced))
                    Stepper("", onIncrement: {
                        preset1 += 30
                    }, onDecrement: {
                        preset1 = max(0, preset1 - 30)
                    })
                }
            }
            
            Section(header: Text("Option 2: Tap to Edit with Popup")) {
                Button(action: {
                    showCustomPicker = true
                }) {
                    HStack {
                        Text("Preset Time")
                        Spacer()
                        Text(timeString(from: preset1))
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showCustomPicker) {
                    VStack {
                        HStack {
                            Button("Cancel") {
                                showCustomPicker = false
                            }
                            Spacer()
                            Button("Done") {
                                showCustomPicker = false
                            }
                            .bold()
                        }
                        .padding()
                        
                        HStack(spacing: 8) {
                            Picker("Minutes", selection: Binding(
                                get: { preset1 / 60 },
                                set: { preset1 = $0 * 60 + preset1 % 60 }
                            )) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute)").tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            
                            Text("min")
                            
                            Picker("Seconds", selection: Binding(
                                get: { preset1 % 60 },
                                set: { preset1 = (preset1 / 60) * 60 + $0 }
                            )) {
                                ForEach(0..<60) { second in
                                    Text("\(second)").tag(second)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100)
                            
                            Text("sec")
                        }
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("Option 3: Slider with Time Display")) {
                VStack {
                    HStack {
                        Text("Preset Time")
                        Spacer()
                        Text(timeString(from: preset2))
                    }
                    Slider(value: Binding(
                        get: { Double(preset2) },
                        set: { preset2 = Int($0) }
                    ), in: 0...3600, step: 30)
                }
            }
            
            Section(header: Text("Option 4: Quick Preset Buttons")) {
                VStack(alignment: .leading) {
                    Text("Preset Time")
                    HStack {
                        ForEach([1, 3, 5, 10], id: \.self) { minutes in
                            Button("\(minutes)m") {
                                preset2 = minutes * 60
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                        Button("Custom") {
                            showCustomPicker = true
                        }
                        .buttonStyle(BorderedButtonStyle())
                    }
                    Text(timeString(from: preset2))
                        .padding(.top, 4)
                }
            }
            
            Section(header: Text("Option 5: Text Field Input")) {
                HStack {
                    Text("Preset Time")
                    Spacer()
                    TimeTextField(seconds: $preset1)
                        .frame(width: 80)
                }
            }
        }
        .navigationTitle("Timer Preset Options")
    }
} 