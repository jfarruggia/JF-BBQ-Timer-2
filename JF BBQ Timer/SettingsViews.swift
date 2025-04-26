import SwiftUI
import AVFoundation
// Import the file with PremiumFeatureBadge - not needed if they are in the same file
// import JF_BBQ_Timer

struct NewSettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    
    @State private var showTimer1Preset1Picker = false
    @State private var showTimer1Preset2Picker = false
    @State private var showTimer2Preset1Picker = false
    @State private var showTimer2Preset2Picker = false
    @State private var showPreheatDurationPicker = false
    @State private var showTimerManagement = false
    @State private var showPremiumUpgrade = false // For premium upgrade modal
    
    var body: some View {
        ZStack {
            NavigationView {
                List {
                    // Timer Management Section (now includes all timers)
                    Section(header: Text("Manage Timers")) {
                        NavigationLink(destination: TimerManagementView(settings: settings)) {
                            HStack {
                                Image(systemName: "timer")
                                    .foregroundColor(.blue)
                                Text("Manage All Timers")
                            }
                        }
                        
                        Text("Configure all timers including presets")
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
                        
                        if settings.soundEnabled {
                            NavigationLink(destination: AlertSoundsView(settings: settings)) {
                                HStack {
                                    Text("Alert Sound")
                                    Spacer()
                                    Text(settings.selectedAlertSound.displayName)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Button(action: {
                                // Test the current alert sound
                                AudioServicesPlaySystemSound(settings.selectedAlertSound.systemSoundID)
                            }) {
                                Text("Test Sound")
                                    .foregroundColor(.blue)
                            }
                        }
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
                    
                    // Premium Features Section
                    Section(header: Text("Premium Features")) {
                        if settings.isPremiumUser {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Premium Unlocked")
                                    .bold()
                            }
                            
                            Text("Thank you for supporting JF BBQ Timer!")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        } else {
                            Button(action: {
                                showPremiumUpgrade = true
                            }) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                    Text("Upgrade to Premium")
                                        .bold()
                                    Spacer()
                                    Text("$4.99")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Feature list
                            VStack(alignment: .leading, spacing: 4) {
                                premiumFeatureRow("Unlimited timers")
                                premiumFeatureRow("Advanced timer settings")
                                premiumFeatureRow("Custom themes (coming soon)")
                                premiumFeatureRow("Priority support")
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
                        
                        // For testing purposes
                        if settings.isPremiumUser {
                            Button(action: {
                                settings.resetPremiumStatus()
                            }) {
                                Text("Reset Premium Status (Testing)")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Future Features Section
                    Section(header: Text("Timer Customization")) {
                        NavigationLink(destination: AlertSoundsView(settings: settings)) {
                            Text("Alert Sounds")
                        }
                        .premiumFeatureBadge(settings: settings)
                        
                        NavigationLink(destination: Text("Temperature monitoring - Coming Soon")) {
                            Text("Temperature Monitoring")
                        }
                        .premiumFeatureBadge(settings: settings)
                        
                        NavigationLink(destination: Text("Recipe integration - Coming Soon")) {
                            Text("Recipe Integration")
                        }
                        
                        NavigationLink(destination: Text("Cloud sync - Coming Soon")) {
                            Text("Cloud Sync")
                        }
                        .premiumFeatureBadge(settings: settings)
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
            
            // Show premium upgrade overlay when needed
            if showPremiumUpgrade {
                PremiumUpgradeView(settings: settings, isPresented: $showPremiumUpgrade)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it appears on top
            }
        }
    }
    
    private func premiumFeatureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
            Spacer()
        }
    }
}

// Updated TimerManagementView to handle both legacy and additional timers
struct TimerManagementView: View {
    @ObservedObject var settings: Settings
    @State private var showingAddTimerSheet = false
    @State private var newTimerName = ""
    @State private var showPreset1Picker = false
    @State private var showPreset2Picker = false
    @State private var tempPreset1 = 60 // 1 minute default
    @State private var tempPreset2 = 120 // 2 minutes default
    @State private var editingTimerIndex: Int? = nil
    @State private var editingLegacyTimer: Int? = nil // 0 for Timer 1, 1 for Timer 2
    @State private var showPremiumUpgrade = false // For showing premium upgrade modal
    @State private var timerToDelete: Int? = nil // Track which timer to delete
    @State private var showDeleteConfirmation = false // Control delete confirmation
    
    var body: some View {
        ZStack {
            List {
                // Default Timers Section
                Section(header: Text("Default Timers")) {
                    // Timer 1
                    timerRow(
                        for: settings.legacyTimersAsBBQTimers[0],
                        isLegacy: true,
                        legacyIndex: 0
                    )
                    
                    // Timer 2
                    timerRow(
                        for: settings.legacyTimersAsBBQTimers[1],
                        isLegacy: true,
                        legacyIndex: 1
                    )
                }
                
                // Additional Timers Section
                Section(header: Text("Additional Timers")) {
                    if settings.additionalTimers.isEmpty && settings.isPremiumUser {
                        Text("No additional timers yet. Add one using the button below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else if !settings.additionalTimers.isEmpty {
                        Text("Swipe left on a timer to delete")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                    
                    ForEach(settings.additionalTimers.indices, id: \.self) { index in
                        timerRow(
                            for: settings.additionalTimers[index],
                            at: index
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            settings.removeTimer(at: index)
                        }
                    }
                    
                    Button(action: {
                        if !settings.canAddMoreTimers() {
                            // Show premium upgrade modal if over free limit
                            showPremiumUpgrade = true
                        } else {
                            // Set up for adding a new timer
                            newTimerName = ""
                            tempPreset1 = 60
                            tempPreset2 = 120
                            editingTimerIndex = nil
                            editingLegacyTimer = nil
                            showingAddTimerSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add New Timer")
                            
                            if !settings.isPremiumUser {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    if !settings.isPremiumUser {
                        HStack {
                            Text("Additional timers require premium")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Upgrade") {
                                showPremiumUpgrade = true
                            }
                            .font(.footnote)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // Premium Features Section (only shown for non-premium users)
                if !settings.isPremiumUser {
                    Section(header: Text("Premium Features")) {
                        Button(action: {
                            showPremiumUpgrade = true
                        }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium")
                                    .bold()
                                Spacer()
                                Text("$4.99")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("Unlock additional timers and premium features")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Manage Timers")
            .sheet(isPresented: $showingAddTimerSheet) {
                addTimerSheet
            }
            
            // Show premium upgrade overlay when needed
            if showPremiumUpgrade {
                PremiumUpgradeView(settings: settings, isPresented: $showPremiumUpgrade)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it appears on top
            }
        }
        .confirmationDialog(
            "Delete Timer",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let index = timerToDelete {
                    settings.removeTimer(at: index)
                    timerToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                timerToDelete = nil
            }
        } message: {
            if let index = timerToDelete, index < settings.additionalTimers.count {
                Text("Are you sure you want to delete '\(settings.additionalTimers[index].name)'?")
            } else {
                Text("Are you sure you want to delete this timer?")
            }
        }
    }
    
    // Updated timer row to handle both legacy and additional timers
    private func timerRow(for timer: BBQTimer, isLegacy: Bool = false, legacyIndex: Int? = nil, at index: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timer.name)
                    .font(.headline)
                Spacer()
                
                // Edit button for all timers
                Button(action: {
                    // Set up for editing this timer
                    newTimerName = timer.name
                    tempPreset1 = timer.preset1
                    tempPreset2 = timer.preset2
                    
                    if isLegacy && legacyIndex != nil {
                        editingLegacyTimer = legacyIndex
                        editingTimerIndex = nil
                    } else if !isLegacy && index != nil {
                        editingTimerIndex = index
                        editingLegacyTimer = nil
                    }
                    
                    showingAddTimerSheet = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Delete button only for additional timers
                if !isLegacy, let index = index {
                    Button(action: {
                        timerToDelete = index
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.horizontal, 8)
                }
                
                // Only show visibility toggle for additional timers
                if !isLegacy, let index = index {
                    Toggle("", isOn: Binding(
                        get: { timer.isVisible },
                        set: { newValue in
                            settings.updateTimer(at: index, isVisible: newValue)
                        }
                    ))
                    .labelsHidden()
                }
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
                    
                    if !showPreset1Picker && !showPreset2Picker {
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
                    
                    if showPreset1Picker {
                        VStack {
                            HStack {
                                Text("Preset 1").font(.headline)
                                Spacer()
                                Button("Done") {
                                    showPreset1Picker = false
                                }
                                .bold()
                            }
                            .padding(.vertical, 8)
                            
                            HStack(spacing: 8) {
                                Picker("Minutes", selection: Binding(
                                    get: { tempPreset1 / 60 },
                                    set: { tempPreset1 = $0 * 60 + tempPreset1 % 60 }
                                )) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                
                                Text("min")
                                
                                Picker("Seconds", selection: Binding(
                                    get: { tempPreset1 % 60 },
                                    set: { tempPreset1 = (tempPreset1 / 60) * 60 + $0 }
                                )) {
                                    ForEach(0..<60) { second in
                                        Text("\(second)").tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                
                                Text("sec")
                            }
                        }
                    }
                    
                    if showPreset2Picker {
                        VStack {
                            HStack {
                                Text("Preset 2").font(.headline)
                                Spacer()
                                Button("Done") {
                                    showPreset2Picker = false
                                }
                                .bold()
                            }
                            .padding(.vertical, 8)
                            
                            HStack(spacing: 8) {
                                Picker("Minutes", selection: Binding(
                                    get: { tempPreset2 / 60 },
                                    set: { tempPreset2 = $0 * 60 + tempPreset2 % 60 }
                                )) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                
                                Text("min")
                                
                                Picker("Seconds", selection: Binding(
                                    get: { tempPreset2 % 60 },
                                    set: { tempPreset2 = (tempPreset2 / 60) * 60 + $0 }
                                )) {
                                    ForEach(0..<60) { second in
                                        Text("\(second)").tag(second)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100)
                                
                                Text("sec")
                            }
                        }
                    }
                }
            }
            .navigationTitle(getEditTitle())
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingAddTimerSheet = false
                },
                trailing: Button("Save") {
                    saveTimer()
                    showingAddTimerSheet = false
                }
            )
        }
    }
    
    // Helper function to get the appropriate title for the edit sheet
    private func getEditTitle() -> String {
        if editingLegacyTimer == 0 {
            return "Edit Timer 1"
        } else if editingLegacyTimer == 1 {
            return "Edit Timer 2"
        } else if editingTimerIndex != nil {
            return "Edit Timer"
        } else {
            return "Add Timer"
        }
    }
    
    // Helper function to save the timer
    private func saveTimer() {
        // Default name if empty
        if newTimerName.isEmpty {
            newTimerName = "Timer \(settings.additionalTimers.count + 3)"
        }
        
        // Handle legacy timers
        if let legacyIndex = editingLegacyTimer {
            if legacyIndex == 0 {
                // Update Timer 1
                settings.timer1Name = newTimerName
                settings.timer1Preset1 = tempPreset1
                settings.timer1Preset2 = tempPreset2
            } else if legacyIndex == 1 {
                // Update Timer 2
                settings.timer2Name = newTimerName
                settings.timer2Preset1 = tempPreset1
                settings.timer2Preset2 = tempPreset2
            }
        } 
        // Handle additional timers
        else if let editIndex = editingTimerIndex {
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
        
        // Save changes
        settings.save()
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

// View for selecting and previewing alert sounds
struct AlertSoundsView: View {
    @ObservedObject var settings: Settings
    @State private var isPlaying = false
    @State private var selectedSound: Settings.AlertSound
    @State private var audioPlayer: AVAudioPlayer?
    
    init(settings: Settings) {
        self.settings = settings
        // Initialize with the currently selected sound
        _selectedSound = State(initialValue: settings.selectedAlertSound)
    }
    
    var body: some View {
        List {
            Section(header: Text("Standard Sounds")) {
                ForEach(Settings.AlertSound.standardSounds) { sound in
                    soundRow(sound: sound)
                }
            }
            
            Section(header: Text("Premium Sounds")) {
                ForEach(Settings.AlertSound.premiumSounds) { sound in
                    soundRow(sound: sound, isPremium: true)
                }
            }
            
            Section(header: Text("Custom Sounds")) {
                if let customSoundID = settings.selectedCustomSoundID {
                    HStack {
                        Text("Using Custom Sound")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                
                NavigationLink(destination: CustomSoundsView(settings: settings)) {
                    if settings.isPremiumUser {
                        Text("Manage Custom Sounds")
                    } else {
                        HStack {
                            Text("Add Custom Sounds")
                            Spacer()
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .disabled(!settings.isPremiumUser)
            }
            
            Section {
                Button(action: {
                    settings.selectedAlertSound = selectedSound
                    settings.save()
                }) {
                    Text("Save Selection")
                        .foregroundColor(.blue)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            Section(header: Text("About Alert Sounds")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Different sounds can help you identify which timer is complete when multiple timers are running.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    if !settings.isPremiumUser {
                        HStack {
                            Text("Unlock premium sounds with premium")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("Alert Sounds")
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    private func soundRow(sound: Settings.AlertSound, isPremium: Bool = false) -> some View {
        Button(action: {
            if !isPremium || settings.isPremiumUser {
                selectedSound = sound
                playSound(sound: sound)
            } else {
                // Show premium upgrade prompt
                playSound(sound: Settings.AlertSound.system) // Play preview
            }
        }) {
            HStack {
                Text(sound.displayName)
                    .foregroundColor(isPremium && !settings.isPremiumUser ? .gray : .primary)
                
                Spacer()
                
                if selectedSound == sound {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                
                if isPremium && !settings.isPremiumUser {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.footnote)
                } else {
                    Button(action: {
                        playSound(sound: sound)
                    }) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .disabled(isPremium && !settings.isPremiumUser)
        .contentShape(Rectangle())
    }
    
    private func playSound(sound: Settings.AlertSound) {
        // Clear any custom sound selection when selecting a system sound
        if settings.isUsingCustomSound {
            settings.deselectCustomSound()
        }
        
        // Use AudioServices for system sounds
        if sound.isPremiumSound && !settings.isPremiumUser {
            // Play a preview but inform user this is premium
            AudioServicesPlaySystemSound(Settings.AlertSound.system.systemSoundID)
            return
        }
        
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
} 