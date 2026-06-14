import SwiftUI
import AVFoundation

struct AlertView: View {
    @ObservedObject var alertState: AlertState
    let audioPlayer: AVAudioPlayer?
    let isPreheat: Bool
    let settings: Settings
    @ObservedObject var timerState: TimerState

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        debugLog("Background tapped")
                        audioPlayer?.stop()
                        settings.stopLoopingAlertSound()
                        timerState.resetCompletionState()
                        if isPreheat {
                            alertState.showPreheatAlert = false
                        } else {
                            alertState.isPresented = false
                        }
                    }

                Button(action: {
                    debugLog("Button tapped")
                    audioPlayer?.stop()
                    settings.stopLoopingAlertSound()
                    timerState.resetCompletionState()
                    if isPreheat {
                        alertState.showPreheatAlert = false
                    } else {
                        alertState.isPresented = false
                    }
                }) {
                    VStack(spacing: 8) {
                        if isPreheat {
                            Text("Preheat")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("Complete! 🔥")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        } else {
                            Text("Interval Complete!")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 220, height: 220)
                    .background(Color.red)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(radius: 10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .transition(.opacity)
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
                    .multilineTextAlignment(.center)
                Button("Dismiss") { dismissAlert() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(24)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
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
                    .background(Color.blue)
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
