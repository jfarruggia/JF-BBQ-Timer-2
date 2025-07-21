import SwiftUI
import RevenueCat

struct CustomPaywallView: View {
    let dismissAction: () -> Void
    @State private var isPurchasing = false
    @State private var package: Package?
    @State private var priceText = "..."  // Loading placeholder
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var settings: Settings
    
    var body: some View {
        VStack(spacing: 16) {  // Reduced spacing
            // Header with Skip button
            HStack {
                Spacer()
                Button("Skip for now") {
                    dismissAction()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.trailing, 16)
            }
            
            // App Icon
            Image("BBQLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)  // Smaller icon
                .cornerRadius(24)
            
            // Title
            Text("Unlock Grill Time Pro")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Subtitle
            Text("Upgrade and get all the\nfeatures serious grillers want:")
                .font(.title3)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 49/255, green: 45/255, blue: 45/255).opacity(0.75))
                )
                .padding(.horizontal, 24)
            
            // Features list
            VStack(alignment: .leading, spacing: 8) {  // Tighter spacing
                FeatureRow(text: "Track up to 24 foods at once with additional timers")
                FeatureRow(text: "Choose from premium alert sounds or upload your own custom sound")
                FeatureRow(text: "Voice announcements—hear alerts in your AirPods or speakers")
                FeatureRow(text: "(Coming Soon!) Apple Watch app, Bluetooth probe integration, cloud sync, and more")
                FeatureRow(text: "One-time purchase. Lifetime access.")
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Purchase button
            Button {
                purchasePremium()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("LIFETIME")
                    Text(priceText)  // Dynamic price
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .disabled(isPurchasing)
            
            // Purchase Now button
            Button {
                purchasePremium()
            } label: {
                Text("Purchase Now")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            .disabled(isPurchasing)
            
            // Restore button
            Button("Restore Purchases") {
                restorePurchases()
            }
            .font(.footnote)
            .foregroundColor(.blue)
            .padding(.bottom)
        }
        .padding(.vertical, 16)
        .background(Color(red: 225/255, green: 139/255, blue: 130/255))
        .onAppear {
            fetchPrice()  // Load price when view appears
        }
    }
    
    private func fetchPrice() {
        print("🏷 Fetching price...")
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("🚫 Error fetching offerings: \(error)")
                return
            }
            
            print("📦 Available offerings: \(offerings?.all.keys.joined(separator: ", ") ?? "none")")
            
            // Try the 'lifetime_unlock' offering first
            if let offering = offerings?.offering(identifier: "lifetime_unlock") {
                print("✅ Found 'lifetime_unlock' offering")
                if let package = offering.availablePackages.first {
                    print("💰 Found package with price: \(package.localizedPriceString)")
                    DispatchQueue.main.async {
                        self.package = package
                        self.priceText = package.localizedPriceString
                    }
                } else {
                    print("❌ No packages in 'lifetime_unlock' offering")
                }
            }
            // Fallback to current offering
            else if let package = offerings?.current?.lifetime {
                print("💰 Found package in current offering: \(package.localizedPriceString)")
                DispatchQueue.main.async {
                    self.package = package
                    self.priceText = package.localizedPriceString
                }
            } else {
                print("❌ No lifetime package found in any offering")
                // For debugging, list all available packages
                if let current = offerings?.current {
                    print("📝 Available packages in current offering:")
                    current.availablePackages.forEach { package in
                        print(" - \(package.identifier): \(package.localizedPriceString)")
                    }
                }
            }
        }
    }
    
    private func purchasePremium() {
        guard let package = package else { return }
        isPurchasing = true
        
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            isPurchasing = false
            
            if let error = error {
                print("❌ Purchase error: \(error)")
                return
            }
            
            if userCancelled {
                print("👋 User cancelled purchase")
                return
            }
            
            let isActive = customerInfo?.entitlements["premium_access"]?.isActive == true
            print("🔐 Premium active: \(isActive)")
            
            if isActive {
                print("✅ Purchase successful!")
                settings.updatePremiumStatus()
                DispatchQueue.main.async {
                    dismissAction()
                }
            } else {
                print("⚠️ Purchase completed but premium not active")
            }
        }
    }
    
    private func restorePurchases() {
        isPurchasing = true
        print("🔄 Starting restore process...")
        
        Purchases.shared.restorePurchases { customerInfo, error in
            if let error = error {
                print("❌ Restore error: \(error)")
                DispatchQueue.main.async {
                    isPurchasing = false
                }
                return
            }
            
            print("✅ Restore completed")
            print("📱 Customer info: \(String(describing: customerInfo))")
            print("🔑 Entitlements: \(String(describing: customerInfo?.entitlements))")
            
            let isActive = customerInfo?.entitlements["premium_access"]?.isActive == true
            print("🔐 Premium active: \(isActive)")
            
            DispatchQueue.main.async {
                isPurchasing = false
                if isActive {
                    print("👋 Dismissing paywall after successful restore")
                    settings.updatePremiumStatus()
                    dismissAction()
                } else {
                    print("⚠️ No active premium entitlement found during restore")
                }
            }
        }
    }
}

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .foregroundColor(.blue)
            Text(text)
                .font(.callout.bold())  // Slightly smaller font
                .foregroundColor(.black)
        }
    }
}

#Preview {
    CustomPaywallView(dismissAction: {}, settings: Settings())
} 