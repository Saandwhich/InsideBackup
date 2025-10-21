import SwiftUI

struct ProfileCreatedView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color("PrimaryGreen"))

            Text("You're all set!")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.64)
                .foregroundColor(Color("PrimaryGreen"))

            Text("Your profile has been created.\nYou can update your preferences anytime.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                onContinue()
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryGreen"))
                    .cornerRadius(28)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: UUID())
    }
}
