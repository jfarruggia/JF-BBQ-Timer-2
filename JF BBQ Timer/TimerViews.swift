import SwiftUI
import UIKit

// MARK: - CardProbeInfo

#if os(iOS)
/// Computed probe data passed into a timer card. Non-nil only when the probe is
/// connected (or reconnecting) AND attached to the card's cook. All expensive
/// logic lives in ContentView.probeInfo(for:) — these views stay dumb.
struct CardProbeInfo: Equatable {
    /// Formatted core temperature string, e.g. "63°" or "—" when no valid reading.
    var coreText: String
    /// Formatted surface temperature, "—" when no valid reading, nil when the
    /// user has hidden surface temp in Settings ▸ Temperature Probe.
    var surfaceText: String? = nil
    /// Formatted ambient temperature; same rules as `surfaceText`.
    var ambientText: String? = nil
    /// Non-nil only when the probe is actively predicting a ready time.
    var readyDate: Date?
    /// False when the user has hidden the predicted-ready slot in Settings.
    var showReady: Bool = true
}
#endif

struct ButtonPreview: View {
    let preset: PresetInterval

    var body: some View {
        Text(preset.displayName)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color.purple)
            .cornerRadius(8)
    }
}

struct TimerHeaderView: View {
    let name: String
    @ObservedObject private var debugSettings = DebugVisualizerSettings.shared

    var body: some View {
        Text(name)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.black)
            .shadow(color: .white.opacity(0.7), radius: 1, x: 0, y: 1)
            .padding(.vertical, 4)
            .if(debugSettings.isEnabled && debugSettings.showLabels) { view in
                view.debugFrame(
                    debugSettings.showFrames,
                    color: .blue,
                    showPadding: debugSettings.showPadding,
                    showBackground: debugSettings.showBackgrounds,
                    label: "Timer Header"
                )
            }
    }
}

struct FlipTimerView: View {
    var timeInterval: TimeInterval
    var theme: Theme

    var body: some View {
        Text(TimeFormatter.timeString(from: Int(timeInterval)))
            .font(.system(size: 84, weight: .bold, design: .rounded))
            .foregroundColor(theme.accentColor)
            .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
            .frame(height: 100)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .animation(.easeInOut, value: timeInterval)
            .id("interval-\(timeInterval)")
    }
}

struct IntervalTimerView: View {
    @ObservedObject var timerState: TimerState
    var theme: Theme

    var body: some View {
        intervalContent
    }

    @ViewBuilder
    private var intervalContent: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 2) {
                Text("FLIP IN")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("TimerAccent"))
                    .shadow(color: Color.black.opacity(0.8), radius: 3, x: 0, y: 2)
                    .padding(.top, 2)
                Text(TimeFormatter.timeString(from: Int(timerState.intervalTime)))
                    .font(.system(size: 84, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .frame(height: 100)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .animation(.easeInOut, value: timerState.intervalTime)
                    .id("interval-\(timerState.intervalTime)")
                    .padding(.bottom, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 2) {
                Text("FLIP IN")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("TimerAccent"))
                    .shadow(color: Color.black.opacity(0.7), radius: 3, x: 0, y: 2)
                    .padding(.top, 2)
                FlipTimerView(timeInterval: timerState.intervalTime, theme: theme)
                    .padding(.bottom, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(theme.backgroundColor)
            .cornerRadius(16)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ElapsedTimerView: View {
    @ObservedObject var timerState: TimerState
    var theme: Theme

    var body: some View {
        elapsedContent
    }

    @ViewBuilder
    private var elapsedContent: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color("TimerRed"))
                        .font(.system(size: 24))
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Text("LIT TIME")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("TimerAccent"))
                        .shadow(color: Color.black.opacity(0.8), radius: 3, x: 0, y: 2)
                }
                .padding(.top, 2)
                Text(TimeFormatter.timeString(from: Int(timerState.elapsedTime)))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .animation(.easeInOut, value: timerState.elapsedTime)
                    .id("elapsed-\(timerState.elapsedTime)")
                    .padding(.bottom, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color("TimerRed"))
                        .font(.system(size: 24))
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Text("LIT TIME")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("TimerAccent"))
                        .shadow(color: Color.black.opacity(0.7), radius: 3, x: 0, y: 2)
                }
                .padding(.top, 2)
                Text(TimeFormatter.timeString(from: Int(timerState.elapsedTime)))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accentColor)
                    .shadow(color: Color.black.opacity(0.7), radius: 4, x: 0, y: 2)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .animation(.easeInOut, value: timerState.elapsedTime)
                    .id("elapsed-\(timerState.elapsedTime)")
                    .padding(.bottom, 2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(theme.backgroundColor)
            .cornerRadius(16)
            .frame(maxWidth: .infinity)
        }
    }
}

struct TimerPresetButton: View {
    let presetTime: TimeInterval
    let timeStringConverter: (TimeInterval) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(timeStringConverter(presetTime))
        }
        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0))))
    }
}

struct TimerControlButtons: View {
    @ObservedObject var state: TimerState
    let settings: Settings
    @ObservedObject var alertState: AlertState

    var body: some View {
        HStack(spacing: 16) {
            if state.isRunning {
                Button(action: {
                    state.stop()
                    settings.stopLoopingAlertSound()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(ElevatedButtonStyle(tint: .red))
            }
            Button(action: {
                state.reset()
                settings.stopLoopingAlertSound()
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ElevatedButtonStyle(tint: .blue))
        }
    }
}

struct DebugPanel: View {
    @ObservedObject var settings: DebugVisualizerSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Options")
                .font(.headline)
                .padding(.bottom, 4)

            Toggle("Show Frames", isOn: $settings.showFrames)
            Toggle("Show Padding", isOn: $settings.showPadding)
            Toggle("Show Backgrounds", isOn: $settings.showBackgrounds)
            Toggle("Show Labels", isOn: $settings.showLabels)
            Toggle("Show Grid", isOn: $settings.showGrid)

            if settings.showGrid {
                HStack(spacing: 12) {
                    Text("Grid Spacing:")
                    Slider(value: $settings.gridSpacing, in: 5...50, step: 5)
                    Text("\(Int(settings.gridSpacing))")
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding()
    }
}

struct CompactTimerView: View {
    let name: String
    let preset1: TimeInterval
    let preset2: TimeInterval
    @ObservedObject var state: TimerState
    var settings: Settings
    var alertState: AlertState
    #if os(iOS)
    var probeInfo: CardProbeInfo? = nil
    #endif

    var body: some View {
        VStack(spacing: 4) {
            let screenWidth = UIScreen.main.bounds.width
            let isVerySmall = screenWidth < 360
            let isLargePhone = screenWidth > 430
            let rowSpacing: CGFloat = isVerySmall ? 6 : (isLargePhone ? 12 : 8)
            let panelHPad: CGFloat = isVerySmall ? 10 : (isLargePhone ? 18 : 12)
            let timerPanelMinWidth: CGFloat? = isVerySmall ? 160 : nil
            let buttonsMinWidth: CGFloat? = isVerySmall ? 130 : nil
            HStack(spacing: rowSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Flip In")
                            .foregroundColor(Theme.defaultTheme.textColor)
                        Text(TimeFormatter.timeString(from: Int(state.intervalTime)))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .animation(.easeInOut, value: state.intervalTime)
                            .id("interval-\(state.intervalTime)")
                            .foregroundColor(Theme.defaultTheme.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Text("Lit Time")
                                .foregroundColor(Theme.defaultTheme.textColor)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                        Text(TimeFormatter.timeString(from: Int(state.elapsedTime)))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .animation(.easeInOut, value: state.elapsedTime)
                            .id("elapsed-\(state.elapsedTime)")
                            .foregroundColor(Theme.defaultTheme.accentColor)
                    }
                }
                .padding(.horizontal, panelHPad)
                .padding(.vertical, 2)
                .background(
                    Group {
                        if #available(iOS 26, *) {
                            Color.black.opacity(0.35)
                        } else {
                            Theme.defaultTheme.backgroundColor
                        }
                    }
                )
                .cornerRadius(14)
                .padding(.leading, 2)
                .frame(maxWidth: .infinity)
                .frame(minWidth: timerPanelMinWidth)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Button(action: {
                            state.stop()
                            state.setCurrentIntervalTime(preset1)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }) {
                            Text(verbatim: {
                                let total = max(0, Int(preset1))
                                let hours = total / 3600
                                let minutes = (total % 3600) / 60
                                let seconds = total % 60
                                if hours > 0 {
                                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    return String(format: "%d:%02d", minutes, seconds)
                                }
                            }())
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0)), height: 40, fontSize: 16))

                        Button(action: {
                            state.stop()
                            state.setCurrentIntervalTime(preset2)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                state.start {
                                    if settings.soundEnabled { state.playSound() }
                                    if settings.hapticsEnabled { alertState.isPresented = true }
                                }
                            }
                        }) {
                            Text(verbatim: {
                                let total = max(0, Int(preset2))
                                let hours = total / 3600
                                let minutes = (total % 3600) / 60
                                let seconds = total % 60
                                if hours > 0 {
                                    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
                                } else {
                                    return String(format: "%d:%02d", minutes, seconds)
                                }
                            }())
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: Color(UIColor(red: 70/255, green: 70/255, blue: 70/255, alpha: 1.0)), height: 40, fontSize: 16))
                    }

                    HStack(spacing: 8) {
                        if state.isRunning {
                            Button(action: {
                                state.stop()
                                settings.stopLoopingAlertSound()
                            }) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(ElevatedButtonStyle(tint: .red, height: 40, fontSize: 16))
                        }
                        Button(action: {
                            state.reset()
                            settings.stopLoopingAlertSound()
                        }) {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(ElevatedButtonStyle(tint: .blue, height: 40, fontSize: 16))
                    }
                }
                .frame(minWidth: buttonsMinWidth)
                .padding(.trailing, 8)
            }

            #if os(iOS)
            if let info = probeInfo {
                Divider()
                    .padding(.horizontal, 4)

                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("TimerAccent"))
                    Text("Core")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(info.coreText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Color("TimerAccent"))
                    if let surface = info.surfaceText {
                        Text("Sfc \(surface)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    if let ambient = info.ambientText {
                        Text("Amb \(ambient)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if info.showReady {
                        Text("ready")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        if #available(iOS 16, *), let readyDate = info.readyDate {
                            Text(timerInterval: Date()...readyDate, countsDown: true)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Text(info.readyDate != nil ? "~" : "—")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
            #endif
        }
    }
}

// MARK: - iOS 26 Liquid Glass redesign (large timer card)

/// Circular countdown ring shared by the large and compact glass cards. The
/// orange arc shows how much of the run remains; `center` supplies the
/// number/labels drawn inside it.
@available(iOS 26.0, *)
struct CircularTimerRing<Center: View>: View {
    /// 0...1 remaining (1 = full, 0 = complete).
    var progress: Double
    var lineWidth: CGFloat
    @ViewBuilder var center: () -> Center

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, progress))
                .stroke(
                    Color("TimerAccent"),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            center()
                .padding(lineWidth + 6)
        }
    }
}

/// Redesigned content for a large timer card on iOS 26.
///
/// Direction (see design review): one hero number ("Flip in"), the elapsed
/// "Lit" time demoted to a quiet secondary line, no black text shadows, a
/// single warm accent for the primary action, and translucent controls so the
/// glass card material actually reads through. This view is the *content* only —
/// the glass material, completion-flash border and adaptive height still come
/// from `.timerContainerAppearance(isLargeTimer:)` applied by the caller, so the
/// timer mechanics are untouched.
@available(iOS 26.0, *)
struct GlassLargeTimerContent: View {
    let timer: BBQTimer
    @ObservedObject var state: TimerState
    let settings: Settings
    @ObservedObject var alertState: AlertState
    #if os(iOS)
    var probeInfo: CardProbeInfo? = nil
    #endif

    private func startWithPreset(_ preset: TimeInterval) {
        state.stop()
        state.setCurrentIntervalTime(preset)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            state.start {
                if settings.soundEnabled { state.playSound() }
                if settings.hapticsEnabled { alertState.isPresented = true }
            }
        }
    }

    /// mm:ss, expanding to h:mm:ss only when there are whole hours.
    private func timeLabel(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(timer.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
            }

            CircularTimerRing(progress: state.progress(at: Date()), lineWidth: 12) {
                VStack(spacing: 3) {
                    Text("Flip in")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    Text(timeLabel(Int(state.intervalTime)))
                        .font(.system(size: 54, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: state.intervalTime)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("TimerAccent"))
                        Text("Lit \(timeLabel(Int(state.elapsedTime)))")
                            .font(.system(size: 16, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    }
                }
            }
            .frame(width: 155, height: 155)

            HStack(spacing: 10) {
                Button {
                    startWithPreset(TimeInterval(timer.preset1))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 13))
                        Text(timeLabel(timer.preset1))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassActionButtonStyle(kind: .primary))

                Button {
                    startWithPreset(TimeInterval(timer.preset2))
                } label: {
                    Text(timeLabel(timer.preset2))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassActionButtonStyle(kind: .secondary))
            }

            HStack(spacing: 20) {
                if state.isRunning {
                    Button {
                        state.stop()
                        settings.stopLoopingAlertSound()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color("TimerRed"))
                }
                Button {
                    state.reset()
                    settings.stopLoopingAlertSound()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            .buttonStyle(.plain)

            #if os(iOS)
            if let info = probeInfo {
                Divider()
                    .overlay(Color.white.opacity(0.25))

                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color("TimerAccent"))
                    Text("Core")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(info.coreText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color("TimerAccent"))
                    if let surface = info.surfaceText {
                        Text("Sfc \(surface)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if let ambient = info.ambientText {
                        Text("Amb \(ambient)")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if info.showReady {
                        Text("ready")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        if let readyDate = info.readyDate {
                            Text(timerInterval: Date()...readyDate, countsDown: true)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        } else {
                            Text("—")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

/// Button style for the glass timer card's actions. Primary is a solid warm
/// accent pill (a control sitting *on* the glass — deliberately not glass, to
/// avoid stacking glass on glass); secondary is a quiet translucent chip.
@available(iOS 26.0, *)
struct GlassActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    var compact: Bool = false

    private let onAccent = Color(red: 0.30, green: 0.13, blue: 0.02)

    func makeBody(configuration: Configuration) -> some View {
        let radius: CGFloat = compact ? 11 : 14
        return configuration.label
            .font(.system(size: compact ? 14 : 17, weight: .semibold, design: .rounded))
            .foregroundStyle(kind == .primary ? onAccent : Color.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, compact ? 9 : 13)
            .padding(.horizontal, compact ? 12 : 16)
            .background {
                if kind == .primary {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color("TimerAccent"))
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.tap() }
            }
    }
}

/// Compact-layout counterpart to `GlassLargeTimerContent` for iOS 26. Same visual
/// language (tinted glass, white text, no opaque inner panels, orange accent,
/// clean mm:ss) but a denser horizontal layout — times on the left, controls on
/// the right — so more timers fit on screen. Container glass, completion flash and
/// the onComplete callback still come from `.timerContainerAppearance(...)`.
@available(iOS 26.0, *)
struct GlassCompactTimerContent: View {
    let timer: BBQTimer
    @ObservedObject var state: TimerState
    let settings: Settings
    @ObservedObject var alertState: AlertState
    #if os(iOS)
    var probeInfo: CardProbeInfo? = nil
    #endif

    private func startWithPreset(_ preset: TimeInterval) {
        state.stop()
        state.setCurrentIntervalTime(preset)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            state.start {
                if settings.soundEnabled { state.playSound() }
                if settings.hapticsEnabled { alertState.isPresented = true }
            }
        }
    }

    /// mm:ss, expanding to h:mm:ss only when there are whole hours.
    private func timeLabel(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timer.name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.leading, 16)

            HStack(alignment: .center, spacing: 0) {
                Spacer(minLength: 12)
                VStack(spacing: 4) {
                    CircularTimerRing(progress: state.progress(at: Date()), lineWidth: 7) {
                        VStack(spacing: 1) {
                            Text("Flip in")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                            Text(timeLabel(Int(state.intervalTime)))
                                .font(.system(size: 25, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                                .animation(.easeInOut, value: state.intervalTime)
                                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        }
                    }
                    .frame(width: 84, height: 84)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color("TimerAccent"))
                        Text("Lit \(timeLabel(Int(state.elapsedTime)))")
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 6) {
                    Button {
                        startWithPreset(TimeInterval(timer.preset1))
                    } label: {
                        Text(timeLabel(timer.preset1)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassActionButtonStyle(kind: .primary, compact: true))

                    Button {
                        startWithPreset(TimeInterval(timer.preset2))
                    } label: {
                        Text(timeLabel(timer.preset2)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlassActionButtonStyle(kind: .secondary, compact: true))

                    HStack(spacing: 16) {
                        if state.isRunning {
                            Button {
                                state.stop()
                                settings.stopLoopingAlertSound()
                            } label: {
                                Text("Stop").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color("TimerRed"))
                        }
                        Button {
                            state.reset()
                            settings.stopLoopingAlertSound()
                        } label: {
                            Text("Reset").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .frame(width: 132)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)

            #if os(iOS)
            if let info = probeInfo {
                Divider()
                    .overlay(Color.white.opacity(0.25))
                    .padding(.horizontal, 16)

                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color("TimerAccent"))
                    Text("Core")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(info.coreText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color("TimerAccent"))
                    if let surface = info.surfaceText {
                        Text("Sfc \(surface)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    if let ambient = info.ambientText {
                        Text("Amb \(ambient)")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    if info.showReady {
                        Text("ready")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                        if let readyDate = info.readyDate {
                            Text(timerInterval: Date()...readyDate, countsDown: true)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        } else {
                            Text("—")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}
