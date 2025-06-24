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
} 