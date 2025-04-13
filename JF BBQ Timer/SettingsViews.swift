import SwiftUI

struct NewSettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    @State private var showTimer1Preset1Picker = false
    @State private var showTimer1Preset2Picker = false
    @State private var showTimer2Preset1Picker = false
    @State private var showTimer2Preset2Picker = false
    @State private var showPreheatDurationPicker = false
    @State private var showTimerManagement = false
    
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
                
                // Add Timer Management Section
                Section(header: Text("Manage Timers")) {
                    NavigationLink(destination: TimerManagementView(settings: settings)) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(.blue)
                            Text("Manage Additional Timers")
                        }
                    }
                    
                    Text("Add custom timers for different meats or cooking methods")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
                
                // Accessibility Section
                Section(header: Text("Accessibility")) {
                    Toggle("Compact Display Mode", isOn: $settings.compactMode)
                        .tint(.blue)
                    
                    if !settings.compactMode {
                        Text("Large display mode enabled for better visibility")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Compact mode saves space for more timers")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Future Features Section
                Section(header: Text("Future Features")) {
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

// Add TimerManagementView
struct TimerManagementView: View {
    @ObservedObject var settings: Settings
    @State private var showingAddTimerSheet = false
    @State private var newTimerName = ""
    @State private var showPreset1Picker = false
    @State private var showPreset2Picker = false
    @State private var tempPreset1 = 60 // 1 minute default
    @State private var tempPreset2 = 120 // 2 minutes default
    @State private var editingTimerIndex: Int? = nil
    
    var body: some View {
        List {
            Section(header: Text("Additional Timers")) {
                ForEach(settings.additionalTimers.indices, id: \.self) { index in
                    timerRow(for: settings.additionalTimers[index], at: index)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        settings.removeTimer(at: index)
                    }
                }
                
                Button(action: {
                    newTimerName = ""
                    tempPreset1 = 60
                    tempPreset2 = 120
                    editingTimerIndex = nil
                    showingAddTimerSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add New Timer")
                    }
                }
            }
            
            if settings.additionalTimers.isEmpty {
                Section {
                    Text("Add custom timers for different meats or cooking methods")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Manage Timers")
        .sheet(isPresented: $showingAddTimerSheet) {
            addTimerSheet
        }
        .sheet(isPresented: $showPreset1Picker) {
            TimerPickerSheet(
                title: "Preset 1",
                seconds: $tempPreset1,
                isPresented: $showPreset1Picker
            )
        }
        .sheet(isPresented: $showPreset2Picker) {
            TimerPickerSheet(
                title: "Preset 2",
                seconds: $tempPreset2,
                isPresented: $showPreset2Picker
            )
        }
    }
    
    private func timerRow(for timer: BBQTimer, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timer.name)
                    .font(.headline)
                Spacer()
                Button(action: {
                    newTimerName = timer.name
                    tempPreset1 = timer.preset1
                    tempPreset2 = timer.preset2
                    editingTimerIndex = index
                    showingAddTimerSheet = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Toggle("", isOn: Binding(
                    get: { timer.isVisible },
                    set: { newValue in
                        settings.updateTimer(at: index, isVisible: newValue)
                    }
                ))
                .labelsHidden()
            }
            
            HStack {
                Text("Presets:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(timeString(from: timer.preset1))
                    .font(.subheadline)
                Text("|")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(timeString(from: timer.preset2))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var addTimerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Timer Details")) {
                    TextField("Timer Name", text: $newTimerName)
                        .autocapitalization(.words)
                    
                    Button(action: {
                        showPreset1Picker = true
                    }) {
                        HStack {
                            Text("Preset 1")
                            Spacer()
                            Text(timeString(from: tempPreset1))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        showPreset2Picker = true
                    }) {
                        HStack {
                            Text("Preset 2")
                            Spacer()
                            Text(timeString(from: tempPreset2))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle(editingTimerIndex == nil ? "Add Timer" : "Edit Timer")
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingAddTimerSheet = false
                },
                trailing: Button("Save") {
                    if newTimerName.isEmpty {
                        newTimerName = "Timer \(settings.additionalTimers.count + 3)"
                    }
                    
                    if let editIndex = editingTimerIndex {
                        settings.updateTimer(
                            at: editIndex,
                            name: newTimerName,
                            preset1: tempPreset1,
                            preset2: tempPreset2
                        )
                    } else {
                        settings.addTimer(
                            name: newTimerName,
                            preset1: tempPreset1,
                            preset2: tempPreset2
                        )
                    }
                    showingAddTimerSheet = false
                }
            )
        }
    }
}

func timeString(from seconds: Int) -> String {
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
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