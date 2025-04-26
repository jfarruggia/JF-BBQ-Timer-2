import SwiftUI
import AVFoundation

struct CustomSoundsView: View {
    @ObservedObject var settings: Settings
    @StateObject private var soundsManager = CustomSoundsManager()
    @State private var showDocumentPicker = false
    @State private var showRenameAlert = false
    @State private var selectedSoundID: UUID? = nil
    @State private var newSoundName = ""
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        List {
            Section(header: Text("Custom Sounds")) {
                if soundsManager.customSounds.isEmpty {
                    Text("No custom sounds added yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(soundsManager.customSounds) { sound in
                        customSoundRow(sound)
                    }
                    .onDelete(perform: deleteSound)
                }
                
                Button(action: {
                    if settings.isPremiumUser {
                        showDocumentPicker = true
                    } else {
                        // Show premium upgrade dialog
                        // This would connect to your existing premium upgrade flow
                    }
                }) {
                    Label("Add Custom Sound", systemImage: "plus.circle")
                }
                .disabled(!settings.isPremiumUser)
            }
            
            if !settings.isPremiumUser {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Custom sounds are a premium feature")
                            .fontWeight(.medium)
                        
                        Text("Unlock premium to add your own custom sounds")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
                }
            }
            
            Section(header: Text("About Custom Sounds")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your own sound files from Files, iCloud Drive, or other sources.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Supported formats: MP3, WAV, M4A, AIFF")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Custom sounds should be less than 30 seconds long.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Custom Sounds")
        .onDisappear {
            // Stop any playing audio when leaving
            audioPlayer?.stop()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerViewController(isPresented: $showDocumentPicker) { url in
                // Import the selected sound file
                if let soundId = soundsManager.importSound(from: url) {
                    // Optionally show rename dialog
                    selectedSoundID = soundId
                    if let sound = soundsManager.getSound(with: soundId) {
                        newSoundName = sound.name
                        showRenameAlert = true
                    }
                }
            }
        }
        .alert("Rename Sound", isPresented: $showRenameAlert) {
            TextField("Sound Name", text: $newSoundName)
            Button("OK") {
                if let id = selectedSoundID {
                    soundsManager.renameSound(with: id, to: newSoundName)
                }
                showRenameAlert = false
            }
            Button("Cancel", role: .cancel) {
                showRenameAlert = false
            }
        }
    }
    
    // Custom sound row with play button and selection
    private func customSoundRow(_ sound: CustomSoundsManager.CustomSound) -> some View {
        HStack {
            Button(action: {
                if let id = settings.selectedCustomSoundID, id == sound.id {
                    // Already selected - do nothing
                } else {
                    // Select this sound
                    settings.selectCustomSound(id: sound.id)
                    
                    // Play a preview
                    audioPlayer?.stop()
                    audioPlayer = soundsManager.playSound(with: sound.id)
                }
            }) {
                HStack {
                    Text(sound.name)
                    Spacer()
                    
                    if let selectedID = settings.selectedCustomSoundID, selectedID == sound.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: {
                        audioPlayer?.stop()
                        audioPlayer = soundsManager.playSound(with: sound.id)
                    }) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Button(action: {
                        selectedSoundID = sound.id
                        newSoundName = sound.name
                        showRenameAlert = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .contentShape(Rectangle())
        }
    }
    
    // Delete a sound
    private func deleteSound(at offsets: IndexSet) {
        for index in offsets {
            let sound = soundsManager.customSounds[index]
            
            // If this is the selected sound, deselect it
            if let selectedID = settings.selectedCustomSoundID, selectedID == sound.id {
                settings.deselectCustomSound()
            }
            
            // Delete the sound
            soundsManager.deleteSound(with: sound.id)
        }
    }
}
