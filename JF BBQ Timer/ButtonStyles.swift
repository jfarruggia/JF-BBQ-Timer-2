import SwiftUI
import UIKit

extension Color {
    /// Shared warm tint applied to Liquid Glass surfaces on iOS 26 (cards,
    /// header, preheat button) so white text keeps contrast against the bright
    /// background and every glass surface reads as the same material.
    static let grillGlassTint = Color(red: 0.40, green: 0.10, blue: 0.05).opacity(0.42)

    /// Subtle warm tint on the cards' clear glass. The card "body" comes mostly from
    /// `grillCardBodyTop`/`grillCardBodyBottom` (a gradient behind the glass); this just
    /// adds a touch of warmth. Tune card transparency via the two body colors below.
    static let grillCardTint = Color(red: 0.40, green: 0.10, blue: 0.05).opacity(0.12)

    /// Card body gradient — a translucent warm pane behind the clear glass. Lighter at
    /// the top, darker at the bottom, so the card reads as a lit-from-above 3D surface
    /// while staying translucent enough that the ember glow shows through. Raise the
    /// opacities for more body/less transparency; lower them for more glow show-through.
    static let grillCardBodyTop = Color(red: 0.42, green: 0.18, blue: 0.10).opacity(0.40)
    static let grillCardBodyBottom = Color(red: 0.16, green: 0.06, blue: 0.03).opacity(0.28)
}

struct BouncyButtonStyle: ButtonStyle {
    let buttonID: UUID
    @Binding var pressedButtonId: UUID?

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == buttonID ? 0.95 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == buttonID ? -0.05 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    pressedButtonId = buttonID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if pressedButtonId == buttonID {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pressedButtonId = nil
                            }
                        }
                    }
                }
            }
    }
}

struct PulsatingButtonStyle: ButtonStyle {
    let buttonID: UUID
    @Binding var pressedButtonId: UUID?

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed || pressedButtonId == buttonID ? 0.92 : 1.0)
            .brightness(configuration.isPressed || pressedButtonId == buttonID ? -0.08 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred()
                    pressedButtonId = buttonID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if pressedButtonId == buttonID {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                                pressedButtonId = nil
                            }
                        }
                    }
                }
            }
    }
}

struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
    }
}

struct ElevatedButtonStyle: SwiftUI.ButtonStyle {
    var tint: Color
    var cornerRadius: CGFloat = 12
    var height: CGFloat = 44
    var fontSize: CGFloat = 18

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.15 : 0.30),
                    radius: configuration.isPressed ? 2 : 6,
                    x: 0, y: configuration.isPressed ? 1 : 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Modifiers

struct PreheatCompleteModifier: ViewModifier {
    let isPreheatComplete: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPreheatComplete ? Color.red : Color.clear, lineWidth: 4)
                    .opacity(isPreheatComplete ? 1.0 : 0)
            )
            .scaleEffect(isPreheatComplete ? 1.05 : 1.0)
            .animation(isPreheatComplete ?
                       .easeInOut(duration: 0.5).repeatForever(autoreverses: true) :
                       .default,
                       value: isPreheatComplete)
    }
}

struct PulsatingBorderModifier: ViewModifier {
    let animating: Bool

    func body(content: Content) -> some View {
        let lineWidth = animating ? 6.0 : 3.0
        let scale = animating ? 1.05 : 1.0
        return content
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red, lineWidth: lineWidth)
            )
            .scaleEffect(scale)
    }
}

struct TimerContainerModifier: ViewModifier {
    let isCompleted: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isCompleted ? Color.red : Color.black, lineWidth: isCompleted ? 12 : 2)
            )
            .animation(.easeInOut(duration: 0.3), value: isCompleted)
    }
}

extension View {
    func timerContainer(isCompleted: Bool) -> some View {
        modifier(TimerContainerModifier(isCompleted: isCompleted))
    }
}

struct TimerContainerAppearance: ViewModifier {
    @ObservedObject var timerState: TimerState
    @State private var previousIntervalTime: TimeInterval = 0
    var onTimerComplete: ((UUID) -> Void)?
    var skipBorder: Bool = false
    var isLargeTimer: Bool = false

    func body(content: Content) -> some View {
        styledCard(content)
            .overlay(cardBorder)
            .if(isLargeTimer) { view in
                view
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: calculateAdaptiveHeight())
            }
            .onChange(of: timerState.intervalTime) { _ in
                let newValue = timerState.intervalTime
                let oldValue = previousIntervalTime
                if oldValue > 0 && newValue == 0 {
                    onTimerComplete?(timerState.id)
                }
                previousIntervalTime = newValue
            }
            .onAppear {
                previousIntervalTime = timerState.intervalTime
            }
    }

    @ViewBuilder
    private func styledCard(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            // "Pronounced" depth treatment: clear glass so the ember-glow background
            // reads through, a top-edge specular rim, and a deep drop shadow for lift.
            // Header and preheat bar keep .regular + the shared grillGlassTint; only
            // the card uses .clear here, with a card-local warm tint overlay.
            let shape = RoundedRectangle(cornerRadius: 15)
            if isLargeTimer {
                content
                    .padding(.vertical, 8)
                    .glassEffect(
                        .clear.tint(.grillCardTint),
                        in: shape
                    )
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
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
            } else {
                content
                    .glassEffect(
                        .clear.tint(.grillCardTint),
                        in: shape
                    )
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
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                    )
                    .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 10)
            }
        } else {
            content
                .padding(.vertical, isLargeTimer ? 8 : 0)
                .background(Color("TimerContainerBG"))
                .cornerRadius(isLargeTimer ? 15 : 0)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if !skipBorder {
            if #available(iOS 26, *) {
                // Glass defines its own visual boundary; only flash red on completion
                RoundedRectangle(cornerRadius: 15)
                    .stroke(timerState.isCompleted ? Color.red : Color.clear,
                            lineWidth: timerState.isCompleted ? 12 : 0)
                    .animation(.easeInOut(duration: 0.3), value: timerState.isCompleted)
            } else {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(timerState.isCompleted ? Color.red : Color.black,
                            lineWidth: timerState.isCompleted ? 12 : 2)
                    .animation(.easeInOut(duration: 0.3), value: timerState.isCompleted)
            }
        }
    }

    private func calculateAdaptiveHeight() -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let deviceIsPad = UIDevice.current.userInterfaceIdiom == .pad
        if deviceIsPad {
            return min(screenHeight * 0.31, 460)
        }
        switch screenHeight {
        case 0...667:
            return screenHeight * 0.36
        case 668...812:
            return screenHeight * 0.30
        case 813...926:
            return screenHeight * 0.28
        default:
            return screenHeight * 0.26
        }
    }
}

extension View {
    func timerContainerAppearance(timerState: TimerState, onTimerComplete: ((UUID) -> Void)? = nil, skipBorder: Bool = false, isLargeTimer: Bool = false) -> some View {
        modifier(TimerContainerAppearance(timerState: timerState, onTimerComplete: onTimerComplete, skipBorder: skipBorder, isLargeTimer: isLargeTimer))
    }
}

struct PremiumFeatureBadge: ViewModifier {
    @ObservedObject var settings: Settings

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            if !settings.isPremiumUser {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

extension View {
    func premiumFeatureBadge(settings: Settings) -> some View {
        modifier(PremiumFeatureBadge(settings: settings))
    }
}

struct HideScrollIndicators: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollIndicators(.hidden)
        } else {
            content
        }
    }
}
