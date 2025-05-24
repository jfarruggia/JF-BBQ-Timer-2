import Foundation
import AVFoundation

// A class to manage bundled sounds included with the app
class BundledSoundsManager: ObservableObject {
    // Structure to represent a bundled sound
    struct BundledSound: Identifiable, Codable, Equatable {
        let id: UUID
        let filename: String
        let displayName: String
        let category: String
        let description: String
        
        // Custom decoder init to handle missing ID in JSON
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Generate a UUID if not in the JSON
            if container.contains(.id) {
                id = try container.decode(UUID.self, forKey: .id)
            } else {
                id = UUID()
            }
            
            filename = try container.decode(String.self, forKey: .filename)
            displayName = try container.decode(String.self, forKey: .displayName)
            category = try container.decode(String.self, forKey: .category)
            description = try container.decode(String.self, forKey: .description)
        }
        
        // Manual init for creating instances in code
        init(id: UUID, filename: String, displayName: String, category: String, description: String) {
            self.id = id
            self.filename = filename
            self.displayName = displayName
            self.category = category
            self.description = description
        }
        
        // URL to the sound file
        var fileURL: URL? {
            // Delegate to the manager's helper function
            BundledSoundsManager().resolveFileURL(for: filename)
        }
        
        // Equality check for diffing in SwiftUI
        static func == (lhs: BundledSound, rhs: BundledSound) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    // Sounds organized by category
    @Published var soundsByCategory: [String: [BundledSound]] = [:]
    
    // All categories in the order they should appear
    @Published var categories: [String] = []
    
    // All sounds in a flat list
    @Published var allSounds: [BundledSound] = []
    
    init() {
        print("🎵 BundledSoundsManager: Initializing...")
        loadBundledSounds()
        print("🎵 BundledSoundsManager: Initialization complete. Loaded \(allSounds.count) sounds in \(categories.count) categories")
    }
    
    // Load sounds from the bundled JSON file
    private func loadBundledSounds() {
        // List of possible locations for sound files and metadata
        let possibleDirectories: [URL?] = [
            // 1. App bundle root
            Bundle.main.resourceURL,
            // 2. App bundle Resources/Sounds
            Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds"),
            // 3. App bundle Sounds
            Bundle.main.resourceURL?.appendingPathComponent("Sounds")
        ]
        
        // Try to find the metadata JSON in any of these locations
        var jsonURL: URL? = nil
        for dir in possibleDirectories.compactMap({ $0 }) {
            let candidate = dir.appendingPathComponent("sound_metadata.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                jsonURL = candidate
                print("✅ Found sound_metadata.json at: \(candidate.path)")
                break
            }
        }
        // Fallback: use Bundle's url(forResource:withExtension:)
        if jsonURL == nil {
            if let bundleURL = Bundle.main.url(forResource: "sound_metadata", withExtension: "json") {
                jsonURL = bundleURL
                print("✅ Found sound_metadata.json via Bundle.url: \(bundleURL.path)")
            }
        }
        // If not found, print error and return
        guard let finalJsonURL = jsonURL else {
            print("❌ Could not find sound_metadata.json in any expected location.")
            self.categories = []
            self.allSounds = []
            self.soundsByCategory = [:]
            return
        }
        // Load and decode the JSON
        do {
            let data = try Data(contentsOf: finalJsonURL)
            let decoder = JSONDecoder()
            let sounds = try decoder.decode([BundledSound].self, from: data)
            print("✅ Decoded \(sounds.count) bundled sounds from JSON.")
            self.allSounds = sounds
            // Organize by category
            var categoriesSet = Set<String>()
            var byCategory: [String: [BundledSound]] = [:]
            for sound in sounds {
                categoriesSet.insert(sound.category)
                byCategory[sound.category, default: []].append(sound)
            }
            // Sort categories by priority
            let categoryPriorities: [String: Int] = [
                "For the Faint of Heart": 1,
                "Standard": 2,
                "Get My Attention": 3,
                "Annoying": 4
            ]
            let sortedCategories = Array(categoriesSet).sorted { (cat1, cat2) -> Bool in
                let p1 = categoryPriorities[cat1] ?? Int.max
                let p2 = categoryPriorities[cat2] ?? Int.max
                return p1 < p2
            }
            self.categories = sortedCategories
            self.soundsByCategory = byCategory
            // Print found sound files
            for sound in sounds {
                if let url = resolveFileURL(for: sound.filename) {
                    print("✅ Found sound file: \(sound.filename) at \(url.path)")
                } else {
                    print("❌ Missing sound file: \(sound.filename)")
                }
            }
            // Debug: print number of sounds in each category
            for category in sortedCategories {
                let count = byCategory[category]?.count ?? 0
                print("Category '", category, "' has ", count, " sounds.")
            }
        } catch {
            print("❌ Error decoding bundled sounds: \(error)")
            self.categories = []
            self.allSounds = []
            self.soundsByCategory = [:]
        }
    }
    
    // Helper to resolve a sound file URL using multiple search paths
    private func resolveFileURL(for filename: String) -> URL? {
        let possibleFiles: [URL?] = [
            // 1. App bundle root
            Bundle.main.resourceURL?.appendingPathComponent(filename),
            // 2. App bundle Resources/Sounds
            Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds").appendingPathComponent(filename),
            // 3. App bundle Sounds
            Bundle.main.resourceURL?.appendingPathComponent("Sounds").appendingPathComponent(filename),
            // 4. Bundle resource loading (no subdirectory)
            Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3"),
            // 5. Bundle resource loading (Resources/Sounds)
            Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3", subdirectory: "Resources/Sounds"),
            // 6. Bundle resource loading (Sounds)
            Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3", subdirectory: "Sounds")
        ]
        for url in possibleFiles.compactMap({ $0 }) {
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
    
    // Get all sounds in a specific category
    func sounds(in category: String) -> [BundledSound] {
        return soundsByCategory[category] ?? []
    }
    
    // Play a bundled sound
    func playSound(with id: UUID) -> AVAudioPlayer? {
        guard let sound = getSound(with: id),
              let url = sound.fileURL else {
            return nil
        }
        
        // Use the AudioManager to play the sound
        print("Playing bundled sound: \(sound.displayName)")
        
        if AudioManager.shared.playSound(from: url) {
            // This is a workaround - we need to return something to match the interface
            // but AudioManager now handles the actual player
            do {
                return try AVAudioPlayer(contentsOf: url)
            } catch {
                print("Error creating dummy audio player: \(error)")
            }
        }
        
        return nil
    }
    
    // Fallback method to find sound files if the standard URL approach fails
    private func fallbackFileURL(for filename: String) -> URL? {
        // Try looking in main bundle first
        if let resourcesURL = Bundle.main.resourceURL?.appendingPathComponent("Resources/Sounds") {
            let fileURL = resourcesURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        // Try looking in the Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let resourcesURL = documentsURL.appendingPathComponent("Resources/Sounds")
            let fileURL = resourcesURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        return nil
    }
    
    // Find a sound by filename
    func getSound(withFilename filename: String) -> BundledSound? {
        return allSounds.first { $0.filename == filename }
    }
    
    // Find a sound by ID
    func getSound(with id: UUID) -> BundledSound? {
        return allSounds.first { $0.id == id }
    }
} 