import SwiftUI

struct PremiumUpgradeView: View {
    @ObservedObject var settings: Settings
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 20) {
                Text("Upgrade to Premium")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.orange)

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .clipShape(Circle())

                Text("Unlock all premium features")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    premiumFeatureRow("Unlimited timers")
                    premiumFeatureRow("Advanced timer settings")
                    premiumFeatureRow("Custom themes")
                    premiumFeatureRow("Priority support")
                }
                .padding()

                Button(action: {
                    settings.unlockPremiumFeatures()
                    isPresented = false
                }) {
                    Text("Upgrade Now - $4.99")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Button(action: {
                    isPresented = false
                }) {
                    Text("Not Now")
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: 400)
        }
    }

    private func premiumFeatureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}
