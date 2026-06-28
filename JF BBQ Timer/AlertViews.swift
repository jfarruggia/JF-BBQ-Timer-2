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

/// Frosted-red completion-alert card: warm glass (clear glass tinted red on iOS 26,
/// solid red fallback pre-26) with a pulsing red rim + glow so it still grabs attention
/// across the room while reading as part of the app's glass language.
private struct AlertGlassCardStyle: ViewModifier {
    let pulse: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let filled: AnyView
        if #available(iOS 26, *) {
            filled = AnyView(
                content
                    .glassEffect(.clear.tint(Color.red.opacity(0.45)), in: shape)
            )
        } else {
            filled = AnyView(
                content.background(Color.red, in: shape)
            )
        }
        return filled
            .overlay(
                shape.stroke(Color.red, lineWidth: pulse ? 9 : 3)
            )
            .shadow(color: Color.red.opacity(pulse ? 0.85 : 0.35),
                    radius: pulse ? 26 : 10)
            .scaleEffect(pulse ? 1.04 : 1.0)
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
