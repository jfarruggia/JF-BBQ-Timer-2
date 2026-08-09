import SwiftUI
import UIKit

// MARK: - Haptics

/// Shared, *prepared* tap haptic for buttons. Creating a `UIImpactFeedbackGenerator`
/// inline and firing it without `prepare()` (as the old button style did) makes iOS
/// silently drop the buzz when the Taptic Engine is idle — which is why button taps
/// often felt dead. Keeping one generator alive and re-priming it after each use makes
/// the feedback reliable. `isEnabled` mirrors the in-app "Haptic Feedback" setting so
/// the toggle actually governs button feedback too.
enum Haptics {
    static var isEnabled = true
    private static let light = UIImpactFeedbackGenerator(style: .light)

    /// Warm the Taptic Engine so the next tap fires instantly (call on appear / before a press).
    static func prepare() {
        guard isEnabled else { return }
        light.prepare()
    }

    /// Fire a light tap (when enabled) and immediately re-prime for the next one.
    static func tap() {
        guard isEnabled else { return }
        light.impactOccurred()
        light.prepare()
    }

    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    /// Double heavy "ignite" pulse for the Preheat button. Must use this
    /// long-lived generator: a generator created locally in a button action
    /// can be deallocated before the Taptic Engine plays, silently dropping
    /// the haptic.
    static func ignite() {
        guard isEnabled else { return }
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            heavy.impactOccurred(intensity: 1.0)
            heavy.prepare()
        }
    }
}

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
    static let grillCardBodyTop = Color(red: 0.50, green: 0.24, blue: 0.14).opacity(0.34)
    static let grillCardBodyBottom = Color(red: 0.10, green: 0.04, blue: 0.02).opacity(0.46)
}

// MARK: - Shared immersive glass theme
//
// The main screen established an "ember-glow charcoal background + frosted glass
// panes" look. These helpers package that language so the rest of the app
// (Settings, paywall, custom sounds, alerts) can reuse it verbatim instead of
// re-rolling effects. `EmberBackground` is the charcoal+coals bed; `grillGlassPane`
// is the card/header/preheat pane treatment (clear glass + body gradient + beveled
// rim + deep shadow), gated behind iOS 26 with a sensible pre-26 fallback.

/// Deep-charcoal background seeded with many small radial "coals" — the same bed
/// the main timer screen uses, so every full-screen surface reads as the same room.
struct EmberBackground: View {
    /// (x, y) are unit positions; r is a fraction of width for the glow radius.
    private var emberSpots: [(x: CGFloat, y: CGFloat, r: CGFloat, color: Color, opacity: Double)] {
        let orange = Color(red: 0.96, green: 0.46, blue: 0.10)
        let redOrange = Color(red: 0.86, green: 0.26, blue: 0.06)
        let red = Color(red: 0.74, green: 0.14, blue: 0.05)
        let amber = Color(red: 1.00, green: 0.56, blue: 0.14)
        return [
            (0.16, 0.07, 0.20, orange,    0.55),
            (0.44, 0.04, 0.15, amber,     0.42),
            (0.82, 0.10, 0.22, redOrange, 0.52),
            (0.94, 0.33, 0.17, red,       0.44),
            (0.62, 0.28, 0.15, orange,    0.36),
            (0.08, 0.40, 0.20, redOrange, 0.44),
            (0.34, 0.58, 0.22, orange,    0.46),
            (0.79, 0.64, 0.18, red,       0.42),
            (0.52, 0.88, 0.24, orange,    0.48),
            (0.07, 0.80, 0.16, amber,     0.40),
            (0.91, 0.86, 0.18, redOrange, 0.44)
        ]
    }

    var body: some View {
        if #available(iOS 26, *) {
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
        } else {
            Color("PrimaryBackground").ignoresSafeArea()
        }
    }
}

/// Frosted "grill glass" pane — the unified card/header/preheat treatment:
/// `.clear` glass tinted warm, a top→bottom body gradient, a beveled rim
/// (white top / black bottom), and a deep drop shadow. Use on grouped content
/// blocks (section cards, banners, buttons) so they match the timer cards.
struct GrillGlassPane: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            content
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
        } else {
            content
                .background(Color("TimerContainerBG"), in: shape)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
}

extension View {
    /// Apply the shared frosted "grill glass" pane treatment (see `GrillGlassPane`).
    func grillGlassPane(cornerRadius: CGFloat = 20) -> some View {
        modifier(GrillGlassPane(cornerRadius: cornerRadius))
    }
}

/// Turns a stock grouped `List` into the immersive ember+frosted-glass look on
/// iOS 26: hides the system list background, drops the `EmberBackground` behind it,
/// frosts every section row, and forces a dark scheme so system text/controls read
/// as light. Pre-26 falls through to the stock system list unchanged.
struct ImmersiveGlassList: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .scrollContentBackground(.hidden)
                .background(EmberBackground())
                .listRowBackground(GrillGlassSectionFill())
                .preferredColorScheme(.dark)
        } else {
            content
        }
    }
}

extension View {
    /// Apply the immersive ember + frosted-glass list treatment (see `ImmersiveGlassList`).
    func immersiveGlassList() -> some View {
        modifier(ImmersiveGlassList())
    }
}

/// Drops the `EmberBackground` behind a non-list screen (custom `VStack`/`ScrollView`
/// layouts: pickers, paywall, sounds, alerts) and forces a dark scheme so text reads
/// as light. Pre-26 leaves the view unchanged. Pair with `grillGlassPane` on the
/// content blocks. For `List`/`Form` screens use `immersiveGlassList` instead.
struct ImmersiveGlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(EmberBackground())
                .preferredColorScheme(.dark)
        } else {
            content
        }
    }
}

extension View {
    /// Apply the immersive ember background + dark scheme (see `ImmersiveGlassBackground`).
    func immersiveGlassBackground() -> some View {
        modifier(ImmersiveGlassBackground())
    }
}

/// Frosted fill for `List` section rows in immersive screens. Pairs with
/// `ImmersiveGlassList`. A *flat* warm tint over thin material (not a vertical
/// gradient) so stacked rows don't band.
struct GrillGlassSectionFill: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color(red: 0.40, green: 0.10, blue: 0.05).opacity(0.22))
    }
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
                    Haptics.tap()
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
            // Instant visual press feedback so taps feel responsive even before the
            // action runs (the old style gave no visual cue at all).
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.tap() }
            }
            .onAppear { Haptics.prepare() }
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
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.tap() }
            }
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
            // repeatCount(20, …) == 10 s of pulsing, matching the 10 s window
            // ContentView keeps `isPreheatComplete` true. Deliberately NOT
            // repeatForever: on iOS 26 the flip-off transition failed to cancel
            // the repeating animation, leaving the button scale-pulsing forever
            // with an invisible (clear) border — verified via frame capture on
            // the 26.5 simulator. A finite repeat self-terminates even if the
            // flip-off transition is dropped again.
            .animation(isPreheatComplete ?
                       .easeInOut(duration: 0.5).repeatCount(20, autoreverses: true) :
                       .easeInOut(duration: 0.2),
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
                                colors: [Color.white.opacity(0.6), Color.clear, Color.black.opacity(0.30)],
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
                                colors: [Color.white.opacity(0.6), Color.clear, Color.black.opacity(0.30)],
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
