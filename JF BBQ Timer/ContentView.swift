import SwiftUI
import AVFoundation
import UIKit
import RevenueCat
import UserNotifications
import WatchConnectivity
import UniformTypeIdentifiers

/// Live-reorders the main-screen timer cards while one is dragged over another
/// (the standard SwiftUI onDrag/onDrop reorder pattern: the move happens in
/// `dropEntered` so cards shift out of the way as you hover, and `performDrop`
/// just ends the gesture — the order is already persisted by then).
struct TimerReorderDropDelegate: DropDelegate {
    let item: UUID
    @Binding var draggedItem: UUID?
    let settings: Settings

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem, dragged != item else { return }
        var order = settings.allTimers.map(\.id)
        guard let from = order.firstIndex(of: dragged),
              let to = order.firstIndex(of: item) else { return }
        order.move(fromOffsets: IndexSet(integer: from),
                   toOffset: to > from ? to + 1 : to)
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.setTimerOrder(order)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

// Remove the duplicate NewSettingsView declaration and keep only the most complete version
struct ContentView: View {
    @EnvironmentObject var settings: Settings
    #if os(iOS)
    @EnvironmentObject var probeManager: ProbeBLEManager
    #endif
    @StateObject private var timerStates: TimerStatesManager
    @State private var showSettings = false
    @State private var showDebugPanel = false
    @State private var showPremiumUpgrade = false
    #if os(iOS)
    @State private var showAttachSheet = false
    @State private var showProbeConnect = false
    /// The cook whose probe target sheet is open (nil = closed).
    @State private var targetSheetCook: BBQTimer? = nil
    #endif
    @State private var preheatPressPulse = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var watchSyncTimer: Timer? = nil
    @State private var watchCommandObserver: NSObjectProtocol? = nil
    @State private var cookStartObserver: NSObjectProtocol? = nil
    // Timer card currently being dragged to a new position (nil when not dragging)
    @State private var draggedTimerId: UUID? = nil
    @State private var lastSnapshot: [String: Any]? = nil

    init() {
        let settings = Settings()
        _timerStates = StateObject(wrappedValue: TimerStatesManager(settings: settings))
    }

    @Namespace private var scrollNamespace
    @State private var lastCompletedTimerId: UUID? = nil

    /// Shared ember-bed background (charcoal + glowing coals); see `EmberBackground`.
    private var backgroundLayer: some View {
        EmberBackground()
    }

    @ViewBuilder
    private var appHeader: some View {
        if #available(iOS 26, *) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color("TimerAccent"))
                Text("GrillTime Pro")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("AppTitle")
                Spacer()
                #if os(iOS)
                probeConnectButton
                #endif
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .accessibilityIdentifier("SettingsButton")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 11)
            .glassEffect(.clear.tint(.grillCardTint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                LinearGradient(
                    colors: [Color.grillCardBodyTop, Color.grillCardBodyBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.clear, Color.black.opacity(0.30)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 16)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color("TimerAccent"))
                Text("GrillTime Pro")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .accessibilityIdentifier("AppTitle")
                Spacer()
                #if os(iOS)
                probeConnectButton
                #endif
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                .accessibilityIdentifier("SettingsButton")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 11)
            .background(Color("PrimaryBackground"))
        }
    }

    #if os(iOS)
    private var probeIsActive: Bool {
        switch probeManager.connectionState {
        case .connected, .reconnecting:
            return true
        default:
            return false
        }
    }

    /// Probe-health warning for the header chip: overheat wins over battery.
    private var probeHealthBadge: (symbol: String, color: Color)? {
        guard probeIsActive, let reading = probeManager.latestReading else { return nil }
        if reading.isOverheating {
            return ("exclamationmark.triangle.fill", Color("TimerRed"))
        }
        if reading.batteryStatus == .low {
            return ("battery.25", Color("TimerRed"))
        }
        return nil
    }

    private var probeConnectButton: some View {
        // Premium gate: the chip is the probe feature's single entry point, so
        // free users get the upgrade sheet here — no connection means no probe
        // strip, targets, alerts, or watch probe page anywhere downstream.
        Button(action: {
            if settings.isPremiumUser {
                showProbeConnect = true
            } else {
                showPremiumUpgrade = true
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 15, weight: .semibold))
                Text("Probe")
                    .font(.system(size: 14, weight: .semibold))
                if !settings.isPremiumUser {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.85)
                }
                if let badge = probeHealthBadge {
                    Image(systemName: badge.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(badge.color)
                }
            }
            .foregroundColor(probeIsActive ? Color(red: 0.28, green: 0.10, blue: 0.04) : .white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(probeIsActive ? Color("TimerAccent") : Color.white.opacity(0.16))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
        }
        .accessibilityLabel("Connect Probe")
        .accessibilityIdentifier("ProbeConnectButton")
    }
    #endif

    private func timeString(from timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func timeStringNoLeadingHours(from timeInterval: TimeInterval) -> String {
        let total = max(0, Int(timeInterval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    @StateObject private var debugSettings = DebugVisualizerSettings.shared

    private var timer1State: TimerState? {
        timerStates.state(for: settings.legacyTimersAsBBQTimers[0].id)
    }

    private var timer2State: TimerState? {
        timerStates.state(for: settings.legacyTimersAsBBQTimers[1].id)
    }

    @StateObject private var alertState = AlertState()

    @State private var showPreheatAlert = false
    @State private var preheatTimeRemaining: TimeInterval = 0
    // Absolute instant the preheat countdown completes. Source of truth for the
    // countdown; preheatTimeRemaining is just the displayed value derived from it.
    @State private var preheatEndDate: Date? = nil
    @State private var preheatTimer: Timer?
    @State private var isPreheatComplete = false
    @State private var preheatNotificationId: String? = nil

    private func initializeTimerStates() {
        debugLog("ContentView: Initializing timer states with settings")
        timerStates.updateSettings(settings)
        timerStates.syncTimerStates(timers: settings.allTimers)
        // Wire onComplete for any timers that were restored from persistence
        // (their endDate is set but onCompleteAction is nil until the user taps Start).
        rewireRunningTimerCallbacks()
    }

    private func rewireRunningTimerCallbacks() {
        for timer in settings.allTimers {
            guard let state = timerStates.state(for: timer.id),
                  state.endDate != nil else { continue }
            state.onCompleteAction = { [weak state] in
                guard let state = state else { return }
                if settings.soundEnabled { state.playSound() }
                if settings.hapticsEnabled { alertState.isPresented = true }
            }
        }
    }

    private func fireHapticBurst() {
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

    private func startTimer1() {
        timer1State?.start {
            if settings.soundEnabled { timer1State?.playSound() }
            if settings.hapticsEnabled { alertState.isPresented = true }
        }
    }

    private func stopTimer1() {
        timer1State?.stop()
    }

    private func startTimer2() {
        timer2State?.start {
            if settings.soundEnabled { timer2State?.playSound() }
            if settings.hapticsEnabled { alertState.isPresented = true }
        }
    }

    private func stopTimer2() {
        timer2State?.stop()
    }

    private func startPreheatTimer() {
        let anyTimerRunning = timerStates.states.contains { $0.isRunning }
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
        if anyTimerRunning && !isUITest {
            debugLog("Cannot start preheat timer while other timers are running")
            return
        }

        preheatTimer?.invalidate()
        let duration = TimeInterval(settings.preheatDuration)
        let end = Date().addingTimeInterval(duration)
        preheatEndDate = end
        preheatTimeRemaining = duration
        showPreheatAlert = false
        isPreheatComplete = false
        // Cancel the previous notification BEFORE scheduling a new one —
        // re-tapping Preheat mid-countdown used to orphan the old request
        // (each schedule uses a fresh UUID id and only the latest is tracked),
        // and orphans fired as phantom "Preheat Complete" alerts later.
        cancelPreheatNotification()
        schedulePreheatNotification(after: duration)

        // The repeating timer only refreshes the displayed value; correctness
        // comes from the absolute end date, so the countdown can't drift when
        // the timer fires late, pauses during scrolling, or stops while the
        // screen is locked / the app is backgrounded.
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let remaining = PreheatCountdown.remaining(endDate: preheatEndDate, now: Date())
            preheatTimeRemaining = remaining
            if remaining <= 0 {
                stopPreheatTimer()
                if settings.soundEnabled { timer1State?.playSound() }
                if settings.hapticsEnabled { alertState.triggerNotificationFeedback(type: .success) }
                isPreheatComplete = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    isPreheatComplete = false
                }
            }
        }
        // Add to .common so the countdown keeps ticking while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        preheatTimer = timer

        if isUITest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if !showPreheatAlert { stopPreheatTimer() }
            }
        }
    }

    private func stopPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
        preheatEndDate = nil
        showPreheatAlert = true
        cancelPreheatNotification()
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")
        let delay: TimeInterval = isUITest ? 2 : 10
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showPreheatAlert = false
        }
    }

    #if os(iOS)
    /// Returns non-nil CardProbeInfo only when the probe is connected (or
    /// reconnecting) AND attached to this specific cook. All callers pass the
    /// result straight into the card content view; no probe logic runs in the
    /// card views themselves.
    private func probeInfo(for timer: BBQTimer) -> CardProbeInfo? {
        guard probeManager.attachedCookID == timer.id else { return nil }
        switch probeManager.connectionState {
        case .connected, .reconnecting:
            break
        default:
            return nil
        }
        let reading = probeManager.latestReading
        // Formats a °C value in the user's unit; "—" at/below the −20 °C sensor
        // floor (raw 0 = no data).
        func tempText(_ celsius: Double?) -> String {
            guard let c = celsius, c > -19.99 else { return "—" }
            return settings.temperatureUnit.compactString(fromCelsius: c)
        }
        var readyDate = reading?.prediction.predictedReadyDate(from: Date())

        // Phase-dependent ready slot (spec 3C): label + static text + emphasis.
        var readySlotLabel = "ready"
        var readySlotText: String? = nil
        var readySlotEmphasized = false
        switch probeManager.cookPhase {
        case .none, .monitoring:
            break
        case .predictingRemoval:
            readySlotLabel = "pull in"
        case .pullNow:
            readySlotLabel = "pull"
            readySlotText = "NOW"
            readySlotEmphasized = true
            readyDate = nil   // act-now moment — a countdown would contradict it
        case .resting:
            readySlotLabel = "rest"
        case .done:
            readySlotText = "done"
            readySlotEmphasized = true
            readyDate = nil
        }

        return CardProbeInfo(
            coreText: tempText(reading?.coreTempC),
            surfaceText: settings.showProbeSurfaceTemp ? tempText(reading?.surfaceTempC) : nil,
            ambientText: settings.showProbeAmbientTemp ? tempText(reading?.ambientTempC) : nil,
            readyDate: readyDate,
            showReady: settings.showProbePredictedReady,
            targetText: settings.probeTarget(forCookID: timer.id)
                .map { settings.temperatureUnit.compactString(fromCelsius: $0) },
            readySlotLabel: readySlotLabel,
            readySlotText: readySlotText,
            readySlotEmphasized: readySlotEmphasized,
            batteryLow: reading?.batteryStatus == .low,
            overheating: reading?.isOverheating ?? false
        )
    }

    /// Alerts for the guided-cook moments. State-driven (never scheduled from a
    /// drifting estimate, per the probe spec): an immediate local notification —
    /// reliable even when backgrounded, since the app holds the BLE background
    /// mode — plus a haptic when the app is frontmost.
    private func handleProbeCookEvent(_ event: ProbeCookEvent) {
        let title: String
        let body: String
        switch event {
        case .pullNow:
            title = "Time to pull the food"
            body = "The probe says take it off the heat — resting will carry it to your target."
        case .restingDone:
            title = "Food is ready"
            body = "Resting is complete — your cook reached its target temperature."
        case .targetReached:
            title = "Target temperature reached"
            body = "The probe's core temperature crossed your target."
        case .batteryLow:
            title = "Probe battery low"
            body = "Charge the probe soon — it may not last the rest of the cook."
        case .overheating:
            title = "Probe overheating"
            body = "A probe sensor is over its limit. Move the probe or handle away from direct heat."
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = NotificationSoundProvider.currentSound()
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "probe-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil   // nil trigger = deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { debugLog("❌ Probe alert notification failed: \(error)") }
        }
        if settings.hapticsEnabled { Haptics.tap() }
    }

    /// Push the attached cook's stored target into the probe manager, which
    /// owns the wire-level send/re-send rules. Called whenever the stored
    /// targets or the attachment change.
    private func syncProbeTargetToManager() {
        guard let cookID = probeManager.attachedCookID else { return }
        probeManager.setTarget(settings.probeTarget(forCookID: cookID))
    }
    #endif

    @ViewBuilder
    private func additionalTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        if settings.compactMode {
            compactTimerView(for: timer, state: state)
        } else {
            largeTimerView(for: timer, state: state)
        }
    }

    @ViewBuilder
    private func compactTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        if #available(iOS 26, *) {
            GlassCompactTimerContent(
                timer: timer,
                state: state,
                settings: settings,
                alertState: alertState,
                probeInfo: probeInfo(for: timer),
                onProbeStripTap: { targetSheetCook = timer }
            )
            .timerContainerAppearance(
                timerState: state,
                onTimerComplete: { timerId in
                    debugLog("Timer \(timerId) completed, scrolling to view")
                    lastCompletedTimerId = timerId
                }
            )
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 6) {
                TimerHeaderView(name: timer.name)

                CompactTimerView(
                    name: timer.name,
                    preset1: TimeInterval(timer.preset1),
                    preset2: TimeInterval(timer.preset2),
                    state: state,
                    settings: settings,
                    alertState: alertState,
                    probeInfo: probeInfo(for: timer),
                    cookID: timer.id,
                    onProbeStripTap: { targetSheetCook = timer }
                )
            }
            .padding(8)
            .timerContainerAppearance(
                timerState: state,
                onTimerComplete: { timerId in
                    debugLog("Timer \(timerId) completed, scrolling to view")
                    lastCompletedTimerId = timerId
                }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func largeTimerView(for timer: BBQTimer, state: TimerState) -> some View {
        if #available(iOS 26, *) {
            GlassLargeTimerContent(
                timer: timer,
                state: state,
                settings: settings,
                alertState: alertState,
                probeInfo: probeInfo(for: timer),
                onProbeStripTap: { targetSheetCook = timer }
            )
            .timerContainerAppearance(
                timerState: state,
                onTimerComplete: { timerId in
                    debugLog("Timer \(timerId) completed, scrolling to view")
                    lastCompletedTimerId = timerId
                },
                isLargeTimer: true
            )
            .padding(.bottom, 8)
        } else {
            VStack(spacing: 8) {
                TimerHeaderView(name: timer.name)
                    .padding(.top, 4)

                IntervalTimerView(timerState: state, theme: Theme.defaultTheme)
                    .padding(.top, 4)

                ElapsedTimerView(timerState: state, theme: Theme.defaultTheme)
                    .padding(.bottom, 4)

                HStack(spacing: 14) {
                    TimerPresetButton(
                        presetTime: TimeInterval(timer.preset1),
                        timeStringConverter: timeStringNoLeadingHours,
                        action: {
                            state.stop()
                            state.setCurrentIntervalTime(TimeInterval(timer.preset1))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }
                    )

                    TimerPresetButton(
                        presetTime: TimeInterval(timer.preset2),
                        timeStringConverter: timeStringNoLeadingHours,
                        action: {
                            state.stop()
                            state.setCurrentIntervalTime(TimeInterval(timer.preset2))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }
                    )
                }
                .padding(.top, 4)

                TimerControlButtons(
                    state: state,
                    settings: settings,
                    alertState: alertState
                )
                .padding(.bottom, 4)

                if let info = probeInfo(for: timer) {
                    Divider()
                        .padding(.horizontal, 4)

                    HStack(spacing: 6) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("TimerAccent"))
                        Text("Core")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(info.coreText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(Color("TimerAccent"))
                        Spacer()
                        Text("ready")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        if #available(iOS 16, *), let readyDate = info.readyDate {
                            Text(timerInterval: Date()...readyDate, countsDown: true)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Text(info.readyDate != nil ? "~" : "—")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .timerContainerAppearance(
                timerState: state,
                onTimerComplete: { timerId in
                    debugLog("Timer \(timerId) completed, scrolling to view")
                    lastCompletedTimerId = timerId
                },
                isLargeTimer: true
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func preheatButtonView() -> some View {
        // Published aggregate (not a states-array scan): flips exactly when a
        // timer starts/stops, so this view re-renders and the disabled look
        // tracks reality.
        let anyTimerRunning = timerStates.anyTimerRunning
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITEST_MODE")

        return Button(action: {
            if settings.hapticsEnabled {
                Haptics.ignite()
            }
            preheatPressPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                preheatPressPulse = false
            }
            startPreheatTimer()
        }) {
            preheatLabel(anyTimerRunning: anyTimerRunning)
        }
        .disabled(anyTimerRunning && !isUITest)
        .contextMenu {
            if preheatTimeRemaining > 0 {
                Button(action: { resetPreheatTimer() }) {
                    Label("Reset Preheat Timer", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
            view.debugFrame(
                debugSettings.showFrames,
                color: .red,
                showPadding: debugSettings.showPadding,
                showBackground: debugSettings.showBackgrounds,
                label: "Preheat Button"
            )
        }
    }

    @ViewBuilder
    private func preheatLabel(anyTimerRunning: Bool) -> some View {
        let timeText = preheatTimeRemaining > 0
            ? timeString(from: preheatTimeRemaining)
            : timeString(from: TimeInterval(settings.preheatDuration))
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        if #available(iOS 26, *) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                VStack(spacing: 1) {
                    Text("Preheat grill")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(timeText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .opacity(0.8)
                }
            }
            .foregroundStyle(anyTimerRunning ? Color.white.opacity(0.4) : Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .glassEffect(.clear.tint(.grillCardTint), in: shape)
            .background(
                LinearGradient(
                    colors: [Color.grillCardBodyTop, Color.grillCardBodyBottom],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: shape
            )
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.clear, Color.black.opacity(0.30)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
            )
            .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
            // Whole-pane dim while a cook timer runs (text-only dimming was
            // too subtle on glass to read as "disabled").
            .saturation(anyTimerRunning ? 0.5 : 1.0)
            .opacity(anyTimerRunning ? 0.55 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: anyTimerRunning)
            .scaleEffect(preheatPressPulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: preheatPressPulse)
            .modifier(PreheatCompleteModifier(isPreheatComplete: isPreheatComplete))
        } else {
            VStack {
                HStack(alignment: .center) {
                    Spacer()
                    Text("Preheat Grill")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                }
                Text(timeText)
                    .font(.system(size: 24, weight: .bold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(width: UIScreen.main.bounds.width * 0.8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: anyTimerRunning ?
                                      [Color.gray.opacity(0.7), Color.gray.opacity(0.5)] :
                                      [Color.orange, Color.red]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 3)
            .scaleEffect(preheatPressPulse ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: preheatPressPulse)
            .modifier(PreheatCompleteModifier(isPreheatComplete: isPreheatComplete))
        }
    }

    private func resetPreheatTimer() {
        preheatTimer?.invalidate()
        preheatTimer = nil
        preheatEndDate = nil
        preheatTimeRemaining = 0
        isPreheatComplete = false
        showPreheatAlert = false
        cancelPreheatNotification()
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                appHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(settings.allTimers) { timer in
                                if let state = timerStates.state(for: timer.id) {
                                    additionalTimerView(for: timer, state: state)
                                        .id(timer.id)
                                        .accessibilityIdentifier("Timer_\(timer.id)")
                                        // Long-press then drag to reorder cards; the
                                        // new order persists and the watch follows it.
                                        .onDrag {
                                            draggedTimerId = timer.id
                                            return NSItemProvider(object: timer.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: TimerReorderDropDelegate(
                                            item: timer.id,
                                            draggedItem: $draggedTimerId,
                                            settings: settings
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: lastCompletedTimerId) { completedId in
                        guard let completedId = completedId else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo(completedId, anchor: .center)
                            }
                        }
                    }
                }

                // Fixed bottom bar — always visible below the scrolling timer list
                preheatButtonView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("PreheatButton")
            }

            if alertState.isPresented, let timer1 = settings.legacyTimersAsBBQTimers.first, let timer1State = timerStates.state(for: timer1.id) {
                AlertView(alertState: alertState, audioPlayer: Settings.sharedAudioPlayer, isPreheat: false, settings: settings, timerState: timer1State)
                    .accessibilityIdentifier("TimerAlert")
            }

            if showPreheatAlert {
                PreheatAlertView(
                    isPresented: $showPreheatAlert,
                    onDismiss: handlePreheatAlertDismiss,
                    settings: settings,
                    timerState: getFirstTimerState()
                )
                .accessibilityIdentifier("PreheatAlert")
            }

            // The real RevenueCat paywall (live price, actual purchase flow) —
            // same one Settings and onboarding use. The old PremiumUpgradeView
            // stub here hardcoded a stale price and granted premium without a
            // purchase.
            if showPremiumUpgrade {
                CustomPaywallView(dismissAction: { showPremiumUpgrade = false }, settings: settings)
                    .transition(.opacity)
                    .zIndex(100)
                    .accessibilityIdentifier("PremiumUpgrade")
            }

            if debugSettings.isEnabled && showDebugPanel {
                VStack {
                    DebugPanel(settings: debugSettings)
                    Spacer()
                }
                .zIndex(100)
                .accessibilityIdentifier("DebugPanel")
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            NewSettingsView(settings: settings)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showProbeConnect) {
            ProbePickerView(probeManager: probeManager,
                            temperatureUnit: settings.temperatureUnit,
                            cooks: settings.allTimers.map { CookItem(id: $0.id, name: $0.name) })
        }
        .fullScreenCover(isPresented: $showAttachSheet) {
            if #available(iOS 16, *) {
                ProbeAttachSheet(
                    cooks: settings.allTimers.map { CookItem(id: $0.id, name: $0.name) },
                    probeManager: probeManager
                )
            }
        }
        .sheet(item: $targetSheetCook) { cook in
            if #available(iOS 16, *) {
                ProbeTargetSheet(
                    cookName: cook.name,
                    unit: settings.temperatureUnit,
                    currentTargetCelsius: settings.probeTarget(forCookID: cook.id),
                    settings: settings,
                    onSave: { celsius in
                        settings.setProbeTarget(celsius, forCookID: cook.id)
                    }
                )
            }
        }
        .onChange(of: probeManager.connectionState) { newState in
            // Auto-ask which timer to attach to — but only when the probe picker
            // cover isn't up: two covers can't present at once (the old silent
            // failure), and the picker now runs this same prompt itself.
            if case .connected = newState, probeManager.attachedCookID == nil, !showProbeConnect {
                showAttachSheet = true
            }
        }
        // Any change to stored targets (sheet, Reset) or to which cook the
        // probe is attached to gets pushed to the manager, which handles the
        // actual (re)sends to the probe.
        .onChange(of: settings.probeTargetsByCookID) { _ in
            syncProbeTargetToManager()
        }
        .onChange(of: probeManager.attachedCookID) { _ in
            syncProbeTargetToManager()
        }
        #endif
        .buttonStyle(HapticButtonStyle())
        .onAppear {
            debugLog("[📱iOS] 🚀 ContentView.onAppear - scenePhase: \(scenePhase)")
            #if os(iOS)
            probeManager.onCookEvent = { event in
                handleProbeCookEvent(event)
            }
            #endif
            timerStates.updateSettings(settings)
            initializeTimerStates()
            settings.initializeVoiceSettings()
            alertState.hapticsEnabled = settings.hapticsEnabled
            Haptics.isEnabled = settings.hapticsEnabled
            Haptics.prepare()
            requestNotificationPermission()
            sweepOrphanedPreheatNotifications()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                debugLog("[📱iOS] 🕐 Delayed sync timer start - scenePhase: \(scenePhase)")
                startWatchSyncTimer()
            }
            // Food going on the grill makes a running preheat countdown moot —
            // cancel it quietly (no "Preheat Complete" alert or notification)
            // whenever any cook timer starts, from any start site incl. the watch.
            cookStartObserver = NotificationCenter.default.addObserver(
                forName: .cookTimerDidStart,
                object: nil,
                queue: .main
            ) { _ in
                if preheatEndDate != nil {
                    debugLog("Preheat cancelled — a cooking timer started")
                    resetPreheatTimer()
                }
            }
            watchCommandObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("receivedCommand"),
                object: nil,
                queue: .main
            ) { note in
                guard let dict = note.userInfo as? [String: Any],
                      let action = dict["action"] as? String else { return }
                let idString = dict["timerId"] as? String
                let uuid = idString.flatMap(UUID.init)
                let timer: BBQTimer? = uuid.flatMap { u in settings.allTimers.first(where: { $0.id == u }) }

                switch action {
                case "requestSnapshot":
                    sendWatchSnapshotImmediately()

                case "applyPreset1":
                    guard let uuid = uuid, let timer = timer else { break }
                    let presetSeconds = TimeInterval(timer.preset1)
                    if let state = timerStates.state(for: uuid) {
                        state.setIntervalTime(presetSeconds)
                        state.start(onComplete: {
                            if settings.soundEnabled { state.playSound() }
                            if settings.hapticsEnabled { alertState.isPresented = true }
                        })
                    }

                case "applyPreset2":
                    guard let uuid = uuid, let timer = timer else { break }
                    let presetSeconds = TimeInterval(timer.preset2)
                    if let state = timerStates.state(for: uuid) {
                        state.setIntervalTime(presetSeconds)
                        state.start(onComplete: {
                            if settings.soundEnabled { state.playSound() }
                            if settings.hapticsEnabled { alertState.isPresented = true }
                        })
                    }

                case "toggleRun":
                    guard let uuid = uuid, let state = timerStates.state(for: uuid) else { break }
                    if state.isRunning {
                        state.stop()
                    } else {
                        if state.intervalTime <= 0, let t = timer {
                            state.setIntervalTime(TimeInterval(t.preset1))
                        }
                        state.start(onComplete: {
                            if settings.soundEnabled { state.playSound() }
                            if settings.hapticsEnabled { alertState.isPresented = true }
                        })
                    }

                case "ackAlert":
                    if alertState.isPresented { alertState.isPresented = false }
                    if showPreheatAlert { showPreheatAlert = false }
                    settings.stopLoopingAlertSound()
                    if let idString = dict["timerId"] as? String,
                       let uuid = UUID(uuidString: idString),
                       let state = timerStates.state(for: uuid) {
                        state.resetCompletionState()
                    }

                default:
                    break
                }

                sendWatchSnapshotImmediately()
            }
        }
        .onChange(of: settings.additionalTimers) { _ in
            initializeTimerStates()
        }
        .onChange(of: settings.selectedAlertSound) { _ in
            debugLog("Alert sound changed to \(settings.selectedAlertSound.displayName), updating timer states")
            timerStates.updateSettings(settings)
        }
        .onChange(of: settings.soundEnabled) { _ in
            debugLog("Sound enabled changed to \(settings.soundEnabled), updating timer states")
            timerStates.updateSettings(settings)
        }
        .onChange(of: settings.hapticsEnabled) { enabled in
            Haptics.isEnabled = enabled
            if enabled { Haptics.prepare() }
        }
        .onChange(of: alertState.isPresented) { isShown in
            let phase = isShown ? "start" : "stop"
            WCSessionManager.shared.sendCommand(["action": "alert", "phase": phase, "message": "Timer Finished"])
        }
        .onChange(of: showPreheatAlert) { isShown in
            let phase = isShown ? "start" : "stop"
            WCSessionManager.shared.sendCommand(["action": "alert", "phase": phase, "message": "Preheat Complete"])
        }
        .onChange(of: scenePhase) { newPhase in
            debugLog("[📱iOS] 📱 scenePhase changed to: \(newPhase)")
            if newPhase == .active {
                debugLog("[📱iOS] 📱 App became ACTIVE - starting watch sync")
                resyncTimersAfterForeground()
                resyncPreheatAfterForeground()
                sendWatchSnapshotImmediately()
                startWatchSyncTimer()
            } else if newPhase == .background || newPhase == .inactive {
                debugLog("[📱iOS] 📱 App went to \(newPhase) - stopping watch sync")
                stopWatchSyncTimer()
            }
        }
        .onDisappear {
            if alertState.showPreheatAlert { alertState.showPreheatAlert = false }
            stopWatchSyncTimer()
            if let observer = watchCommandObserver {
                NotificationCenter.default.removeObserver(observer)
                watchCommandObserver = nil
            }
            if let observer = cookStartObserver {
                NotificationCenter.default.removeObserver(observer)
                cookStartObserver = nil
            }
        }
    }

    private func getFirstTimerState() -> TimerState {
        if let firstTimer = settings.legacyTimersAsBBQTimers.first {
            return timerStates.state(for: firstTimer.id) ?? createDefaultTimerState()
        }
        return createDefaultTimerState()
    }

    private func createDefaultTimerState() -> TimerState {
        return TimerState(id: UUID(), interval: TimeInterval(settings.preheatDuration), settings: settings)
    }

    private func handlePreheatAlertDismiss() {
        showPreheatAlert = false
        settings.stopLoopingAlertSound()
        if let firstTimer = settings.legacyTimersAsBBQTimers.first,
           let state = timerStates.state(for: firstTimer.id) {
            state.resetCompletionState()
        }
    }

    // MARK: - Watch sync helpers

    private func startWatchSyncTimer() {
        debugLog("[📱iOS] 🕐 startWatchSyncTimer() called - scenePhase: \(scenePhase)")
        stopWatchSyncTimer()
        guard scenePhase == .active || scenePhase == .inactive else {
            debugLog("[📱iOS] ⚠️ startWatchSyncTimer: skipped - scenePhase is \(scenePhase)")
            return
        }
        debugLog("[📱iOS] ✅ Starting watch sync timer (1s interval)")
        watchSyncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let snapshot = self.buildWatchSnapshot()
            var hasRunningTimer = false
            if let timers = snapshot["timers"] as? [[String: Any]] {
                let runningCount = timers.filter { ($0["state"] as? String) == "running" }.count
                hasRunningTimer = runningCount > 0
                if hasRunningTimer { debugLog("[📱iOS] 🔄 Sync tick: \(runningCount) running timer(s)") }
            }
            if let last = self.lastSnapshot {
                if NSDictionary(dictionary: snapshot).isEqual(to: last) { return }
            }
            if hasRunningTimer {
                debugLog("[📱iOS] 📤 Sync timer sending snapshot (timer running)...")
            } else {
                debugLog("[📱iOS] 📤 Sync timer sending snapshot (state changed)...")
            }
            let session = WCSession.default
            if WCSession.isSupported() && session.activationState == .activated {
                let success = WCSessionManager.shared.sendTimersSnapshot(snapshot)
                if success { self.lastSnapshot = snapshot }
            }
        }
        RunLoop.main.add(watchSyncTimer!, forMode: .common)
        debugLog("[📱iOS] ✅ Watch sync timer started and added to RunLoop")
    }

    private func stopWatchSyncTimer() {
        if watchSyncTimer != nil { debugLog("[📱iOS] 🛑 Stopping watch sync timer") }
        watchSyncTimer?.invalidate()
        watchSyncTimer = nil
    }

    private func buildWatchSnapshot() -> [String: Any] {
        let rows: [[String: Any]] = settings.allTimers.compactMap { timer in
            let state = timerStates.state(for: timer.id)
            let now = Date()
            let remaining = Int((state?.remaining(at: now) ?? TimeInterval(timer.preset1)).rounded())
            let isRunning = state?.isRunning == true
            let status = isRunning ? "running" : "stopped"
            let elapsed = Int((state?.elapsed(at: now) ?? 0).rounded())
            var row: [String: Any] = [
                "id": timer.id.uuidString,
                "name": timer.name,
                "remaining": remaining,
                "state": status,
                "preset1": timer.preset1,
                "preset2": timer.preset2,
                "elapsed": elapsed,
            ]
            // Absolute end date lets the watch compute remaining independently,
            // surviving suspension without drifting.
            if let end = state?.endDate {
                row["endDate"] = end.timeIntervalSince1970
            }
            // Total run duration lets the watch compute its countdown ring's
            // fill fraction. Additive key — older watch builds ignore it.
            if let duration = state?.runDuration, duration > 0 {
                row["runDuration"] = Int(duration.rounded())
            }
            return row
        }
        return ["timers": rows]
    }

    private func sendWatchSnapshotImmediately() {
        let snapshot = buildWatchSnapshot()
        if let timers = snapshot["timers"] as? [[String: Any]] {
            let runningTimers = timers.filter { ($0["state"] as? String) == "running" }
            debugLog("[📱iOS] 📤 sendWatchSnapshotImmediately: \(timers.count) timers, \(runningTimers.count) running")
        }
        _ = WCSessionManager.shared.sendTimersSnapshot(snapshot)
        lastSnapshot = snapshot
    }

    // MARK: - Notification helpers

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                debugLog("❌ Notification permission error: \(error)")
            } else {
                debugLog("🔔 Notification permission granted: \(granted)")
            }
        }
    }

    private func resyncTimersAfterForeground() {
        for state in timerStates.states { state.resyncAfterForeground() }
    }

    private func schedulePreheatNotification(after seconds: TimeInterval) {
        let identifier = "preheat-\(UUID().uuidString)"
        preheatNotificationId = identifier
        let content = UNMutableNotificationContent()
        content.title = "Preheat Complete"
        content.body = "Your grill preheat timer is done."
        content.sound = NotificationSoundProvider.currentSound()
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                debugLog("❌ Failed to schedule preheat notification: \(error)")
            } else {
                debugLog("🗓️ Scheduled preheat notification in \(Int(seconds))s")
            }
        }
    }

    private func cancelPreheatNotification() {
        if let id = preheatNotificationId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            preheatNotificationId = nil
        }
    }

    /// Remove every pending "preheat-…" notification. Called once at launch:
    /// a preheat never survives a relaunch (its state is not persisted), so any
    /// pending preheat notification at launch is an orphan from an old session
    /// — including ones stranded on users' devices by the pre-fix re-tap bug.
    private func sweepOrphanedPreheatNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let orphans = requests.map(\.identifier).filter { $0.hasPrefix("preheat-") }
            if !orphans.isEmpty {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: orphans)
                debugLog("🧹 Removed \(orphans.count) orphaned preheat notification(s)")
            }
        }
    }

    private func resyncPreheatAfterForeground() {
        guard let end = preheatEndDate else { return }
        // Re-derive the displayed value from the absolute end date so a countdown
        // that drifted (or froze) while backgrounded snaps back to the true time.
        let remaining = PreheatCountdown.remaining(endDate: end, now: Date())
        preheatTimeRemaining = remaining
        if remaining <= 0 && !showPreheatAlert {
            // Finished while the app was away — the local notification already
            // alerted the user, so just settle the in-app state to complete.
            stopPreheatTimer()
            isPreheatComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                isPreheatComplete = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 12) {
                Text("Timer 1")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("05:00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                HStack(spacing: 12) {
                    Text("Reset")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .background(Color("TimerRed"))
                        .cornerRadius(12)

                    Text("Start")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 120)
                        .background(Color("TimerGreen"))
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 3)
            .padding()
            .background(Color(UIColor(red: 201/255, green: 48/255, blue: 32/255, alpha: 0.75)))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Timer Component")
        }
    }
}
