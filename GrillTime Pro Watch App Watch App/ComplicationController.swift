//
//  ComplicationController.swift
//  GrillTime Pro Watch App Watch App
//
//  Manages the Watch complication that displays the timer finishing soonest
//

import ClockKit
import SwiftUI

/// Shared data source for the complication - stores the soonest finishing timer
final class ComplicationDataSource {
    static let shared = ComplicationDataSource()
    
    // The timer that finishes soonest (if any are running)
    private(set) var soonestTimer: (name: String, remainingSeconds: Int)? = nil
    private(set) var lastUpdate: Date = Date()
    
    private init() {}
    
    /// Updates the complication data with the soonest finishing timer
    func updateSoonestTimer(from timers: [WatchTimersModel.Row], snapshotDate: Date?) {
        // Find all running timers
        let runningTimers = timers.filter { $0.state == "running" }
        
        // Find the one with the least remaining time
        if let soonest = runningTimers.min(by: { $0.remaining < $1.remaining }) {
            soonestTimer = (name: soonest.name, remainingSeconds: soonest.remaining)
        } else {
            soonestTimer = nil
        }
        
        lastUpdate = snapshotDate ?? Date()
        
        // Reload all complications so they update
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
    
    /// Calculates the effective remaining time accounting for time since last snapshot
    func effectiveRemaining() -> Int? {
        guard let timer = soonestTimer else { return nil }
        let elapsed = Int(Date().timeIntervalSince(lastUpdate))
        return max(0, timer.remainingSeconds - elapsed)
    }
}

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "GrillTimeTimer",
                displayName: "GrillTime Timer",
                supportedFamilies: [.modularMedium] // Medium complication only
            )
        ]
        handler(descriptors)
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(Date())
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Extend timeline 24 hours into the future
        handler(Date().addingTimeInterval(24 * 60 * 60))
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        guard complication.family == .modularMedium else {
            handler(nil)
            return
        }
        
        let template = createTemplate()
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // For simplicity, we'll just update every minute
        // In a production app, you might want to update more frequently
        var entries: [CLKComplicationTimelineEntry] = []
        let calendar = Calendar.current
        
        for i in 0..<min(limit, 60) { // Up to 60 entries (1 hour)
            if let nextDate = calendar.date(byAdding: .minute, value: i, to: date) {
                let template = createTemplate(for: nextDate)
                let entry = CLKComplicationTimelineEntry(date: nextDate, complicationTemplate: template)
                entries.append(entry)
            }
        }
        
        handler(entries.isEmpty ? nil : entries)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // Create a sample template for the complication picker
        let template = createSampleTemplate()
        handler(template)
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for date: Date = Date()) -> CLKComplicationTemplate {
        let dataSource = ComplicationDataSource.shared
        
        guard let timer = dataSource.soonestTimer else {
            // No running timers - show placeholder
            return createEmptyTemplate()
        }
        
        // Calculate effective remaining time accounting for time elapsed since last update
        // For future dates, subtract the time difference
        let timeSinceUpdate = Int(date.timeIntervalSince(dataSource.lastUpdate))
        let effectiveRemaining = max(0, timer.remainingSeconds - timeSinceUpdate)
        
        // Format time as MM:SS
        let minutes = effectiveRemaining / 60
        let seconds = effectiveRemaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)
        
        // Create the template with timer name and time
        let template = CLKComplicationTemplateModularMediumSimpleText()
        template.headerTextProvider = CLKSimpleTextProvider(text: timer.name)
        template.bodyTextProvider = CLKSimpleTextProvider(text: timeString)
        
        return template
    }
    
    private func createEmptyTemplate() -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularMediumSimpleText()
        template.headerTextProvider = CLKSimpleTextProvider(text: "GrillTime")
        template.bodyTextProvider = CLKSimpleTextProvider(text: "No timers")
        return template
    }
    
    private func createSampleTemplate() -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularMediumSimpleText()
        template.headerTextProvider = CLKSimpleTextProvider(text: "Ribeye")
        template.bodyTextProvider = CLKSimpleTextProvider(text: "5:30")
        return template
    }
}

