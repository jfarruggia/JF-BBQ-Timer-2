import SwiftUI
import AVFoundation
import RevenueCat
import RevenueCatUI

struct PressableButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct NewSettingsView: View {
    @ObservedObject var settings: Settings
    @Environment(\.dismiss) var dismiss
    @State private var showPremiumUpgrade = false
    @State private var showPreheatDurationPicker = false
    @State private var showSettingsSaved = false
    @State private var showTestPlayed = false

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    // Premium Banner (if not premium)
                    if !settings.isPremiumUser {
                        Section {
                            Button(action: { showPremiumUpgrade = true }) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading) {
                                        Text("Upgrade to Premium")
                                            .bold()
                                        Text("Unlock unlimited timers, custom sounds, and more!")
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("$4.99")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Timer Management
                    Section(header: Text("Timers")) {
                        NavigationLink("Manage All Timers", destination: TimerManagementView(settings: settings))
                        Button(action: { showPreheatDurationPicker = true }) {
                            HStack {
                                Text("Preheat Duration")
                                Spacer()
                                Text(TimeFormatter.timeString(from: settings.preheatDuration))
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
                        // Add Reset to Default button for Preheat Duration
                        Button(action: {
                            settings.preheatDuration = 600 // 10 minutes
                            settings.save()
                        }) {
                            Text("Reset to Default")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }

                    // Alerts & Sounds (grouped all related settings here)
                    Section(header: Text("Alerts & Sounds"), footer: Text("You can choose to play a sound, a voice announcement, or both when a timer completes.")) {
                        Toggle("Sound Alerts", isOn: $settings.soundEnabled)
                        Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                        Toggle("Voice Announcements", isOn: $settings.voiceAnnouncementsEnabled)
                            .disabled(!settings.isPremiumUser)
                            .overlay(
                                Group {
                                    if !settings.isPremiumUser {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.gray)
                                            .padding(.leading, 8)
                                    }
                                }, alignment: .trailing
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !settings.isPremiumUser {
                                    showPremiumUpgrade = true
                                }
                            }
                        if settings.voiceAnnouncementsEnabled {
                            Text("Hear a spoken message when your timer completes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        NavigationLink(destination: VoiceAnnouncementSettingsView(settings: settings)) {
                            HStack {
                                Text("Voice Announcement Settings")
                                if !settings.voiceAnnouncementsEnabled {
                                    Text("(Off)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(!settings.voiceAnnouncementsEnabled)
                        // Moved Alert Sound picker here for better organization
                        NavigationLink("Alert Sound", destination: AlertSoundsView(settings: settings))
                        Button("Test Alert") {
                            // Play both sound and voice announcement for preview
                            AudioServicesPlaySystemSound(settings.selectedAlertSound.systemSoundID)
                            let timerName = settings.legacyTimersAsBBQTimers.first?.name ?? "Test"
                            let message = "\(timerName) timer is complete."
                            directAnnouncement(message: message, settings: settings)
                            showTestPlayed = true
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                showTestPlayed = false
                            }
                        }
                        .foregroundColor(.blue)
                        .accessibilityLabel("Test both sound and voice announcement")
                    }

                    // Display & Accessibility
                    Section(header: Text("Display & Accessibility")) {
                        Toggle("Compact Display Mode", isOn: $settings.compactMode)
                            .tint(.blue)
                        Text(settings.compactMode ? "Compact mode saves space for more timers" : "Large display mode enabled for better visibility")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    // Timer Customization & Advanced
                    Section(header: Text("Timer Customization")) {
                        // Removed Alert Sound picker from here (now in Alerts & Sounds section)
                        NavigationLink("Temperature Monitoring (Coming Soon)", destination: Text("Temperature monitoring - Coming Soon"))
                        NavigationLink("Recipe Integration (Coming Soon)", destination: Text("Recipe integration - Coming Soon"))
                        NavigationLink("Cloud Sync (Coming Soon)", destination: Text("Cloud sync - Coming Soon"))
                    }

                    // Thank you message for premium users
                    if settings.isPremiumUser {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Premium Unlocked")
                                    .bold()
                            }
                            Text("Thank you for supporting GrillTime Pro!")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    // DEBUG: Toggle for premium status (for testing only)
                    Section(header: Text("Debug")) {
                        Toggle(isOn: Binding(
                            get: { settings.isPremiumUser },
                            set: { newValue in
                                settings.isPremiumUser = newValue
                                settings.save()
                            }
                        )) {
                            Text("[DEBUG] Premium Features Enabled")
                                .foregroundColor(.red)
                        }
                    }

                    // Add a button to show onboarding again for testing
                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasOnboarded")
                    }) {
                        Text("Show Onboarding Again")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Settings")
                .navigationBarItems(trailing: Button("Done") {
                    settings.save()
                    showSettingsSaved = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showSettingsSaved = false
                        dismiss()
                    }
                })
                .sheet(isPresented: $showPremiumUpgrade) {
                    CustomPaywallView(dismissAction: { showPremiumUpgrade = false }, settings: settings)
                }
                if showSettingsSaved {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Settings Saved!")
                                .font(.headline)
                                .padding()
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
                if showTestPlayed {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Test Played!")
                                .font(.headline)
                                .padding()
                                .background(Color.blue.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
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
    @State private var showTimerSaved = false
    @State private var showTimerDeleted = false
    
    var body: some View {
        ZStack {
            List {
                // --- Instructional text for users ---
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You can rename timers to match what you're cooking, like 'Ribeye' or 'Veggies', or leave the default names.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Text("Preset 1 is for the main flip time. Preset 2 is for a quick extension—usually one more minute.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
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
                            deleteTimerWithFeedback(index: index)
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
                CustomPaywallView(dismissAction: { showPremiumUpgrade = false }, settings: settings)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it appears on top
            }
            // --- Feedback overlays for add/edit/delete ---
            if showTimerSaved {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Timer Saved!")
                            .font(.headline)
                            .padding()
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(2)
            }
            if showTimerDeleted {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Timer Deleted!")
                            .font(.headline)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .confirmationDialog(
            "Delete Timer",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let index = timerToDelete {
                    deleteTimerWithFeedback(index: index)
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
                // Timer name as a button with pencil icon
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
                    HStack(spacing: 6) {
                        Text(timer.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
                // Chevron to indicate tap/edit
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
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
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.7))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            HStack {
                Text("Presets:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(TimeFormatter.timeString(from: timer.preset1))
                    .font(.subheadline)
                Text("|")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(TimeFormatter.timeString(from: timer.preset2))
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
    }
    
    private var addTimerSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Timer Details")) {
                    TextField("Timer Name", text: $newTimerName)
                        .autocapitalization(.words)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.vertical, 4)
                    
                    if !showPreset1Picker && !showPreset2Picker {
                        Button(action: {
                            showPreset1Picker = true
                        }) {
                            HStack {
                                Text("Preset 1")
                                Spacer()
                                Text(TimeFormatter.timeString(from: tempPreset1))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Button(action: {
                            showPreset2Picker = true
                        }) {
                            HStack {
                                Text("Preset 2")
                                Spacer()
                                Text(TimeFormatter.timeString(from: tempPreset2))
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
                                .font(.headline)
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
                                .font(.headline)
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
                    saveTimerWithFeedback()
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
            _ = settings.addTimer(
                name: newTimerName,
                preset1: tempPreset1,
                preset2: tempPreset2
            )
        }
        
        // Save changes
        settings.save()
    }
    
    // Helper function to save timer and show feedback
    private func saveTimerWithFeedback() {
        saveTimer()
        showTimerSaved = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showTimerSaved = false
        }
    }
    
    // Helper function to delete timer and show feedback
    private func deleteTimerWithFeedback(index: Int) {
        settings.removeTimer(at: index)
        showTimerDeleted = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showTimerDeleted = false
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
                .font(.headline)
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
                    Text(TimeFormatter.timeString(from: preset1))
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
                        Text(TimeFormatter.timeString(from: preset1))
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
                            .font(.headline)
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
                        Text(TimeFormatter.timeString(from: preset2))
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
                    Text(TimeFormatter.timeString(from: preset2))
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
    @State private var showPremiumUpgrade = false
    @StateObject private var bundledSoundsManager = BundledSoundsManager()
    @State private var selectedBundledSoundID: UUID? = nil
    @State private var expandedCategory: String? = nil
    @State private var showSaveFeedback = false
    
    init(settings: Settings) {
        self.settings = settings
        // Initialize with the currently selected sound
        _selectedSound = State(initialValue: settings.selectedAlertSound)
        
        // Initialize with the currently selected bundled sound
        _selectedBundledSoundID = State(initialValue: settings.selectedBundledSoundID)
    }
    
    var body: some View {
        ZStack {
            List {
                // Show premium upgrade banner for non-premium users
                if !settings.isPremiumUser {
                    Section {
                        Button(action: {
                            showPremiumUpgrade = true
                        }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium")
                                    .bold()
                                Spacer()
                                Text("Unlock All Sounds")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // System Sounds Section - always visible
                Section(header: Text("System Sounds")) {
                    ForEach(Settings.AlertSound.standardSounds) { sound in
                        systemSoundRow(sound: sound)
                    }
                }
                
                // Premium Sounds - With categorized list
                Section(header:
                    HStack(spacing: 6) {
                        Text("Premium Sounds")
                            .font(.headline)
                        if !settings.isPremiumUser {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .font(.headline)
                                .padding(.bottom, 1)
                        }
                    }
                ) {
                    if !settings.isPremiumUser {
                        Button(action: { showPremiumUpgrade = true }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium to unlock all sounds")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        if bundledSoundsManager.categories.isEmpty {
                            Text("No premium sounds available")
                                .foregroundColor(.secondary)
                                .italic()
                            // Debug information
                            Text("Debug: \(bundledSoundsManager.allSounds.count) sounds loaded")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            // For each category, show a sub-section header and its sounds
                            ForEach(bundledSoundsManager.categories, id: \.self) { category in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(category)
                                        .font(.headline)
                                        .padding(.top, 8)
                                    ForEach(bundledSoundsManager.sounds(in: category)) { sound in
                                        bundledSoundRow(sound: sound)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Custom Sounds Section
                Section(header: Text("Custom Sounds")) {
                    if !settings.isPremiumUser {
                        Button(action: { showPremiumUpgrade = true }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium to add custom sounds")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        NavigationLink(destination: CustomSoundsView(settings: settings)) {
                            Text("Manage Custom Sounds")
                        }
                    }
                }
                
                // About Section
                Section(header: Text("About Alert Sounds")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Different sounds can help you identify which timer is complete when multiple timers are running.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        if !settings.isPremiumUser {
                            HStack {
                                Text("Upgrade to premium to unlock all sounds")
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
            .onAppear {
                // Initialize selection based on current settings
                if let bundledID = settings.selectedBundledSoundID {
                    selectedBundledSoundID = bundledID
                    selectedSound = .system
                    
                    // Find and expand the category containing the selected sound
                    if let sound = bundledSoundsManager.getSound(with: bundledID) {
                        expandedCategory = sound.category
                    }
                }
            }
            
            // Show premium upgrade overlay when needed
            if showPremiumUpgrade {
                CustomPaywallView(dismissAction: { showPremiumUpgrade = false }, settings: settings)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it appears on top
            }
            // --- Overlay for save feedback ---
            if showSaveFeedback {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Selection Saved!")
                            .font(.headline)
                            .padding()
                            .background(Color.green.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
    }
    
    private func systemSoundRow(sound: Settings.AlertSound) -> some View {
        Button(action: {
            selectedBundledSoundID = nil
            selectedSound = sound
            playSystemSound(sound: sound)
            // Auto-save selection
            settings.deselectBundledSound()
            settings.deselectCustomSound()
            settings.selectedAlertSound = sound
            settings.save()
            // Feedback
            showSaveFeedback = true
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                showSaveFeedback = false
            }
        }) {
            HStack {
                Text(sound.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedSound == sound && selectedBundledSoundID == nil {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    playSystemSound(sound: sound)
                }) {
                    Image(systemName: "play.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2) // Add consistent padding
    }
    
    private func bundledSoundRow(sound: BundledSoundsManager.BundledSound) -> some View {
        Button(action: {
            if !settings.isPremiumUser {
                showPremiumUpgrade = true
                audioPlayer?.stop()
                audioPlayer = bundledSoundsManager.playSound(with: sound.id)
            } else {
                selectedBundledSoundID = sound.id
                selectedSound = .system
                audioPlayer?.stop()
                audioPlayer = bundledSoundsManager.playSound(with: sound.id)
                // Auto-save selection
                settings.selectBundledSound(id: sound.id)
                settings.save()
                // Feedback
                showSaveFeedback = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    showSaveFeedback = false
                }
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.displayName)
                        .font(.body)
                        .foregroundColor(!settings.isPremiumUser ? .gray : .primary)
                    
                    if !sound.description.isEmpty {
                        Text(sound.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let selectedID = selectedBundledSoundID, selectedID == sound.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                
                if !settings.isPremiumUser {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.footnote)
                } else {
                    Button(action: {
                        audioPlayer?.stop()
                        audioPlayer = bundledSoundsManager.playSound(with: sound.id)
                    }) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .disabled(!settings.isPremiumUser)
        .contentShape(Rectangle())
        .padding(.vertical, 6) // Increased padding for better spacing
        .background(Color(UIColor.systemBackground))
    }
    
    private func playSystemSound(sound: Settings.AlertSound) {
        // Clear any custom sound selection when selecting a system sound
        if settings.isUsingCustomSound {
            settings.deselectCustomSound()
        }
        
        // Clear any bundled sound selection
        if settings.isUsingBundledSound {
            settings.deselectBundledSound()
        }
        
        // Use AudioServices for system sounds
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
}

// Voice Announcement Settings View
struct VoiceAnnouncementSettingsView: View {
    @ObservedObject var settings: Settings
    @State private var customMessage: String
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoiceIndex: Int = 0
    
    init(settings: Settings) {
        self.settings = settings
        _customMessage = State(initialValue: settings.customAnnouncementMessage)
        let voices = settings.availableVoices()
        _availableVoices = State(initialValue: voices)
        let initialIndex = voices.firstIndex(where: { $0.identifier == settings.selectedVoiceIdentifier }) ?? 0
        _selectedVoiceIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Customization"), footer: Text("This message will be spoken when your timer completes.")) {
                HStack {
                    TextField("Custom announcement message", text: $customMessage)
                        .onChange(of: customMessage) { newValue in
                            settings.customAnnouncementMessage = newValue
                            settings.save()
                        }
                        .accessibilityLabel("Custom announcement message")
                    Button(action: {
                        // Preview the custom message
                        directAnnouncement(message: customMessage, settings: settings)
                    }) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Preview announcement message")
                }
                Button(action: {
                    // Reset to default message
                    customMessage = "Your timer has completed"
                    settings.customAnnouncementMessage = customMessage
                    settings.save()
                }) {
                    Text("Reset to Default Message")
                        .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Options"), footer: Text("Announcements can be limited to play only when headphones or AirPods are connected.")) {
                Toggle("Announce only when AirPods/headphones connected", isOn: $settings.announceOnlyWithHeadphones)
                if settings.announceOnlyWithHeadphones {
                    HStack {
                        Text("Current status")
                        Spacer()
                        Text(settings.hasBluetoothHeadphonesConnected ? "Headphones connected" : "No headphones detected")
                            .foregroundColor(settings.hasBluetoothHeadphonesConnected ? .green : .secondary)
                        Button(action: {
                            settings.objectWillChange.send()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.footnote)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityLabel("Refresh headphone status")
                    }
                }
            }
            
            Section(header: Text("Voice Selection"), footer: Text("Choose the voice for your announcements.")) {
                if availableVoices.isEmpty {
                    Text("No voices available")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Voice", selection: $selectedVoiceIndex) {
                        ForEach(0..<availableVoices.count, id: \.self) { index in
                            let voice = availableVoices[index]
                            Text("\(voice.name) (\(voice.language))")
                                .tag(index)
                        }
                    }
                    .onChange(of: selectedVoiceIndex) { newValue in
                        if availableVoices.indices.contains(newValue) {
                            settings.selectedVoiceIdentifier = availableVoices[newValue].identifier
                            settings.save()
                        }
                    }
                    .accessibilityLabel("Select voice for announcements")
                    HStack {
                        Text("Language")
                        Spacer()
                        if availableVoices.indices.contains(selectedVoiceIndex) {
                            Text(availableVoices[selectedVoiceIndex].language)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Test Speech"), footer: Text("Test how your announcement will sound.")) {
                Button(action: {
                    print("Test announcement button pressed")
                    let timerName = settings.legacyTimersAsBBQTimers.first?.name ?? "Test"
                    let message = "\(timerName) timer is complete."
                    directAnnouncement(message: message, settings: settings)
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Text("Test Voice Announcement")
                    }
                    .foregroundColor(.blue)
                }
                .accessibilityLabel("Test voice announcement")
                Button(action: {
                    print("Ultra basic test")
                    AudioServicesPlaySystemSound(1005)
                    let utterance = AVSpeechUtterance(string: "Testing")
                    utterance.rate = 0.5
                    utterance.volume = 1.0
                    let synth = AVSpeechSynthesizer()
                    synth.speak(utterance)
                    TestSpeech.shared.synthesizer = synth
                }) {
                    HStack {
                        Image(systemName: "bell")
                        Text("Ultra Basic Test")
                    }
                    .foregroundColor(.orange)
                }
                .accessibilityLabel("Ultra basic test announcement")
            }
            
            Section(header: Text("About Voice Announcements"), footer: Text("The announcement will include the timer name and your custom message. You can set announcements to play only when headphones or AirPods are connected.")) {
                Text("Voice announcements are played when a timer completes.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Voice Announcements")
        .onDisappear {
            // Save any changes when view disappears
            settings.customAnnouncementMessage = customMessage
            settings.save()
        }
    }
}

// Simple class to retain the speech synthesizer
class TestSpeech {
    static let shared = TestSpeech()
    var synthesizer: AVSpeechSynthesizer?
} 