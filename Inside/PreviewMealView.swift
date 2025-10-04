import SwiftUI

struct PreviewMealView: View {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    var onAnalyze: (UIImage) -> Void
    
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Take A Photo")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryGreen"))
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.gray.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Image Preview
                    if let uiImage = image {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 500, minHeight: 300)
                            .clipped()
                            .cornerRadius(16)
                            .shadow(radius: 5)
                            .padding(.horizontal)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(maxWidth: 500, minHeight: 300)
                            .cornerRadius(16)
                            .padding(.horizontal)
                    }
                    
                    // Retake Button
                    Button(action: { isPresented = false }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Retake Photo")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("PrimaryGreen"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Notes
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("PrimaryGreen"), lineWidth: 1)
                        )
                        .foregroundColor(.primary)
                        .accentColor(Color("PrimaryGreen"))
                        .padding(.horizontal)
                    
                    // Analyze Button
                    Button(action: {
                        if let uiImage = image {
                            onAnalyze(uiImage)
                        }
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Analyze Meal")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("PrimaryGreen"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.bottom, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .keyboardAdaptive()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .interactiveDismissDisabled(true) // prevents iPad sheet from being small
    }
}
