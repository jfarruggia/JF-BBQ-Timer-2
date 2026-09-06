//
//  ContentView.swift
//  GrillTime Pro Watch App Watch App
//
//  Created by James Farruggia on 8/17/25.
//

import SwiftUI
import WatchConnectivity
import WatchKit

struct TimersListView: View {
    @StateObject private var model = WatchTimersModel()
    @StateObject private var probeModel = WatchProbeModel()
    @StateObject private var probeAlertModel = WatchProbeAlertModel()
    // Local ticker so the watch UI updates every second without waiting for iPhone
    // Only active when timers are running to save battery
    @State private var now = Date()
    @State private var activeTickerTimer: Timer? = nil
    // Retry requesting a snapshot from iPhone a few times on first launch
    @State private var snapshotRetryCount: Int = 5
    @State private var snapshotRetryTimer: Timer?
    // Tracks which timer page is currently visible so we can show its name in the top bar
    @State private var selectedTimerId: String? = nil
    // Request guard so we only ask iPhone for a snapshot once on launch
    @State private var hasRequestedInitialSnapshot: Bool = false
    // Keeps the app executing when it leaves the foreground, similar to Apple's Timer app
    // so countdowns remain accurate and alerts can still be coordinated.
    private let runtime = ExtendedRuntimeController()
    
    // Check if any timer is currently running
    private var hasRunningTimer: Bool {
        model.timers.contains { $0.state == "running" }
    }

    var body: some View {
        // NavigationStack provides the top system bar on watchOS
        NavigationStack {
            mainContent
                // Same ember-glow bed as the iPhone main screen, sized for the
                // small display (fewer, softer coals so text stays readable).
                .containerBackground(for: .navigation) {
                    WatchEmberBackground()
                }
                // Clear any default title to avoid duplication with the toolbar item
                .navigationTitle("")
                // Timer pages carry their own name + temp line under the ring
                // (watch-ring-layout-spec.md) — the top row belongs to the
                // system clock. Only the probe page still labels itself here.
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if selectedTimerId == Self.probePageID {
                            Text("Probe")
                                .font(.footnote)
                                .baselineOffset(-3)
                        }
                    }
                }
        }
        // Initialize the selection to the first timer when available
        .onAppear {
            debugLog("[⌚️Watch] 🚀 TimersListView appeared")
            debugLog("[⌚️Watch] Current timer count: \(model.timers.count)")
            
            if selectedTimerId == nil {
                selectedTimerId = model.timers.first?.id
                debugLog("[⌚️Watch] Selected first timer: \(selectedTimerId ?? "none")")
            }
            
            // If we launch to an empty list, proactively ask iPhone for a snapshot
            if !hasRequestedInitialSnapshot && model.timers.isEmpty {
                hasRequestedInitialSnapshot = true
                debugLog("[⌚️Watch] 📤 Requesting INITIAL snapshot from iPhone (timers empty)")
                WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
                
                // Start a short retry loop so we recover if the first request races activation
                snapshotRetryTimer?.invalidate()
                snapshotRetryCount = 5
                snapshotRetryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    // Stop retrying once we have data
                    if !model.timers.isEmpty || snapshotRetryCount <= 0 {
                        if !model.timers.isEmpty {
                            debugLog("[⌚️Watch] ✅ Got timers! Stopping retry loop")
                        } else {
                            debugLog("[⌚️Watch] ⏱️ Retry loop exhausted, still no timers")
                        }
                        snapshotRetryTimer?.invalidate()
                        snapshotRetryTimer = nil
                        return
                    }
                    snapshotRetryCount -= 1
                    debugLog("[⌚️Watch] 🔄 Retrying snapshot request (\(snapshotRetryCount) retries left)")
                    WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
                }
                if let t = snapshotRetryTimer { RunLoop.main.add(t, forMode: .common) }
            } else {
                debugLog("[⌚️Watch] ℹ️ Skipping initial snapshot request (already requested or have timers)")
            }
            
            // Ensure extended runtime is active if any timers are already running
            refreshExtendedRuntimeSession()
        }
        // Keep the selection valid when the timers list changes
        .onChange(of: model.timers) { oldValue, newValue in
            debugLog("[⌚️Watch] 📊 Timers changed: \(oldValue.count) → \(newValue.count)")
            
            // Log which timers are now running
            let runningTimers = newValue.filter { $0.state == "running" }
            if !runningTimers.isEmpty {
                debugLog("[⌚️Watch] 🏃 Running timers: \(runningTimers.map { "\($0.name)(\($0.remaining)s)" }.joined(separator: ", "))")
                // Start the UI ticker when a timer starts running
                startTickerIfNeeded()
            } else {
                debugLog("[⌚️Watch] ⏸️ No timers currently running")
                // Stop the UI ticker to save battery when no timers are running
                stopTicker()
            }
            
            if let current = selectedTimerId,
               current == Self.probePageID || newValue.contains(where: { $0.id == current }) {
                // keep current selection (incl. staying on the probe page —
                // snapshots arrive every second while a timer runs, and getting
                // bounced off the page on every tick would make it unusable)
            } else {
                selectedTimerId = newValue.first?.id
            }
            // Start/stop extended runtime according to whether any timers are running
            refreshExtendedRuntimeSession()
        }
        // A timer just started running (typically from the iPhone) — page over to
        // it so the user sees it counting down. Consumes focusTimerId (reset to
        // nil) so the same timer can re-trigger focus on a later start.
        .onChange(of: model.focusTimerId) { _, newValue in
            guard let id = newValue else { return }
            withAnimation { selectedTimerId = id }
            model.focusTimerId = nil
        }
        // When an alert appears, play a lightweight haptic once
        .onChange(of: model.alertMessage) { oldValue, newValue in
            if newValue != nil {
                WKInterfaceDevice.current().play(.notification)
            }
        }
        // Same one-shot haptic for a probe cook moment
        .onChange(of: probeAlertModel.alert) { _, newValue in
            if newValue != nil {
                WKInterfaceDevice.current().play(.notification)
            }
        }
        // If the probe disconnects while its page is showing, the page is removed
        // from the pager — move the selection back to a timer.
        .onChange(of: probeConnected) { _, connected in
            if !connected && selectedTimerId == Self.probePageID {
                selectedTimerId = model.timers.first?.id
            }
        }
    }

    // Break the main content into smaller subviews for faster type-checking
    @ViewBuilder
    private var mainContent: some View {
        if model.timers.isEmpty {
            emptyState
                .overlay(alertBanner, alignment: .center)
                .overlay(probeAlertBanner, alignment: .center)
        } else {
            timersPager
                .overlay(alertBanner, alignment: .center)
                .overlay(probeAlertBanner, alignment: .center)
        }
    }

    // MARK: - Probe page
    //
    // The probe gets its own page at the end of the pager (swiping between pages
    // is already how you move between timers, so one more page fits the existing
    // navigation). A bottom strip was tried first and overlapped the timer
    // controls — the fixed-height presets + Start button don't leave room for a
    // safe-area inset on smaller watch sizes. While on a timer page, the current
    // core temp stays glanceable in the top bar next to the timer name.

    /// Pager tag for the probe page. Timer pages use UUID strings, so this
    /// sentinel can't collide.
    private static let probePageID = "probe"

    private var probeConnected: Bool {
        probeModel.probe?.connected == true
    }

    @ViewBuilder
    private var probePage: some View {
        if let probe = probeModel.probe {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text("Core")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if let target = probe.targetC {
                        Text("→ \(probe.unit.compactString(fromCelsius: target))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    if probe.overheating {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else if probe.batteryLow {
                        Image(systemName: "battery.25")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                // Core temp — the hero
                Text(shortTemp(probe.coreC, unit: probe.unit))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 10) {
                    Text("Sfc \(shortTemp(probe.surfaceC, unit: probe.unit))")
                    Text("Amb \(shortTemp(probe.ambientC, unit: probe.unit))")
                }
                .font(.footnote)
                .monospacedDigit()
                .foregroundColor(.secondary)

                // Guided-cook status line — phase-aware (mirrors the iPhone card)
                probeStatusLine(for: probe)
                    .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// Short whole-degree temperature in the user's unit, or "—" when no reading.
    private func shortTemp(_ celsius: Double?, unit: TemperatureUnit) -> String {
        celsius.map { unit.compactString(fromCelsius: $0) } ?? "—"
    }

    /// Phase-aware status line for the probe page: countdowns while the probe
    /// is predicting, and clear act-now text at the pull / done moments.
    @ViewBuilder
    private func probeStatusLine(for probe: WatchProbeReading) -> some View {
        switch ProbeCookPhase(rawValue: probe.phaseRaw) ?? .none {
        case .pullNow:
            Label("Pull now!", systemImage: "hand.raised.fill")
                .font(.footnote.weight(.bold))
                .foregroundColor(.orange)
        case .done:
            Label("Ready to serve", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.bold))
                .foregroundColor(.green)
        case .resting:
            probeCountdownLine(for: probe, caption: "resting")
        case .predictingRemoval:
            probeCountdownLine(for: probe, caption: "to pull")
        case .none, .monitoring:
            probeCountdownLine(for: probe, caption: "ready")
        }
    }

    @ViewBuilder
    private func probeCountdownLine(for probe: WatchProbeReading, caption: String) -> some View {
        if let readyDate = probe.predictedReadyDate, readyDate > Date() {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text(timerInterval: Date.now...readyDate, countsDown: true)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundColor(.green)
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(.gray)
            Text("No timers yet")
                .font(.headline)
            Text("Open the iPhone app to sync timers.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Refresh") {
                // Ask the iPhone for a snapshot (safe no-op if ignored)
                debugLog("[⌚️Watch] 👆 User tapped REFRESH button")
                WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            debugLog("[⌚️Watch] ⚠️ Showing EMPTY STATE - no timers available")
        }
    }

    private var timersPager: some View {
        TabView(selection: $selectedTimerId) {
            ForEach(model.timers) { row in
                timerPage(row)
                    .tag(row.id)
            }
            // Probe page rides at the end of the pager while connected
            if probeConnected {
                probePage
                    .tag(Self.probePageID)
            }
        }
        .tabViewStyle(.page)
    }

    // Ring layout per watch-ring-layout-spec.md (mirrors the iPhone card):
    // ring hero, name + probe temp beneath it, preset buttons at the bottom.
    // Leftover space splits above the ring / below the buttons so the group
    // floats centered under the system clock.
    @ViewBuilder
    private func timerPage(_ row: WatchTimersModel.Row) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)
            countdownRing(for: row)
            nameLine(for: row)
                .padding(.top, 2)
            presetButtons(for: row)
                .padding(.top, 3)
                .padding(.horizontal, 14)
            // No Start/Pause button (removed by request — the preset buttons
            // start timers; pause/resume is done from the iPhone).
            Spacer(minLength: 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The countdown ring — fill computed from absolute dates every tick
    /// (never a decremented counter), digits system-managed so they stay live
    /// on Always-On Display. The ring itself can't redraw while suspended and
    /// catches up on wrist-raise (accepted in the spec).
    private func countdownRing(for row: WatchTimersModel.Row) -> some View {
        let remaining = Double(effectiveRemaining(for: row))
        // Older iPhone apps don't send runDuration — approximate so the ring
        // still renders sensibly.
        let duration = Double(row.runDurationSeconds ?? max(row.remaining, row.preset1Seconds ?? 0))

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 9)
            Circle()
                .trim(from: 0, to: WatchRingMath.progress(remaining: remaining, runDuration: duration))
                .stroke(Color("TimerAccent"),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("Flip in")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                remainingCountdown(for: row)
                if let shownElapsed = effectiveElapsed(for: row) {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color("TimerAccent"))
                        Text("Lit \(format(seconds: shownElapsed))")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(4.5)
        .frame(width: 118, height: 118)
    }

    /// Timer name + glanceable core temp (only when the probe is attached to
    /// this cook), on a full-width line between the ring and the buttons.
    private func nameLine(for row: WatchTimersModel.Row) -> some View {
        HStack(spacing: 5) {
            Text(row.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
            if let probe = probeModel.probe, probe.connected, let core = probe.coreC,
               probe.attachedCookID == row.id {
                HStack(spacing: 2) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("TimerAccent"))
                    Text(probe.unit.compactString(fromCelsius: core))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color("TimerAccent"))
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // Full-screen alert; tap anywhere to acknowledge/stop. Covers the whole
    // display on purpose: while an alert is showing, the preset/start buttons
    // underneath must not be reachable, so a stray tap can't start a timer.
    @ViewBuilder
    private var alertBanner: some View {
        if let message = model.alertMessage {
            Button {
                // Tell the iPhone to stop the alert, and hide locally
                var payload: [String: Any] = ["action": "ackAlert"]
                if let id = selectedTimerId { payload["timerId"] = id }
                WCSessionManager.shared.sendCommand(payload)
                model.alertMessage = nil
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34))
                    Text(message)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Text("Tap to dismiss")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("TimerRed"))
            }
            .buttonStyle(.plain)
            .ignoresSafeArea()
        }
    }

    // Probe cook moment (pull now / target reached / resting done). Mirrors the
    // red timer banner, but green — green reads "food is ready" and is the
    // visual opposite of the timer red, matching the iPhone's green card.
    @ViewBuilder
    private var probeAlertBanner: some View {
        if let event = probeAlertModel.alert {
            Button {
                probeAlertModel.alert = nil
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "thermometer.high")
                        .font(.system(size: 30))
                    if let cookName = event.cookName {
                        Text(cookName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if let tempText = event.tempText {
                        Text(tempText)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text(event.title)
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("Tap to dismiss")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.green)
            }
            .buttonStyle(.plain)
            .ignoresSafeArea()
        }
    }

    private func format(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        // Show hours for long presets/elapsed (e.g. 1:30:00, not 90:00) to match
        // the iPhone's timeLabel formatting — including no leading zero on
        // minutes ("5:00", not "05:00"), so idle and running text agree.
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // Build the button label using preset1 seconds if present; fallback to generic
    private func preset1Label(for row: WatchTimersModel.Row) -> String {
        if let preset = row.preset1Seconds {
            return format(seconds: preset)
        }
        return "Preset 1"
    }

    private func preset2Label(for row: WatchTimersModel.Row) -> String {
        // Plain time label to match the iPhone card (the action starts the
        // preset, it doesn't add time — the old "+" prefix was misleading).
        if let preset = row.preset2Seconds {
            return format(seconds: preset)
        }
        return "Preset 2"
    }

    // MARK: - Local time computations for smooth UI
    private func isRunning(_ row: WatchTimersModel.Row) -> Bool {
        row.state == "running"
    }

    private func effectiveRemaining(for row: WatchTimersModel.Row) -> Int {
        guard isRunning(row) else { return row.remaining }
        // Use absolute endDate when available — stays correct across watch suspension.
        if let end = row.endDate {
            return max(0, Int(end.timeIntervalSinceNow))
        }
        // Fallback for snapshots without endDate: subtract elapsed time since snapshot.
        guard let snap = model.lastSnapshotAt else { return row.remaining }
        let delta = max(0, Int(now.timeIntervalSince(snap)))
        if delta > 5 {
            WCSessionManager.shared.sendCommand(["action": "requestSnapshot"])
        }
        return max(0, row.remaining - delta)
    }

    private func effectiveElapsed(for row: WatchTimersModel.Row) -> Int? {
        guard let base = row.elapsedSeconds else { return nil }
        guard isRunning(row), let snap = model.lastSnapshotAt else { return base }
        let delta = max(0, Int(now.timeIntervalSince(snap)))
        return max(0, base + delta)
    }

    // System-managed countdown — self-updates without app code running,
    // so it stays live on Always-On Display even when the watch is suspended.
    @ViewBuilder
    private func remainingCountdown(for row: WatchTimersModel.Row) -> some View {
        if let end = row.endDate, isRunning(row), end > Date() {
            Text(timerInterval: Date.now...end, countsDown: true)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        } else {
            Text(format(seconds: effectiveRemaining(for: row)))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // Dark label color for text on the solid accent button (matches the
    // iPhone's GlassActionButtonStyle onAccent).
    private var onAccent: Color { Color(red: 0.30, green: 0.13, blue: 0.02) }

    // Preset buttons styled like the iPhone card: primary = solid accent with
    // play icon, secondary = quiet translucent chip. Actions unchanged.
    @ViewBuilder
    private func presetButtons(for row: WatchTimersModel.Row) -> some View {
        HStack(spacing: 6) {
            Button {
                // Stronger confirmation haptic on preset apply
                WKInterfaceDevice.current().play(.success)
                // Optimistically apply Preset 1 and start immediately for snappy UX
                if let preset = row.preset1Seconds {
                    optimisticStart(row, remainingOverride: preset)
                    refreshExtendedRuntimeSession()
                }
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset1",
                    "timerId": row.id
                ])
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(preset1Label(for: row))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundColor(onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 39)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color("TimerAccent")))
            }
            .buttonStyle(.plain)

            Button {
                // Stronger confirmation haptic on preset apply
                WKInterfaceDevice.current().play(.success)
                // Optimistically apply Preset 2 and start immediately for snappy UX
                if let preset = row.preset2Seconds {
                    optimisticStart(row, remainingOverride: preset)
                    refreshExtendedRuntimeSession()
                }
                WCSessionManager.shared.sendCommand([
                    "action": "applyPreset2",
                    "timerId": row.id
                ])
            } label: {
                Text(preset2Label(for: row))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 39)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Optimistic UI helpers
    /// Immediately reflect a local start so the countdown and state change without
    /// waiting for the iPhone round-trip. The next snapshot will reconcile if needed.
    private func optimisticStart(_ row: WatchTimersModel.Row, remainingOverride: Int? = nil) {
        let newRemaining = max(1, remainingOverride ?? effectiveRemaining(for: row))
        let optimisticEnd = Date().addingTimeInterval(TimeInterval(newRemaining))
        model.lastSnapshotAt = Date()
        model.timers = model.timers.map { item in
            if item.id == row.id {
                return WatchTimersModel.Row(
                    id: item.id,
                    name: item.name,
                    remaining: newRemaining,
                    state: "running",
                    preset1Seconds: item.preset1Seconds,
                    preset2Seconds: item.preset2Seconds,
                    elapsedSeconds: item.elapsedSeconds,
                    endDate: optimisticEnd,
                    // A preset start runs for exactly the preset length, so the
                    // ring starts full; the next phone snapshot reconciles.
                    runDurationSeconds: newRemaining
                )
            }
            return item
        }
    }

    /// Manages the extended runtime session to keep the app active while timers are running.
    /// This helps prevent the watch from going back to the watch face too quickly.
    private func refreshExtendedRuntimeSession() {
        // Refreshed here rather than at init: the controller outlives any single
        // body evaluation, and this closure must read the CURRENT timer list.
        // Capture the model OBJECT, not the view struct — a captured struct copy
        // freezes whatever it held at capture time (the scenePhase bug, #57).
        let timersModel = model
        runtime.isTimerRunning = { timersModel.timers.contains { $0.state == "running" } }
        if hasRunningTimer {
            // Start extended runtime if a timer is running
            if !runtime.isRunning {
                debugLog("[⌚️Watch] 🔋 Starting extended runtime session (timer running)")
                runtime.startIfNeeded()
            }
        } else {
            // Stop extended runtime if no timers are running
            if runtime.isRunning {
                debugLog("[⌚️Watch] 🔋 Stopping extended runtime session (no timers running)")
                runtime.invalidate()
            }
        }
    }
    
    // MARK: - Ticker Management (Battery Optimization)
    
    /// Starts the 1-second UI ticker if not already running.
    /// Only runs when timers are active to save battery.
    private func startTickerIfNeeded() {
        guard activeTickerTimer == nil else {
            // Ticker already running
            return
        }
        
        debugLog("[⌚️Watch] ⏱️ Starting UI ticker (timer is running)")
        activeTickerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            now = Date()
        }
        // Ensure the timer fires even during scrolling
        if let timer = activeTickerTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stops the UI ticker to conserve battery when no timers are running.
    private func stopTicker() {
        guard activeTickerTimer != nil else {
            // Ticker not running
            return
        }
        
        debugLog("[⌚️Watch] ⏱️ Stopping UI ticker (no timers running) - saving battery")
        activeTickerTimer?.invalidate()
        activeTickerTimer = nil
    }
}

final class WatchTimersModel: ObservableObject {
    // Conform to Equatable so Array<Row> can be used with onChange(of:)
    struct Row: Identifiable, Equatable {
        let id: String
        let name: String
        let remaining: Int          // snapshot value; prefer endDate for live display
        let state: String
        let preset1Seconds: Int?
        let preset2Seconds: Int?
        let elapsedSeconds: Int?
        // Absolute end time from iPhone — survives watch suspension without drift.
        let endDate: Date?
        // Total run duration (seconds) — drives the countdown ring's fill.
        // Nil when the paired iPhone app predates the "runDuration" snapshot key.
        let runDurationSeconds: Int?
    }

    @Published var timers: [Row] = []
    // When the last snapshot was received (used for local ticking)
    @Published var lastSnapshotAt: Date? = nil
    // Message to show in the alert banner when iPhone signals an alert
    @Published var alertMessage: String? = nil
    // Set when a snapshot shows a timer that just transitioned to running (e.g.
    // started from the iPhone) — the pager focuses it so the user can see it's
    // going. Starts made on the watch don't trigger this: the optimistic local
    // update already marks that timer running before the phone's snapshot echoes
    // back. The view consumes the value and resets it to nil.
    @Published var focusTimerId: String? = nil

    init() {
        debugLog("[⌚️Watch] WatchTimersModel initialized - setting up notification observers")
        
        // Log current timer count for debugging
        debugLog("[⌚️Watch] Current timers count at init: \(timers.count)")
        
        NotificationCenter.default.addObserver(forName: Notification.Name("receivedTimersSnapshot"), object: nil, queue: .main) { [weak self] note in
            debugLog("[⌚️Watch] 🔔 receivedTimersSnapshot notification RECEIVED")
            
            guard let dict = note.userInfo as? [String: Any] else {
                debugLog("[⌚️Watch] ❌ receivedTimersSnapshot: NO userInfo dictionary!")
                return
            }
            
            debugLog("[⌚️Watch] 📦 userInfo keys: \(dict.keys.joined(separator: ", "))")
            
            guard let arr = dict["timers"] as? [[String: Any]] else {
                debugLog("[⌚️Watch] ❌ receivedTimersSnapshot: missing 'timers' array. Available keys: \(dict.keys)")
                return
            }
            
            debugLog("[⌚️Watch] ✅ Found timers array with \(arr.count) items")
            
            // Log each timer in the received snapshot
            for (index, timer) in arr.enumerated() {
                let name = timer["name"] as? String ?? "?"
                let state = timer["state"] as? String ?? "?"
                let remaining = timer["remaining"] as? Int ?? 0
                debugLog("[⌚️Watch]   📋 Timer \(index+1): '\(name)' - state=\(state) - \(remaining)s remaining")
            }
            
            let snapshotDate = Date()
            self?.lastSnapshotAt = snapshotDate
            
            // Parse timers and track any parsing failures
            let parsedTimers = arr.compactMap { item -> Row? in
                guard let id = item["id"] as? String else {
                    debugLog("[⌚️Watch] ⚠️ Timer missing 'id' field")
                    return nil
                }
                guard let name = item["name"] as? String else {
                    debugLog("[⌚️Watch] ⚠️ Timer \(id) missing 'name' field")
                    return nil
                }
                guard let remaining = item["remaining"] as? Int else {
                    debugLog("[⌚️Watch] ⚠️ Timer \(name) missing 'remaining' field")
                    return nil
                }
                guard let state = item["state"] as? String else {
                    debugLog("[⌚️Watch] ⚠️ Timer \(name) missing 'state' field")
                    return nil
                }
                let preset1 = item["preset1"] as? Int
                let preset2 = item["preset2"] as? Int
                let elapsed = item["elapsed"] as? Int
                let endDate: Date? = (item["endDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
                let runDuration = item["runDuration"] as? Int
                return Row(id: id, name: name, remaining: remaining, state: state, preset1Seconds: preset1, preset2Seconds: preset2, elapsedSeconds: elapsed, endDate: endDate, runDurationSeconds: runDuration)
            }
            
            let previousRows = self?.timers ?? []
            let previousCount = previousRows.count
            self?.timers = parsedTimers
            debugLog("[⌚️Watch] ✅ Updated timers: \(previousCount) → \(parsedTimers.count)")

            // Focus a timer that just started running (set after `timers` so the
            // page exists by the time the view reacts to focusTimerId).
            let previouslyRunning = Set(previousRows.filter { $0.state == "running" }.map { $0.id })
            if let newlyStarted = parsedTimers.first(where: { $0.state == "running" && !previouslyRunning.contains($0.id) }) {
                debugLog("[⌚️Watch] 🎯 Timer '\(newlyStarted.name)' newly running — requesting focus")
                self?.focusTimerId = newlyStarted.id
            }
            
            // Update complication with the soonest finishing timer
            if let timers = self?.timers {
                ComplicationDataSource.shared.updateSoonestTimer(from: timers, snapshotDate: snapshotDate)
                
                // Log final state of all timers
                debugLog("[⌚️Watch] 📊 Final timer states after update:")
                for (index, timer) in timers.enumerated() {
                    debugLog("[⌚️Watch]   \(index+1). \(timer.name): \(timer.state) - \(timer.remaining)s")
                }
            }
        }
        
        // Listen for explicit alert messages sent from iPhone via the session manager
        NotificationCenter.default.addObserver(forName: Notification.Name("receivedAlert"), object: nil, queue: .main) { [weak self] note in
            debugLog("[⌚️Watch] 🔔 receivedAlert notification")
            guard let info = note.userInfo as? [String: Any], let phase = info["phase"] as? String else {
                debugLog("[⌚️Watch] ⚠️ receivedAlert: missing phase")
                return
            }
            debugLog("[⌚️Watch] Alert phase: \(phase)")
            if phase == "start" {
                let msg = (info["message"] as? String) ?? "Timer Finished"
                self?.alertMessage = msg
                debugLog("[⌚️Watch] 🚨 Showing alert: \(msg)")
            } else if phase == "stop" {
                self?.alertMessage = nil
                debugLog("[⌚️Watch] ✅ Alert dismissed")
            }
        }
        
        debugLog("[⌚️Watch] ✅ WatchTimersModel notification observers registered")
    }
}

// MARK: - Extended runtime controller
/// Lightweight wrapper around `WKExtendedRuntimeSession` that starts a background
/// execution window while timers are active, helping keep the app active longer
/// and allowing it to continue running when the user lowers their wrist.
final class ExtendedRuntimeController: NSObject, WKExtendedRuntimeSessionDelegate {
    private var session: WKExtendedRuntimeSession?
    private(set) var isRunning: Bool = false

    /// Asked at invalidation time whether a cook timer is still counting down.
    /// Set by the view; nil means "assume nothing to keep alive".
    var isTimerRunning: (() -> Bool)?

    /// When the session that is ending began, so the restart policy can tell a
    /// genuine hour-long expiry from a session that failed immediately.
    private var sessionStartedAt: Date?

    /// Injectable clock, so the restart decision never depends on wall time in
    /// a way tests can't reach.
    var now: () -> Date = Date.init

    /// Start a new extended runtime session if not already running.
    func startIfNeeded() {
        if isRunning {
            debugLog("[⌚️Watch] 🔋 Extended runtime already running, skipping start")
            return
        }
        
        debugLog("[⌚️Watch] 🔋 Creating new extended runtime session...")
        
        // Always create a fresh session to avoid edge states
        session?.invalidate()
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession
        newSession.start()
        
        debugLog("[⌚️Watch] 🔋 Extended runtime session start() called")
    }

    /// End the session if one is active.
    func invalidate() {
        guard let s = session else {
            debugLog("[⌚️Watch] 🔋 No extended runtime session to invalidate")
            return
        }
        debugLog("[⌚️Watch] 🔋 Invalidating extended runtime session...")
        s.invalidate()
        session = nil
        isRunning = false
    }

    // MARK: - WKExtendedRuntimeSessionDelegate
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        isRunning = true
        sessionStartedAt = now()
        debugLog("[⌚️Watch] ✅ Extended runtime session STARTED successfully")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        debugLog("[⌚️Watch] ⚠️ Extended runtime session will EXPIRE soon")
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        isRunning = false
        session = nil
        
        // Describe the invalidation reason (API varies by watchOS version)
        let reasonDescription: String
        switch reason {
        case .none: reasonDescription = "none"
        case .error: reasonDescription = "error"
        case .expired: reasonDescription = "expired"
        case .resignedFrontmost: reasonDescription = "resignedFrontmost"
        case .sessionInProgress: reasonDescription = "sessionInProgress"
        case .suppressedBySystem: reasonDescription = "suppressedBySystem"
        @unknown default: reasonDescription = "unknown(\(reason.rawValue))"
        }
        
        if let error = error {
            debugLog("[⌚️Watch] ❌ Extended runtime INVALIDATED: \(reasonDescription), error: \(error.localizedDescription)")
        } else {
            debugLog("[⌚️Watch] 🔋 Extended runtime INVALIDATED: \(reasonDescription)")
        }

        // watchOS caps a session at about an hour. Renew it so a long cook
        // (brisket, pork butt) keeps ticking on the wrist instead of going
        // quiet halfway through. Only on a genuine expiry, only while a cook is
        // still running, and only if the session actually lived a while — see
        // ExtendedRuntimeRestartPolicy.
        let lifetime = sessionStartedAt.map { now().timeIntervalSince($0) } ?? 0
        sessionStartedAt = nil
        guard ExtendedRuntimeRestartPolicy.shouldRestart(
            expired: reason == .expired,
            timerRunning: isTimerRunning?() ?? false,
            sessionLifetime: lifetime
        ) else { return }

        // A short breath before reopening: watchOS refuses a new session that
        // starts inside the invalidation callback.
        debugLog("[⌚️Watch] 🔋 Session expired after \(Int(lifetime))s with a cook running — renewing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.isTimerRunning?() == true else { return }
            self.startIfNeeded()
        }
    }
}

// MARK: - SwiftUI Preview
// This preview enables Xcode Canvas for the watch UI.
// It renders `TimersListView`, which shows either the empty state
// or any timers provided by a snapshot during previews.
#if DEBUG
// Break the large literal into simple constants the compiler can type-check quickly.
private func previewSampleTimers() -> [[String: Any]] {
    let t1: [String: Any] = [
        "id": UUID().uuidString,
        "name": "Ribeye",
        "remaining": 300,
        "state": "running",
        "preset1": 300,
        "preset2": 60,
        "elapsed": 0
    ]
    let t2: [String: Any] = [
        "id": UUID().uuidString,
        "name": "Tri‑Tip",
        "remaining": 900,
        "state": "stopped",
        "preset1": 900,
        "preset2": 120,
        "elapsed": 0
    ]
    return [t1, t2]
}

#Preview {
    TimersListView()
}

#Preview("With sample timers") {
    // Preview that injects a mock snapshot so Canvas shows real rows
    TimersListView()
        .onAppear {
            let timers: [[String: Any]] = previewSampleTimers()
            NotificationCenter.default.post(
                name: Notification.Name("receivedTimersSnapshot"),
                object: nil,
                userInfo: ["timers": timers]
            )
        }
}
#endif


// MARK: - Ember background (watch)

/// Watch-sized version of the iPhone's `EmberBackground` (ButtonStyles.swift):
/// the same deep-charcoal base with radial "coal" glows, but fewer and softer
/// spots so white text stays readable on the small display. Duplicated here
/// because the watch target compiles only its own files.
struct WatchEmberBackground: View {
    /// (x, y) are unit positions; r is a fraction of width for the glow radius.
    private var emberSpots: [(x: CGFloat, y: CGFloat, r: CGFloat, color: Color, opacity: Double)] {
        let orange = Color(red: 0.96, green: 0.46, blue: 0.10)
        let redOrange = Color(red: 0.86, green: 0.26, blue: 0.06)
        let red = Color(red: 0.74, green: 0.14, blue: 0.05)
        let amber = Color(red: 1.00, green: 0.56, blue: 0.14)
        return [
            (0.18, 0.08, 0.34, orange,    0.34),
            (0.85, 0.14, 0.30, redOrange, 0.32),
            (0.10, 0.52, 0.28, red,       0.28),
            (0.62, 0.44, 0.26, amber,     0.24),
            (0.38, 0.86, 0.34, orange,    0.30),
            (0.90, 0.80, 0.28, redOrange, 0.28)
        ]
    }

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.035, blue: 0.02)
            GeometryReader { geo in
                ZStack {
                    ForEach(emberSpots.indices, id: \.self) { i in
                        let e = emberSpots[i]
                        RadialGradient(
                            colors: [e.color.opacity(e.opacity), Color.clear],
                            center: UnitPoint(x: e.x, y: e.y),
                            startRadius: 0,
                            endRadius: geo.size.width * e.r
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
