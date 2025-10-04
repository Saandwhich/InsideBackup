import SwiftUI

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AddMealOptionsView: View {
    var onDescribeMealTap: () -> Void
    var onUploadImageTap: () -> Void
    var onTakePhotoTap: () -> Void
    var onScanBarcodeTap: () -> Void   // ✅ New callback for Scan A Barcode

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Spacer().frame(height: 10)

                Text("Add A Meal")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.bottom, 4)

                VStack(spacing: 16) {
                    Button(action: { onTakePhotoTap() }) {
                        mealOption(icon: "camera.fill",
                                   title: "Snap A Photo",
                                   description: "Take a clear photo of your meal from above for the most accurate results.")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { onUploadImageTap() }) {
                        mealOption(icon: "photo",
                                   title: "Upload An Image",
                                   description: "Choose an image of your meal from your photos library.")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { onDescribeMealTap() }) {
                        mealOption(icon: "text.alignleft",
                                   title: "Describe A Meal",
                                   description: "Write a short description of your meal or ingredients for a fast analysis.")
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { onScanBarcodeTap() }) {
                        mealOption(icon: "barcode.viewfinder",
                                   title: "Scan A Barcode",
                                   description: "Scan the barcode on packaged food for instant, detailed analysis.")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 500) // cap width on iPad
                Spacer(minLength: 30)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .interactiveDismissDisabled(true)
    }

    private func mealOption(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color("PrimaryGreen"))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .medium))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
