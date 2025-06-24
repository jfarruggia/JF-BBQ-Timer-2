//
//  OnboardingView.swift
//  JF BBQ Timer
//
//  Created by James Farruggia on 5/30/25.
//


import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            Text("🍖")
                .font(.system(size: 80))
                .padding(.bottom, 20)

            Text("Welcome to BBQ Timer!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Perfect timing, every barbecue.\nSimple. Reliable. Delicious.")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: {
                hasOnboarded = true
            }) {
                Text("Start Grilling!")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
