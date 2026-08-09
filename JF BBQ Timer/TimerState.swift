import Foundation
import AVFoundation
import UIKit
import SwiftUI
import UserNotifications
import Combine

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

// MARK: -

extension Notification.Name {
    /// Posted whenever any cook timer starts running (see TimerState.start).
    static let cookTimerDidStart = Notification.Name("cookTimerDidStart")
}

class TimerState: ObservableObject {
    let id: UUID

    // UI display values — updated by the refresh timer every second. Never the source of truth.
    @Published var intervalTime: TimeInterval
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isCompleted: Bool = false

    // --- Sources of truth ---
    // When running: endDate is when the countdown reaches zero.
    // When paused/stopped: remainingAtPause holds the snapshot of remaining time.
    // Elapsed: elapsedStartDate is when the "lit time" clock first started (never cleared by pause).
    private(set) var endDate: Date?
    private var remainingAtPause: TimeInterval
    private var elapsedStartDate: Date?
    // Total duration the current run counts down from — the ring's "full".
    // Set when a fresh duration is established (preset applied / reset), and
    // deliberately left unchanged across pause/resume so the ring stays continuous.
    private(set) var runDuration: TimeInterval

    var initialIntervalTime: TimeInterval
    private var settings: Settings?
    private var refreshTimer: Timer?
    var onCompleteAction: (() -> Void)?
    private var notificationIdentifier: String?

    init(id: UUID, interval: TimeInterval, settings: Settings? = nil) {
        self.id = id
        self.intervalTime = interval
        self.remainingAtPause = interval
        self.initialIntervalTime = interval
        self.runDuration = interval
        self.settings = settings
    }

    // MARK: - Pure testable functions (injectable now)

    /// Remaining countdown time at a given instant.
    func remaining(at now: Date) -> TimeInterval {
        guard let end = endDate else { return remainingAtPause }
        return max(0, end.timeIntervalSince(now))
    }

    /// Total elapsed ("lit") time at a given instant.
    func elapsed(at now: Date) -> TimeInterval {
        guard let start = elapsedStartDate else { return 0 }
        return max(0, now.timeIntervalSince(start))
    }

    /// Fraction of the countdown still remaining at a given instant (0...1).
    /// Drives the progress ring: 1 when full, 0 at completion. Measured against
    /// `runDuration` so pausing and resuming doesn't refill the ring.
    func progress(at now: Date) -> Double {
        guard runDuration > 0 else { return 0 }
        return min(1, max(0, remaining(at: now) / runDuration))
    }

    // MARK: - State transitions

    func start(onComplete: @escaping () -> Void) {
        let starting = remainingAtPause > 0 ? remainingAtPause : initialIntervalTime
        guard starting > 0 else {
            debugLog("⚠️ TimerState (\(id)): Cannot start — no time remaining")
            return
        }

        cancelPendingNotification()
        let now = Date()
        endDate = now.addingTimeInterval(starting)
        remainingAtPause = 0
        if elapsedStartDate == nil { elapsedStartDate = now }
        isRunning = true
        isCompleted = false
        onCompleteAction = onComplete

        scheduleCompletionNotification(at: endDate!)
        startRefreshTimer()

        intervalTime = starting
        objectWillChange.send()
        debugLog("TimerState (\(id)): started — endDate \(endDate!), starting \(Int(starting))s")

        saveState()

        // Single choke point for every cook-timer start (cards, presets, watch
        // commands) — lets the app react app-wide, e.g. cancel a running
        // preheat countdown, without each start site needing to know.
        NotificationCenter.default.post(name: .cookTimerDidStart, object: nil)
    }

    func stop(at now: Date = Date()) {
        remainingAtPause = remaining(at: now)
        endDate = nil
        isRunning = false
        cancelPendingNotification()
        // Refresh timer stays alive so elapsed continues ticking.
        objectWillChange.send()
        debugLog("TimerState (\(id)): stopped — \(Int(remainingAtPause))s remaining")

        saveState()
    }

    func reset() {
        endDate = nil
        elapsedStartDate = nil
        remainingAtPause = initialIntervalTime
        runDuration = initialIntervalTime
        isRunning = false
        isCompleted = false
        intervalTime = initialIntervalTime
        elapsedTime = 0
        stopRefreshTimer()
        cancelPendingNotification()
        objectWillChange.send()
        debugLog("TimerState (\(id)): reset")

        clearPersistedState()
    }

    func resetToZero() { reset() }

    func setIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.initialIntervalTime = time
            self.remainingAtPause = time
            self.runDuration = time
            self.intervalTime = time
            self.objectWillChange.send()
        }
    }

    func setCurrentIntervalTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.remainingAtPause = time
            self.runDuration = time
            self.intervalTime = time
            self.objectWillChange.send()
        }
    }

    func setElapsedTime(_ time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = time
            self.elapsedStartDate = Date().addingTimeInterval(-time)
            self.objectWillChange.send()
        }
    }

    // MARK: - Refresh timer (UI-only, not source of truth)

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            self.elapsedTime = self.elapsed(at: now)
            if self.isRunning {
                let r = self.remaining(at: now)
                self.intervalTime = r
                if r <= 0 && !self.isCompleted {
                    self.handleCompletion()
                }
            }
            self.objectWillChange.send()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Completion

    private func handleCompletion() {
        endDate = nil
        remainingAtPause = 0
        isRunning = false
        isCompleted = true
        intervalTime = 0
        // Do NOT stop the refresh timer here: "Lit"/elapsed time must keep counting
        // up after the flip countdown completes, until the user presses Reset.
        // (elapsedStartDate stays set; reset() is what stops the clock and zeroes it.)
        cancelPendingNotification()
        objectWillChange.send()
        debugLog("TimerState (\(id)): completed")

        clearPersistedState()
        onCompleteAction?()
        triggerCompletionHaptics()
    }

    func completeNow() { handleCompletion() }

    func resetCompletionState() {
        isCompleted = false
        objectWillChange.send()
    }

    // MARK: - Foreground resync

    /// Called when the app returns to the foreground, or after state is restored from persistence.
    /// Corrects display values and restarts the refresh timer if needed.
    func resyncAfterForeground() {
        let now = Date()
        if let end = endDate {
            let r = max(0, end.timeIntervalSince(now))
            intervalTime = r
            elapsedTime = elapsed(at: now)
            if r <= 0 {
                handleCompletion()
            } else {
                isRunning = true
                if refreshTimer == nil { startRefreshTimer() }
            }
        } else if elapsedStartDate != nil {
            // Countdown is done (or stopped) but lit time is still running —
            // refresh the value and keep it ticking until the user resets.
            elapsedTime = elapsed(at: now)
            if refreshTimer == nil { startRefreshTimer() }
        }
        objectWillChange.send()
    }

    // MARK: - Sound & haptics

    func playSound() {
        if let settingsObj = settings, settingsObj.soundEnabled {
            settingsObj.playTimerCompletionWithAnnouncement(timerId: self.id)
        } else {
            AudioServicesPlaySystemSound(1005)
        }
    }

    private func triggerCompletionHaptics() {
        guard let settingsObj = settings, settingsObj.hapticsEnabled else { return }
        DispatchQueue.main.async {
            switch settingsObj.hapticIntensity {
            case .light:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .medium:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
                }
            case .strong:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
                }
            }
        }
    }

    // MARK: - Local notifications

    private func scheduleCompletionNotification(at fireDate: Date) {
        let identifier = "timer-\(id.uuidString)"
        notificationIdentifier = identifier
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(displayName()) timer is complete."
        // The user's chosen alert sound (repeated alarm variant), not the
        // stock ding — the locked-phone case is exactly the loud-backyard one.
        content.sound = NotificationSoundProvider.currentSound()
        content.interruptionLevel = .timeSensitive
        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌ Failed to schedule notification: \(error)")
            } else {
                debugLog("🗓️ Scheduled notification for timer \(self.id) in \(Int(interval))s")
            }
        }
    }

    private func cancelPendingNotification() {
        if let identifier = notificationIdentifier {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            notificationIdentifier = nil
        }
    }

    private func displayName() -> String {
        if let settings = settings,
           let timer = settings.allTimers.first(where: { $0.id == self.id }) {
            return timer.name
        }
        return "Timer"
    }

    // MARK: - Persistence (UserDefaults)

    private var persistPrefix: String { "timerState_\(id.uuidString)" }

    func saveState() {
        let d = UserDefaults.standard
        if let end = endDate {
            d.set(end.timeIntervalSince1970, forKey: "\(persistPrefix)_endDate")
        } else {
            d.removeObject(forKey: "\(persistPrefix)_endDate")
        }
        d.set(remainingAtPause, forKey: "\(persistPrefix)_remaining")
        if let start = elapsedStartDate {
            d.set(start.timeIntervalSince1970, forKey: "\(persistPrefix)_elapsedStart")
        } else {
            d.removeObject(forKey: "\(persistPrefix)_elapsedStart")
        }
    }

    func loadState() {
        let d = UserDefaults.standard
        // Restore elapsed start date (lit time continues across launches)
        if let raw = d.object(forKey: "\(persistPrefix)_elapsedStart") as? Double {
            elapsedStartDate = Date(timeIntervalSince1970: raw)
        }
        // Restore remaining-at-pause
        let savedRemaining = d.double(forKey: "\(persistPrefix)_remaining")
        if savedRemaining > 0 { remainingAtPause = savedRemaining }

        // Restore running timer
        if let raw = d.object(forKey: "\(persistPrefix)_endDate") as? Double {
            let savedEnd = Date(timeIntervalSince1970: raw)
            if savedEnd > Date() {
                endDate = savedEnd
                // isRunning stays false; resyncAfterForeground() will activate it
            } else {
                // Timer expired while app was killed — notification already fired
                isCompleted = true
                remainingAtPause = 0
                intervalTime = 0
            }
        }
        // Update display values from restored state
        let now = Date()
        if endDate != nil || remainingAtPause > 0 {
            intervalTime = remaining(at: now)
        }
        if elapsedStartDate != nil {
            elapsedTime = elapsed(at: now)
        }
    }

    func clearPersistedState() {
        let d = UserDefaults.standard
        d.removeObject(forKey: "\(persistPrefix)_endDate")
        d.removeObject(forKey: "\(persistPrefix)_remaining")
        d.removeObject(forKey: "\(persistPrefix)_elapsedStart")
    }

    // MARK: -

    func updateSettings(_ newSettings: Settings) {
        let old = self.settings?.selectedAlertSound.displayName ?? "nil"
        self.settings = newSettings
        debugLog("TimerState (\(id)): sound \(old) → \(newSettings.selectedAlertSound.displayName)")
    }
}

// MARK: - Preheat countdown (pure, testable)

/// Pure countdown math for the grill-preheat timer. Like `TimerState`, the
/// preheat countdown is derived from an absolute end date rather than a
/// decremented counter, so it stays correct across scrolling, screen-lock, and
/// backgrounding — all of which pause or drift a plain repeating `Timer`.
enum PreheatCountdown {
    /// Seconds remaining until `endDate`, clamped at 0. Returns 0 when no
    /// countdown is active (`endDate == nil`).
    static func remaining(endDate: Date?, now: Date) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }
}

// MARK: -

class TimerStatesManager: ObservableObject {
    @Published var states: [TimerState] = [] {
        didSet { resubscribeToRunningChanges() }
    }
    /// True while any timer is running. Published separately because `states`
    /// only changes on add/remove — an individual timer starting or stopping
    /// doesn't touch the array, so views that gate on "is anything running"
    /// (e.g. the Preheat bar's disabled look) would never re-render off
    /// `states` alone. Only fires when the aggregate answer actually flips.
    @Published private(set) var anyTimerRunning: Bool = false
    private var runningCancellables: Set<AnyCancellable> = []
    private var settings: Settings?

    init(settings: Settings? = nil) {
        self.settings = settings
    }

    private func resubscribeToRunningChanges() {
        runningCancellables.removeAll()
        updateAnyTimerRunning()
        for state in states {
            // $isRunning emits the new value during willSet, so the changed
            // state must be judged by the emitted value, not its property.
            state.$isRunning
                .sink { [weak self, weak state] newValue in
                    guard let self else { return }
                    let othersRunning = self.states.contains { $0 !== state && $0.isRunning }
                    let running = newValue || othersRunning
                    if running != self.anyTimerRunning {
                        self.anyTimerRunning = running
                    }
                }
                .store(in: &runningCancellables)
        }
    }

    private func updateAnyTimerRunning() {
        let running = states.contains { $0.isRunning }
        if running != anyTimerRunning {
            anyTimerRunning = running
        }
    }

    func initializeTimerStates(timers: [BBQTimer]) {
        for state in states { state.stop() }
        states = []
        for timer in timers {
            let state = TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings)
            state.loadState()
            states.append(state)
        }
        debugLog("TimerStatesManager: initialized \(states.count) states")
    }

    func addTimerState(for timer: BBQTimer) -> TimerState {
        let state = TimerState(id: timer.id, interval: TimeInterval(timer.preset1), settings: settings)
        state.loadState()
        states.append(state)
        return state
    }

    func removeTimerState(for timerId: UUID) {
        if let index = states.firstIndex(where: { $0.id == timerId }) {
            states[index].stop()
            states[index].clearPersistedState()
            states.remove(at: index)
        }
    }

    func state(for timerId: UUID) -> TimerState? {
        states.first { $0.id == timerId }
    }

    func syncTimerStates(timers: [BBQTimer]) {
        for timer in timers {
            if state(for: timer.id) == nil { _ = addTimerState(for: timer) }
        }
        let timerIds = Set(timers.map { $0.id })
        states = states.filter { timerState in
            if timerIds.contains(timerState.id) { return true }
            timerState.stop()
            timerState.clearPersistedState()
            return false
        }
    }

    func updateSettings(_ settings: Settings) {
        self.settings = settings
        for state in states { state.updateSettings(settings) }
        objectWillChange.send()
    }
}
