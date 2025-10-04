import SwiftUI

struct SplashScreenView: View {
    var onFinish: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "#287741")
                .ignoresSafeArea()
            
            VStack {
                Image("InsideLogo") // Replace with your asset name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    onFinish() // Call the parent to move to welcome
                }
            }
        }
    }
}

