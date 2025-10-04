import SwiftUI

struct LoadingProfileView: View {
    var onComplete: () -> Void
    @State private var currentMessageIndex = 0
    private let messages = [
        "Analyzing your restrictions...",
        "Scanning for common allergens...",
        "Checking your dietary needs...",
        "Creating your profile..."
    ]
    
    var body: some View {
        ZStack {
            Color("PrimaryGreen").ignoresSafeArea()
            
            VStack(spacing: 32) {
                LoadingIcon()
                
                Text(messages[currentMessageIndex])
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .onAppear {
            cycleMessages()
        }
    }
    
    func cycleMessages() {
        let interval = 1.7
        for i in 1..<messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                withAnimation {
                    currentMessageIndex = i
                }
            }
        }
        // Call onComplete after final message
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(messages.count) * interval + 0.5) {
            withAnimation {
                onComplete()
            }
        }
    }
}
