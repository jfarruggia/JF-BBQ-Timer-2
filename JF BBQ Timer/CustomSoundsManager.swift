import Foundation
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

// Class to manage custom sounds
class CustomSoundsManager: ObservableObject {
    // All custom sounds
    @Published var customSounds: [CustomSound] = []
    
    // The directory where custom sounds are stored
    private let customSoundsDirectory: URL
    
    // Structure to represent a custom sound
    struct CustomSound: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var filename: String
        
        // URL to the sound file
        var fileURL: URL? {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            return documentsDirectory?.appendingPathComponent("CustomSounds").appendingPathComponent(filename)
        }
        
        // Check if the file exists
        var fileExists: Bool {
            guard let url = fileURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        
        static func == (lhs: CustomSound, rhs: CustomSound) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    init() {
        // Get the documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create a CustomSounds directory inside documents if it doesn't exist
        customSoundsDirectory = documentsDirectory.appendingPathComponent("CustomSounds")
        
        do {
            // Create the directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: customSoundsDirectory.path) {
                try FileManager.default.createDirectory(at: customSoundsDirectory, withIntermediateDirectories: true)
            }
            
            // Load saved custom sounds
            loadCustomSounds()
        } catch {
            print("Error setting up custom sounds directory: \(error)")
        }
    }
    
    // Load custom sounds from UserDefaults
    private func loadCustomSounds() {
        if let data = UserDefaults.standard.data(forKey: "customSounds"),
           let decodedSounds = try? JSONDecoder().decode([CustomSound].self, from: data) {
            self.customSounds = decodedSounds
        }
    }
    
    // Save custom sounds to UserDefaults
    private func saveCustomSounds() {
        if let encodedData = try? JSONEncoder().encode(customSounds) {
            UserDefaults.standard.set(encodedData, forKey: "customSounds")
        }
    }
    
    // Import a sound file from a URL
    func importSound(from sourceURL: URL, name: String? = nil) -> UUID? {
        do {
            // Generate a unique filename based on timestamp and random number
            let uniqueFilename = "custom_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 1000...9999)).\(sourceURL.pathExtension)"
            let destinationURL = customSoundsDirectory.appendingPathComponent(uniqueFilename)
            
            // Copy the file to our directory
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            // Create a new custom sound
            let soundName = name ?? sourceURL.deletingPathExtension().lastPathComponent
            let newSound = CustomSound(id: UUID(), name: soundName, filename: uniqueFilename)
            
            // Add to our list
            customSounds.append(newSound)
            
            // Save the updated list
            saveCustomSounds()
            
            return newSound.id
        } catch {
            print("Error importing sound: \(error)")
            return nil
        }
    }
    
    // Delete a custom sound
    func deleteSound(with id: UUID) {
        guard let index = customSounds.firstIndex(where: { $0.id == id }),
              let fileURL = customSounds[index].fileURL else {
            return
        }
        
        do {
            // Delete the file
            try FileManager.default.removeItem(at: fileURL)
            
            // Remove from array
            customSounds.remove(at: index)
            
            // Save the updated list
            saveCustomSounds()
        } catch {
            print("Error deleting sound: \(error)")
        }
    }
    
    // Rename a custom sound
    func renameSound(with id: UUID, to newName: String) {
        guard let index = customSounds.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        // Update the name
        customSounds[index].name = newName
        
        // Save the updated list
        saveCustomSounds()
    }
    
    // Get a custom sound by ID
    func getSound(with id: UUID) -> CustomSound? {
        return customSounds.first { $0.id == id }
    }
    
    // Play a custom sound for preview
    func playSound(with id: UUID) -> AVAudioPlayer? {
        guard let sound = getSound(with: id),
              let url = sound.fileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            return player
        } catch {
            print("Error playing sound: \(error)")
            return nil
        }
    }
    
    // Supported file types for import
    static var supportedAudioTypes: [UTType] {
        [UTType.audio, UTType.mp3, UTType.wav, UTType.aiff, UTType.mpeg4Audio]
    }
}

// DocumentPicker for selecting custom sounds
struct DocumentPickerViewController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: CustomSoundsManager.supportedAudioTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerViewController
        
        init(_ parent: DocumentPickerViewController) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Get persistent access to the file
            guard url.startAccessingSecurityScopedResource() else { return }
            
            // Call the callback with the selected URL
            parent.onPick(url)
            
            // Release access to the file
            url.stopAccessingSecurityScopedResource()
            
            // Dismiss the picker
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}
