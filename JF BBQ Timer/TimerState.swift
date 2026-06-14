import Foundation
import AVFoundation
import UIKit
import SwiftUI
import UserNotifications

class AlertState: ObservableObject {
    @Published var isPresented: Bool
    @Published var showPreheatAlert: Bool {
        didSet {
            debugLog("PreheatAlertState changed from \(oldValue) to \(showPreheatAlert)")
            if showPreheatAlert {
                startHapticTimer()
            } else if hapticTimer != nil {
                stopHapticTimer()
            }
        }
    }

    private var hapticTimer: Timer?
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var hapticCounter = 0
    var hapticsEnabled: Bool = true

    init() {
        self.isPresented = false
        self.showPreheatAlert = false
        self.hapticCounter = 0
        self.hapticTimer = nil
        notificationGenerator.prepare()
        heavyGenerator.prepare()
        mediumGenerator.prepare()
    }

    func triggerNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        guard hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(type)
    }

    private func startHapticTimer() {
        guard hapticsEnabled else { return }
        notificationGenerator.prepare()
        heavyGenerator.prepare()
        mediumGenerator.prepare()
        triggerHapticFeedback()
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.triggerHapticFeedback()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.hapticTimer != nil { self.stopHapticTimer() }
        }
    }

    private func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        hapticCounter = 0
    }

    private func triggerHapticFeedback() {
        guard hapticsEnabled else { return }
        hapticCounter += 1
        if hapticCounter % 2 == 0 {
            heavyGenerator.impactOccurred()
        } else {
            mediumGenerator.impactOccurred()
        }
    }
}

class TimerState: ObservableObject {
    let id: UUID
    @Published var intervalTime: TimeInterval
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isCompleted: Bool = false

    private var settings: Settings?
    private var intervalTimer: Timer?
    private var elapsedTimer: Timer?
    private var onCompleteAction: (() -> Void)?
    private var completionTimer: Timer?
    private var initialIntervalTime: TimeInterval
    private var targetDate: Date?
    private var notificationIdentifier: String?

    init(id: UUID, interval: TimeInterval, settings: Settings? = nil) {
        self.id = id
        self.intervalTime = interval
        self.initialIntervalTime = interval
        self.settings = settings
    }

    func updateSettings(_ newSettings: Settings) {
        debugLog("TimerState (\(self.id)): Updating settings reference")
        let previousSetting = self.settings?.selectedAlertSound.displayName ?? "nil"
        self.settings = newSettings
        let newSetting = self.settings?.selectedAlertSound.displayName ?? "nil"
        debugLog("TimerState (\(self.id)): Sound changed from \(previousSetting) to \(newSetting)")
    }

    func reset() {
        stopIntervalTimer()
        stopElapsedTimer()
        completionTimer?.invalidate()
        completionTimer = nil
        isRunning = false
        isCompleted = false
        elapsedTime = 0
        intervalTime = initialIntervalTime
        targetDate = nil
        cancelPendingNotification()
        objectWillChange.send()
    }

    private func createAndStartIntervalTimer() {
        debugLog("Creating interval timer")
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.createAndStartIntervalTimer()
            }
            return
        }
        self.intervalTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.intervalTime > 0 {
                self.intervalTime -= 1
                debugLog("Interval timer tick: \(self.intervalTime)")
                self.objectWillChange.send()
            } else {
                debugLog("Interval timer complete")
                self.stopIntervalTimer()
                self.isCompleted = true
                self.objectWillChange.send()
                if let settingsObj = self.settings {
                    debugLog("TimerState (\(self.id)): Timer complete with settings: \(settingsObj.selectedAlertSound.displayName)")
                } else {
                    debugLog("TimerState (\(self.id)): ⚠️ Timer complete but settings is nil")
                }
                self.onCompleteAction?()
                DispatchQueue.main.async {
                    if let settingsObj = self.settings, settingsObj.hapticsEnabled {
                        switch settingsObj.hapticIntensity {
                        case .light:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                        case .medium:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                            let heavy = UIImpactFeedbackGenerator(style: .heavy)
                            heavy.impactOccurred(intensity: 0.9)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                let medium = UIImpactFeedbackGenerator(style: .medium)
                                medium.impactOccurred(intensity: 0.9)
                            }
                        case .strong:
                            let notif = UINotificationFeedbackGenerator()
                            notif.notificationOccurred(.success)
                            let heavy1 = UIImpactFeedbackGenerator(style: .heavy)
                            heavy1.impactOccurred(intensity: 1.0)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                let heavy2 = UIImpactFeedbackGenerator(style: .heavy)
                                heavy2.impactOccurred(intensity: 1.0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                let medium = UIImpactFeedbackGenerator(style: .medium)
                                medium.impactOccurred(intensity: 0.9)
                            }
                        }
                    }
                }
            }
        }
        if let timer = self.intervalTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func setIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.initialIntervalTime = time
            self.objectWillChange.send()
        }
    }

    func setCurrentIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.intervalTime = time
            self.objectWillChange.send()
        }
    }

    func setElapsedTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = time
            self.objectWillChange.send()
        }
    }

    func start(onComplete: @escaping () -> Void) {
        debugLog("Starting timer with interval: \(intervalTime)")
        intervalTimer?.invalidate()
        intervalTimer = nil
        self.isRunning = false
        self.isCompleted = false
        self.onCompleteAction = onComplete
        stopIntervalTimer()
        guard intervalTime > 0 else {
            debugLog("⚠️ Cannot start timer - interval time is \(intervalTime)")
            return
        }
        targetDate = Date().addingTimeInterval(intervalTime)
        scheduleCompletionNotification(after: intervalTime)
        startElapsedTimerIfNeeded()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            self.objectWillChange.send()
            debugLog("Timer started - isRunning set to true")
            self.createAndStartIntervalTimer()
        }
    }

    private func startElapsedTimerIfNeeded() {
        guard elapsedTimer == nil else {
            debugLog("Elapsed timer already running, continuing it")
            return
        }
        debugLog("Starting elapsed timer")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.elapsedTime += 1
                    debugLog("Elapsed timer tick: \(self.elapsedTime)")
                    self.objectWillChange.send()
                }
            }
            if let timer = self.elapsedTimer {
                RunLoop.main.add(timer, forMode: .common)
                debugLog("Elapsed timer added to RunLoop")
            }
        }
    }

    private func stopIntervalTimer() {
        intervalTimer?.invalidate()
        intervalTimer = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRunning = false
            self.objectWillChange.send()
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    func stop() {
        stopIntervalTimer()
        cancelPendingNotification()
        targetDate = nil
    }

    func resetToZero() {
        stopIntervalTimer()
        stopElapsedTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = 0
            self.intervalTime = self.initialIntervalTime
            self.isRunning = false
            self.objectWillChange.send()
            debugLog("Timer reset to zero. Interval time is now: \(self.intervalTime)")
        }
        cancelPendingNotification()
        targetDate = nil
    }

    func playSound() {
        let defaultSoundID: SystemSoundID = 1005
        if let settingsObj = self.settings, settingsObj.soundEnabled {
            debugLog("TimerState (\(self.id)): Playing timer completion sound with announcement")
            settingsObj.playTimerCompletionWithAnnouncement(timerId: self.id)
        } else {
            debugLog("TimerState (\(self.id)): ⚠️ Settings reference is nil or sound disabled")
            AudioServicesPlaySystemSound(defaultSoundID)
        }
    }

    func resetCompletionState() {
        debugLog("[DEBUG] TimerState.resetCompletionState() called for timer: \(id)")
        isCompleted = false
        objectWillChange.send()
    }

    // MARK: - Background resync helpers

    func resyncAfterForeground() {
        guard let target = targetDate else { return }
        let remaining = target.timeIntervalSinceNow
        if remaining <= 0 {
            completeNow()
        } else {
            setCurrentIntervalTime(remaining)
            if isRunning && intervalTimer == nil {
                createAndStartIntervalTimer()
            }
        }
    }

    func completeNow() {
        stopIntervalTimer()
        isRunning = false
        isCompleted = true
        objectWillChange.send()
        cancelPendingNotification()
        onCompleteAction?()
    }

    // MARK: - Local notification scheduling

    private func scheduleCompletionNotification(after interval: TimeInterval) {
        let identifier = "timer-\(id.uuidString)"
        notificationIdentifier = identifier
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(displayName()) timer is complete."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌ Failed to schedule completion notification: \(error)")
            } else {
                debugLog("🗓️ Scheduled completion notification for timer \(self.id) in \(Int(interval))s")
            }
        }
    }

    private func cancelPendingNotification() {
        if let id = notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            notificationIdentifier = nil
        }
    }

    private func displayName() -> String {
        if let settings = settings {
            if let timer = settings.allTimers.first(where: { $0.id == self.id }) {
                return timer.name
            }
        }
        return "Timer"
    }
}

class TimerStatesManager: ObservableObject {
    @Published var states: [TimerState] = []
    private var settings: Settings?

    init(settings: Settings? = nil) {
        debugLog("TimerStatesManager: Initializing with settings \(settings != nil ? "provided" : "nil")")
        self.settings = settings
    }

    func initializeTimerStates(timers: [BBQTimer]) {
        debugLog("TimerStatesManager: Initializing timer states for \(timers.count) timers")
        debugLog("TimerStatesManager: Current settings reference: \(settings != nil ? "valid" : "nil")")
        if let sound = settings?.selectedAlertSound {
            debugLog("TimerStatesManager: Current alert sound: \(sound.displayName)")
        }
        for state in states { state.stop() }
        states = []
        for timer in timers {
            states.append(TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings))
        }
        debugLog("TimerStatesManager: Created \(states.count) timer states")
    }

    func addTimerState(for timer: BBQTimer) -> TimerState {
        let state = TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings)
        states.append(state)
        return state
    }

    func removeTimerState(for timerId: UUID) {
        if let index = states.firstIndex(where: { $0.id == timerId }) {
            states[index].stop()
            states.remove(at: index)
        }
    }

    func state(for timerId: UUID) -> TimerState? {
        return states.first { $0.id == timerId }
    }

    func syncTimerStates(timers: [BBQTimer]) {
        for timer in timers {
            if state(for: timer.id) == nil {
                _ = addTimerState(for: timer)
            }
        }
        let timerIds = Set(timers.map { $0.id })
        states = states.filter { timerState in
            if timerIds.contains(timerState.id) {
                return true
            } else {
                timerState.stop()
                return false
            }
        }
    }

    func updateSettings(_ settings: Settings) {
        debugLog("TimerStatesManager: Updating settings reference")
        self.settings = settings
        for (index, state) in states.enumerated() {
            debugLog("TimerStatesManager: Updating settings for timer state #\(index)")
            state.updateSettings(settings)
        }
        if settings.isUsingCustomSound {
            debugLog("TimerStatesManager: Using custom sound with ID: \(settings.selectedCustomSoundID?.uuidString ?? "nil")")
        } else {
            debugLog("TimerStatesManager: Using system sound: \(settings.selectedAlertSound.displayName)")
        }
        objectWillChange.send()
    }
}
