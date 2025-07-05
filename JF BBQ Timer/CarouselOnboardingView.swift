//
//  CarouselOnboardingView.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 5/30/25.
//


import SwiftUI
import AVFoundation

// MARK: - App Theme Color
extension Color {
    static let onboardingBackground = Color(UIColor(red: 225/255, green: 139/255, blue: 130/255, alpha: 1.0))
}

// MARK: - Main Onboarding Flow
struct OnboardingFlowView: View {
    @State private var selection = 0
    @State private var showMain = false
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
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
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Color.onboardingBackground.ignoresSafeArea()
                TabView(selection: $selection) {
                    WelcomeOnboardingScreen(skipAction: completeOnboarding)
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
                    PaywallOnboardingScreen(
                        skipAction: completeOnboarding,
                        upgradeAction: completeOnboarding,
                        restoreAction: { /* TODO: Integrate StoreKit/RevenueCat */ }
                    )
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .ignoresSafeArea()
                
                // Skip button (top right)
                if selection < 2 {
                    VStack {
                        HStack {
                            Spacer()
                            Button("Skip Setup") {
                                completeOnboarding()
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 20)
                        .padding(.trailing, 24)
                    }
                }
            }
            .navigationDestination(isPresented: $showMain) {
                MainView()
            }
        }
    }
    
    private func completeOnboarding() {
        hasOnboarded = true
        showMain = true
    }
}

// MARK: - Modular Onboarding Screens
struct WelcomeOnboardingScreen: View {
    let skipAction: () -> Void
    @State private var animateIcon = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("BBQLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
                .scaleEffect(animateIcon ? 1.0 : 0.9)
                .animation(.easeOut(duration: 0.4), value: animateIcon)
                .onAppear {
                    animateIcon = true
                }
            Text("Welcome to GrillTime Pro")
                .font(.largeTitle).bold()
                .foregroundColor(Color("TimerAccent"))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
            Text("GrillTime Pro – Free Features")
                .font(.title2).bold().italic()
                .foregroundColor(Color(red: 0.807, green: 0.216, blue: 0.129)) // #ce3721
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Set up to 3 customizable timers for different foods")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Name your timers for easy tracking")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Adjust flip & cook times to match your grilling style")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Get sound alerts so you never miss a beat")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text("Compact & Large Timer Views—perfect for every grill master, including those with vision needs")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.7), radius: 2, x: 1, y: 1)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.35))
            )

            Text("Start grilling smarter today—upgrade anytime for even more power!")
                .font(.body)
                .foregroundColor(Color("TimerAccent"))
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                )
                .padding(.top, 8)
            // Minimal swipe instruction with icon
            HStack(spacing: 6) {
                Text("Swipe to set up timers")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                Image(systemName: "arrow.right")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

// MARK: - MainView Placeholder
struct MainView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)
            Text("Ready to Grill.")
                .font(.largeTitle).bold()
                .padding(.top, 16)
            Spacer()
        }
        .padding()
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
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                Text("Set Up Your Grill Timers")
                    .font(.largeTitle).bold()
                    .foregroundColor(Color("TimerAccent"))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                Text("Rename your timers and set the presets or just use the defaults")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Timer 1 Container
                VStack(alignment: .leading, spacing: 12) {
                    Label("Timer 1", systemImage: "clock.fill")
                        .font(.headline)
                        .foregroundColor(Color("TimerAccent"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("TimerBackground"))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Timer 1 Name", text: $timer1Name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        HStack {
                            Text("Preset 1:")
                                .foregroundColor(Color("TimerAccent"))
                            Spacer()
                            Button(action: {
                                tempTime = timer1Preset1
                                showingPicker = .timer1Preset1
                            }) {
                                Text(timeString(from: timer1Preset1))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TimerAccent"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                        HStack {
                            Text("Preset 2:")
                                .foregroundColor(Color("TimerAccent"))
                            Spacer()
                            Button(action: {
                                tempTime = timer1Preset2
                                showingPicker = .timer1Preset2
                            }) {
                                Text(timeString(from: timer1Preset2))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TimerAccent"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("TimerBackground"))
                    .cornerRadius(12)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("TimerContainerBG"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                
                // Timer 2 Container
                VStack(alignment: .leading, spacing: 12) {
                    Label("Timer 2", systemImage: "clock.fill")
                        .font(.headline)
                        .foregroundColor(Color("TimerAccent"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("TimerBackground"))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Timer 2 Name", text: $timer2Name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        HStack {
                            Text("Preset 1:")
                                .foregroundColor(Color("TimerAccent"))
                            Spacer()
                            Button(action: {
                                tempTime = timer2Preset1
                                showingPicker = .timer2Preset1
                            }) {
                                Text(timeString(from: timer2Preset1))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TimerAccent"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                        HStack {
                            Text("Preset 2:")
                                .foregroundColor(Color("TimerAccent"))
                            Spacer()
                            Button(action: {
                                tempTime = timer2Preset2
                                showingPicker = .timer2Preset2
                            }) {
                                Text(timeString(from: timer2Preset2))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TimerAccent"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("TimerBackground"))
                    .cornerRadius(12)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("TimerContainerBG"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                
                // Preheat Duration Container
                VStack(alignment: .leading, spacing: 12) {
                    Label("Preheat Duration", systemImage: "flame.fill")
                        .font(.headline)
                        .foregroundColor(Color("TimerAccent"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color("TimerBackground"))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Preheat:")
                            .foregroundColor(Color("TimerAccent"))
                        Spacer()
                        Button(action: {
                            tempTime = preheatDuration
                            showingPicker = .preheat
                        }) {
                            Text(timeString(from: preheatDuration))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("TimerAccent"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color("TimerBackground"))
                    .cornerRadius(12)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("TimerContainerBG"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                Spacer(minLength: 20)
            }
            .padding()
        }
        // Modal for time picker
        .sheet(item: $showingPicker) { pickerType in
            TimePickerModal(
                totalSeconds: $tempTime,
                onDone: {
                    // Save the selected time to the correct property
                    switch pickerType {
                    case .timer1Preset1: timer1Preset1 = tempTime
                    case .timer1Preset2: timer1Preset2 = tempTime
                    case .timer2Preset1: timer2Preset1 = tempTime
                    case .timer2Preset2: timer2Preset2 = tempTime
                    case .preheat: preheatDuration = tempTime
                    }
                    showingPicker = nil
                },
                onCancel: {
                    showingPicker = nil
                }
            )
        }
    }
    // Helper to format seconds as HH:MM:SS
    private func timeString(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
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
            .onChange(of: hours) { updateTotal() }
            .onChange(of: minutes) { updateTotal() }
            .onChange(of: seconds) { updateTotal() }
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

// MARK: - Temporary Paywall Onboarding Screen (placeholder for RevenueCat)
struct PaywallOnboardingScreen: View {
    let skipAction: () -> Void
    let upgradeAction: () -> Void
    let restoreAction: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "flame.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.orange)
            Text("Thank You for Using GrillTime Pro!")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            Text("Premium features will be available soon. Stay tuned for updates!")
                .font(.title3)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Button("Continue") {
                skipAction()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    OnboardingFlowView()
}
