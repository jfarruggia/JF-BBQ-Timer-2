import SwiftUI
import AVFoundation

struct AlertView: View {
    @ObservedObject var alertState: AlertState
    let audioPlayer: AVAudioPlayer?
    let isPreheat: Bool
    let settings: Settings
    @ObservedObject var timerState: TimerState

    /// Drives the attention-grabbing border/glow pulse. Toggled once on appear with
    /// a repeating, auto-reversing animation so the rim breathes until dismissed.
    @State private var pulse = false

    private func dismiss() {
        audioPlayer?.stop()
        settings.stopLoopingAlertSound()
        timerState.resetCompletionState()
        if isPreheat {
            alertState.showPreheatAlert = false
        } else {
            alertState.isPresented = false
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { dismiss() }

            Button(action: dismiss) {
                VStack(spacing: 10) {
                    Image(systemName: isPreheat ? "flame.fill" : "checkmark.circle.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.white)
                    if isPreheat {
                        Text("Preheat")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Complete! 🔥")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    } else {
                        Text("Interval\nComplete!")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(width: 240, height: 240)
                .modifier(AlertGlassCardStyle(pulse: pulse))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Frosted completion-alert card: warm glass (clear glass tinted `tint` on iOS 26,
/// solid `tint` fallback pre-26) with a pulsing `tint`-colored rim + glow so it still
/// grabs attention across the room while reading as part of the app's glass language.
/// Red by default (the timer completion card); the probe alert reuses this with green.
private struct AlertGlassCardStyle: ViewModifier {
    let pulse: Bool
    var tint: Color = .red

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let filled: AnyView
        if #available(iOS 26, *) {
            filled = AnyView(
                content
                    .glassEffect(.clear.tint(tint.opacity(0.45)), in: shape)
            )
        } else {
            filled = AnyView(
                content.background(tint, in: shape)
            )
        }
        return filled
            .overlay(
                shape.stroke(tint, lineWidth: pulse ? 9 : 3)
            )
            .shadow(color: tint.opacity(pulse ? 0.85 : 0.35),
                    radius: pulse ? 26 : 10)
            .scaleEffect(pulse ? 1.04 : 1.0)
    }
}

// MARK: - Probe alert (green "act now" card)

/// Content for the in-app probe alert card — pure so it's unit-testable
/// independent of SwiftUI. `nil` for events that stay quiet notification
/// banners (`batteryLow`, `overheating`).
struct ProbeAlertContent: Equatable {
    let symbolName: String
    let cookName: String?
    let tempText: String?
    let message: String

    static func make(event: ProbeCookEvent, tempText: String?, cookName: String?) -> ProbeAlertContent? {
        let message: String
        switch event {
        case .pullNow:
            message = "Pull the food now"
        case .targetReached:
            message = "Target temperature reached"
        case .restingDone:
            message = "Food is ready"
        case .batteryLow, .overheating:
            return nil
        }

        func nonEmpty(_ s: String?) -> String? {
            guard let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else { return nil }
            return trimmed
        }

        return ProbeAlertContent(
            symbolName: "thermometer.high",
            cookName: nonEmpty(cookName),
            tempText: nonEmpty(tempText),
            message: message
        )
    }
}

/// Full-screen green "act now" overlay for probe cook events — mirrors `AlertView`'s
/// red completion card (same tap-to-dismiss, same pulse cadence) but green, per
/// `probe-alert-spec.md`. Carries no sound logic; the caller's existing
/// notification/haptic path (`ContentView.handleProbeCookEvent`) is unchanged and
/// fires independently of whether this card is shown.
struct ProbeAlertView: View {
    let content: ProbeAlertContent
    var onDismiss: () -> Void

    /// Same breathing-rim pulse as `AlertView`.
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { onDismiss() }

            Button(action: onDismiss) {
                VStack(spacing: 10) {
                    Image(systemName: content.symbolName)
                        .font(.system(size: 46, weight: .bold))
                    if let cookName = content.cookName {
                        Text(cookName)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    if let tempText = content.tempText {
                        Text(tempText)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Text(content.message)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(width: 240)
                .frame(minHeight: 240)
                .modifier(AlertGlassCardStyle(pulse: pulse, tint: .green))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct PreheatAlertView: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    @ObservedObject var settings: Settings
    @ObservedObject var timerState: TimerState

    @State private var animationPhase = false
    @State private var animationTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissAlert()
                }
            preheatCard
        }
        .onAppear { startAnimationTimer() }
        .onDisappear { stopAnimationTimer() }
    }

    @ViewBuilder
    private var preheatCard: some View {
        if #available(iOS 26, *) {
            VStack(spacing: 16) {
                Text("Preheat Complete! 🔥")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Button("Dismiss") { dismissAlert() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color("TimerAccent"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(24)
            .glassEffect(.clear.tint(Color.red.opacity(0.45)), in: RoundedRectangle(cornerRadius: 16))
            .modifier(PulsatingBorderModifier(animating: animationPhase))
            .shadow(radius: 8)
        } else {
            VStack(spacing: 16) {
                Text("Preheat Complete! 🔥")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Button("Dismiss") { dismissAlert() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color("TimerAccent"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(16)
            .modifier(PulsatingBorderModifier(animating: animationPhase))
            .shadow(radius: 8)
        }
    }

    private func dismissAlert() {
        settings.stopLoopingAlertSound()
        timerState.resetCompletionState()
        onDismiss()
    }

    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                animationPhase.toggle()
            }
        }
        withAnimation(.easeInOut(duration: 0.6)) {
            animationPhase = true
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}
