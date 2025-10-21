import SwiftUI

struct AgreementsView: View {
    @Binding var agreedPrivacy: Bool
    @Binding var agreedTerms: Bool
    let onOpenPrivacy: () -> Void
    let onOpenTerms: () -> Void

    var canContinue: Bool { agreedPrivacy && agreedTerms }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Checkboxes
            AgreementRow(title: "I agree to the Privacy Policy", isOn: $agreedPrivacy)
            AgreementRow(title: "I agree to the Terms of Use", isOn: $agreedTerms)

            // Links
            HStack(spacing: 12) {
                Button(action: onOpenPrivacy) {
                    Text("Open Privacy Policy")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                }
                Button(action: onOpenTerms) {
                    Text("Open Terms of Use")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct AgreementRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(isOn ? Color("PrimaryGreen") : .gray)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}
