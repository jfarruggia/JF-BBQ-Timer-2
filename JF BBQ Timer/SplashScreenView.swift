import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 1.0 // Start at full size to match launch screen
    @State private var textOpacity = 0.0 // Text starts invisible for smooth transition
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Background gradient with BBQ theme colors - matches LaunchScreen color
                Color(UIColor(red: 0.88235294117647056, green: 0.54509803921568623, blue: 0.50980392156862742, alpha: 1.0))
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // BBQ Timer Logo - positioned to match the launch screen
                    Image("bbq_logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250)
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        )
                    
                    // App name fades in for a smooth effect
                    Text("JF BBQ Timer")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 3)
                        .opacity(textOpacity)
                }
                .offset(y: 25) // Same offset as in LaunchScreen
                .onAppear {
                    // Only animate the text, keep the logo static since it's already visible from LaunchScreen
                    withAnimation(.easeIn(duration: 0.8)) {
                        self.textOpacity = 1.0
                    }
                    
                    // Wait a bit, then transition to the main app
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
} 