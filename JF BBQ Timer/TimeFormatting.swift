import Foundation

public struct TimeFormatter {
    /// Formats a time interval in seconds into a string representation.
    /// - Parameter seconds: The number of seconds to format
    /// - Returns: A string in the format "HH:mm:ss" always showing hours, minutes, and seconds
    public static func timeString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        
        // Always show hours, minutes, and seconds in HH:mm:ss format
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// "MM:SS" for durations known to be at most an hour (the preset steppers
    /// cap at 3600 s, shown as "60:00"). Total minutes, no hours field — the
    /// full HH:mm:ss made the Manage Timers rows wrap on narrower phones.
    public static func compactTimeString(from seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }
}