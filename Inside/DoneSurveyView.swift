import SwiftUI

struct DoneSurveyView: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(Color("PrimaryGreen"))

            Text("Survey Complete")
                .font(.title)
                .fontWeight(.bold)

            Text("Thanks for sharing. We're setting up your personalized experience.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)

            Spacer()

            HStack(spacing: 16) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(Color("PrimaryGreen"))
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(height: 52)
                        .frame(maxWidth: .infinity)
                        .background(Color("PrimaryGreen"))
                        .cornerRadius(32)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
