//
//  CarouselOnboardingView.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 5/30/25.
//


import SwiftUI
import AVFoundation
import RevenueCat
import RevenueCatUI

// MARK: - App Theme Color
extension Color {
    static let onboardingBackground = Color(UIColor(red: 225/255, green: 139/255, blue: 130/255, alpha: 1.0))
}

// MARK: - Main Onboarding Flow
struct OnboardingFlowView: View {
    /// When set (e.g. replaying the tour from Settings), completing the flow calls
    /// this to dismiss instead of flipping `hasOnboarded`. Nil = first-run behavior.
    var onFinish: (() -> Void)? = nil

    @State private var selection = 0
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @StateObject private var settings = Settings()
    // Timer 1
    @AppStorage("timer1Name") private var timer1Name: String = "Timer 1"
    @AppStorage("timer1Preset1") private var timer1Preset1: Int = 300  // 5 minutes
    @AppStorage("timer1Preset2") private var timer1Preset2: Int = 60   // 1 minute
    // Timer 2
    @AppStorage("timer2Name") private var timer2Name: String = "Timer 2"
    @AppStorage("timer2Preset1") private var timer2Preset1: Int = 300  // 5 minutes
    @AppStorage("timer2Preset2") private var timer2Preset2: Int = 60   // 1 minute
    // Preheat
    @AppStorage("preheatDuration") private var preheatDuration: Int = 600
    
    var body: some View {
        // No NavigationStack needed: completing onboarding flips `hasOnboarded`,
        // which swaps the app's root to ContentView (see JF_BBQ_TimerApp).
        ZStack(alignment: .topTrailing) {
            // Background: shared ember bed on iOS 26 (added by immersiveGlassBackground
            // below); original salmon backdrop pre-26.
            if #unavailable(iOS 26) {
                Color.onboardingBackground.ignoresSafeArea()
            }

            TabView(selection: $selection) {
                WelcomeOnboardingScreen()
                    .tag(0)
                CombinedTimerPreheatSetupScreen(
                    timer1Name: $timer1Name,
                    timer1Preset1: $timer1Preset1,
                    timer1Preset2: $timer1Preset2,
                    timer2Name: $timer2Name,
                    timer2Preset1: $timer2Preset1,
                    timer2Preset2: $timer2Preset2,
                    preheatDuration: $preheatDuration
                )
                    .tag(1)
                // Third onboarding page: Custom Paywall (already themed)
                CustomPaywallView(dismissAction: completeOnboarding, settings: settings)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .ignoresSafeArea()
            // Ensure defaults are visible the first time this screen appears, even if
            // prior runs left zero or empty values in UserDefaults.
            .onAppear { ensureOnboardingDefaults() }

            // Skip button (top right) — hidden on the paywall page
            if selection < 2 {
                Button("Skip") { completeOnboarding() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .padding(.top, 8)
                    .padding(.trailing, 16)
            }
        }
        .immersiveGlassBackground()
    }

    private func completeOnboarding() {
        if let onFinish {
            onFinish() // review mode: just dismiss
        } else {
            hasOnboarded = true
        }
    }

    // Initialize defaults if missing or zero so page 2 shows expected values
    private func ensureOnboardingDefaults() {
        if timer1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { timer1Name = "Timer 1" }
        if timer2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { timer2Name = "Timer 2" }
        if UserDefaults.standard.object(forKey: "timer1Preset1") == nil || timer1Preset1 == 0 { timer1Preset1 = 300 }
        if UserDefaults.standard.object(forKey: "timer1Preset2") == nil || timer1Preset2 == 0 { timer1Preset2 = 60 }
        if UserDefaults.standard.object(forKey: "timer2Preset1") == nil || timer2Preset1 == 0 { timer2Preset1 = 300 }
        if UserDefaults.standard.object(forKey: "timer2Preset2") == nil || timer2Preset2 == 0 { timer2Preset2 = 60 }
        if UserDefaults.standard.object(forKey: "preheatDuration") == nil || preheatDuration == 0 { preheatDuration = 600 }
    }
}

// MARK: - Modular Onboarding Screens
struct WelcomeOnboardingScreen: View {
    @State private var animateIcon = false

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }
    private let features: [Feature] = [
        .init(icon: "timer", text: "Time several foods at once, each on its own timer"),
        .init(icon: "hand.tap.fill", text: "Flip and extend cook times with a single tap"),
        .init(icon: "bell.badge.fill", text: "Loud alerts so you never miss a flip")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 28)

                Image("BBQLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .scaleEffect(animateIcon ? 1.0 : 0.9)
                    .animation(.easeOut(duration: 0.4), value: animateIcon)
                    .onAppear { animateIcon = true }

                VStack(spacing: 6) {
                    Text("Welcome to GrillTime Pro")
                        .font(.system(.title, design: .rounded)).bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text("Perfect timing, every cook.")
                        .font(.headline)
                        .foregroundColor(Color("TimerAccent"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(features) { feature in
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: feature.icon)
                                .font(.title3)
                                .foregroundColor(Color("TimerAccent"))
                                .frame(width: 28)
                            Text(feature.text)
                                .font(.callout)
                                .foregroundColor(.white)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .grillGlassPane(cornerRadius: 20)
                .padding(.horizontal, 20)

                HStack(spacing: 6) {
                    Text("Swipe to set up your timers")
                    Image(systemName: "arrow.right")
                }
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))

                Spacer(minLength: 28)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Combined Timer & Preheat Setup Screen
/// This replaces the individual Timer 1, Timer 2, and Preheat screens in onboarding.
struct CombinedTimerPreheatSetupScreen: View {
    @Binding var timer1Name: String
    @Binding var timer1Preset1: Int
    @Binding var timer1Preset2: Int
    @Binding var timer2Name: String
    @Binding var timer2Preset1: Int
    @Binding var timer2Preset2: Int
    @Binding var preheatDuration: Int
    
    // State for showing modals and tracking which value is being edited
    @State private var showingPicker: PickerType? = nil
    @State private var tempTime: Int = 0
    // Detailed timer customization is collapsed by default — defaults are pre-filled,
    // so users can dive straight in and tweak later (here or in Settings).
    @State private var showCustomize = false

    // Enum to identify which value is being edited
    enum PickerType: Identifiable {
        case timer1Preset1, timer1Preset2, timer2Preset1, timer2Preset2, preheat
        var id: Int {
            switch self {
            case .timer1Preset1: return 1
            case .timer1Preset2: return 2
            case .timer2Preset1: return 3
            case .timer2Preset2: return 4
            case .preheat: return 5
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 44) // clear the Skip button up top

                VStack(spacing: 8) {
                    Text("You're ready to grill")
                        .font(.system(.title, design: .rounded)).bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text("Two timers are set with sensible defaults. Start now, or fine-tune them — you can change everything later in Settings.")
                        .font(.subheadline)
                        .foregroundColor(.primary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                summaryCard
                    .padding(.horizontal, 20)

                Button {
                    withAnimation(.easeInOut) { showCustomize.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCustomize ? "chevron.up" : "slider.horizontal.3")
                        Text(showCustomize ? "Hide customization" : "Customize timers")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color("TimerAccent"))
                }

                if showCustomize {
                    timerEditorCard(title: "Timer 1", name: $timer1Name,
                                    flip: timer1Preset1, extend: timer1Preset2,
                                    flipPicker: .timer1Preset1, extendPicker: .timer1Preset2)
                        .padding(.horizontal, 20)
                    timerEditorCard(title: "Timer 2", name: $timer2Name,
                                    flip: timer2Preset1, extend: timer2Preset2,
                                    flipPicker: .timer2Preset1, extendPicker: .timer2Preset2)
                        .padding(.horizontal, 20)
                    preheatEditorCard
                        .padding(.horizontal, 20)
                }

                HStack(spacing: 6) {
                    Text("Swipe to continue")
                    Image(systemName: "arrow.right")
                }
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.7))
                .padding(.top, 4)

                Spacer(minLength: 28)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            // Guarantee visible defaults when values are zero/empty
            if timer1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { timer1Name = "Timer 1" }
            if timer2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { timer2Name = "Timer 2" }
            if timer1Preset1 <= 0 { timer1Preset1 = 300 }
            if timer1Preset2 <= 0 { timer1Preset2 = 60 }
            if timer2Preset1 <= 0 { timer2Preset1 = 300 }
            if timer2Preset2 <= 0 { timer2Preset2 = 60 }
            if preheatDuration <= 0 { preheatDuration = 600 }
        }
        // Modal for time picker
        .sheet(item: $showingPicker) { pickerType in
            TimePickerModal(
                totalSeconds: $tempTime,
                onDone: {
                    switch pickerType {
                    case .timer1Preset1: timer1Preset1 = tempTime
                    case .timer1Preset2: timer1Preset2 = tempTime
                    case .timer2Preset1: timer2Preset1 = tempTime
                    case .timer2Preset2: timer2Preset2 = tempTime
                    case .preheat: preheatDuration = tempTime
                    }
                    showingPicker = nil
                },
                onCancel: { showingPicker = nil }
            )
        }
    }

    // MARK: - Summary + editor helpers

    private var summaryCard: some View {
        VStack(spacing: 14) {
            summaryRow(name: timer1Name, flip: timer1Preset1, extend: timer1Preset2)
            Divider().overlay(Color.white.opacity(0.15))
            summaryRow(name: timer2Name, flip: timer2Preset1, extend: timer2Preset2)
            Divider().overlay(Color.white.opacity(0.15))
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .foregroundColor(Color("TimerAccent"))
                    .frame(width: 22)
                Text("Preheat")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(timeString(from: preheatDuration))
                    .font(.subheadline).monospacedDigit()
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .grillGlassPane(cornerRadius: 20)
    }

    private func summaryRow(name: String, flip: Int, extend: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .foregroundColor(Color("TimerAccent"))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Timer" : name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Flip \(timeString(from: flip))  ·  Extend +\(timeString(from: extend))")
                    .font(.caption).monospacedDigit()
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func timerEditorCard(title: String, name: Binding<String>,
                                 flip: Int, extend: Int,
                                 flipPicker: PickerType, extendPicker: PickerType) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(Color("TimerAccent"))
            TextField("\(title) name", text: name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            editRow(label: "Flip time", seconds: flip, picker: flipPicker)
            editRow(label: "Extend by", seconds: extend, picker: extendPicker)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .grillGlassPane(cornerRadius: 16)
    }

    private var preheatEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Preheat", systemImage: "flame.fill")
                .font(.headline)
                .foregroundColor(Color("TimerAccent"))
            editRow(label: "Preheat time", seconds: preheatDuration, picker: .preheat)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .grillGlassPane(cornerRadius: 16)
    }

    private func editRow(label: String, seconds: Int, picker: PickerType) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white)
            Spacer()
            Button {
                tempTime = seconds
                showingPicker = picker
            } label: {
                Text(timeString(from: seconds))
                    .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                    .foregroundColor(Color("TimerAccent"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
        }
    }

    // Compact time: M:SS, or H:MM:SS for long durations.
    private func timeString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - TimePickerModal
/// A modal with three wheels for hours, minutes, and seconds. Max: 23:59:59
struct TimePickerModal: View {
    @Binding var totalSeconds: Int
    var onDone: () -> Void
    var onCancel: () -> Void
    // Internal state for wheels
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    // Max values
    let maxHours = 23
    let maxMinutes = 59
    let maxSeconds = 59
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)
                HStack(spacing: 0) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0...maxHours, id: \ .self) { Text("\($0) h") }
                    }
                    .frame(width: 90)
                    .clipped()
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...maxMinutes, id: \ .self) { Text("\($0) m") }
                    }
                    .frame(width: 90)
                    .clipped()
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0...maxSeconds, id: \ .self) { Text("\($0) s") }
                    }
                    .frame(width: 90)
                    .clipped()
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                Spacer(minLength: 20)
            }
            .onAppear {
                // Initialize wheels from totalSeconds
                hours = totalSeconds / 3600
                minutes = (totalSeconds % 3600) / 60
                seconds = totalSeconds % 60
            }
            .onChange(of: hours) { _ in updateTotal() }
            .onChange(of: minutes) { _ in updateTotal() }
            .onChange(of: seconds) { _ in updateTotal() }
            .navigationBarTitle("Set Time", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Done", action: onDone)
            )
        }
    }
    private func updateTotal() {
        // Clamp to max
        let h = min(max(hours, 0), maxHours)
        let m = min(max(minutes, 0), maxMinutes)
        let s = min(max(seconds, 0), maxSeconds)
        totalSeconds = h * 3600 + m * 60 + s
    }
}

// MARK: - Preview
#Preview {
    OnboardingFlowView()
}
