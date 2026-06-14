import Foundation
import SwiftUI

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

struct BBQTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var preset1: Int  // Seconds for preset 1
    var preset2: Int  // Seconds for preset 2
    var isVisible: Bool

    init(id: UUID = UUID(), name: String, preset1: Int, preset2: Int, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.preset1 = preset1
        self.preset2 = preset2
        self.isVisible = isVisible
    }

    static func == (lhs: BBQTimer, rhs: BBQTimer) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.preset1 == rhs.preset1 &&
               lhs.preset2 == rhs.preset2 &&
               lhs.isVisible == rhs.isVisible
    }
}

enum TimerType {
    case regular, preheat
}

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

struct Theme {
    var backgroundColor: Color
    var accentColor: Color
    var textColor: Color

    static let defaultTheme = Theme(
        backgroundColor: Color("TimerBackground"),
        accentColor: Color("TimerAccent"),
        textColor: Color.white
    )

    static let fireTheme = Theme(
        backgroundColor: Color("TimerBackground"),
        accentColor: Color("TimerRed"),
        textColor: Color.white
    )
}
