import SwiftUI
import UIKit

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

struct ElapsedTimerView: View {
    @ObservedObject var timerState: TimerState
    var theme: Theme

    var body: some View {
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
                .background(Theme.defaultTheme.backgroundColor)
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
        }
    }
}
