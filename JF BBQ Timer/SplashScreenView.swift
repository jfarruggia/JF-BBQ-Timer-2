import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Background gradient with new colors #a4816b → #3d3936
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#a4816b"),
                        Color(hex: "#3d3936")
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    // New BBQ Timer Logo
                    Image("BBQLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("JF BBQ Timer")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    // Simple fade-in animation
                    withAnimation(.easeOut(duration: 1.0)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                    
                    // Wait and then transition to the main app
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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