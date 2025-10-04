import SwiftUI

struct TakePhotoView: View {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    @Binding var mealNotes: String

    @State private var isLoading = false
    @State private var mealName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingCamera = false
    @FocusState private var notesFocused: Bool

    private let openAIService = OpenAIService()
    private let profileStore = ProfileStore.shared

    var onAnalysisComplete: (String, String, UIImage?) -> Void

    // Temp variable to reset image if user exits
    @State private var tempImage: UIImage?

    var body: some View {
        NavigationView {
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            subtitle
                            Group {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(4/3, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .padding(.horizontal)
                                } else {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .aspectRatio(4/3, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(Text("No image selected").foregroundColor(.gray))
                                        .padding(.horizontal)
                                }
                            }
                            
                            selectImageButton
                            notesField
                                .id("notesField")
                                .focused($notesFocused)
                            
                            analyzeButton
                        }
                        .padding(.bottom, 20)
                    }
                    .keyboardAdaptive() // <-- Added here
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onTapGesture { hideKeyboard() }

                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .alert("We hit a snag", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .fullScreenCover(isPresented: $showingCamera, onDismiss: handleCameraDismiss) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ImagePicker(
                        sourceType: .camera,
                        selectedImage: $selectedImage
                    )
                    .ignoresSafeArea()
                }
            }
            .onDisappear {
                // Reset image if user exits without analyzing
                if selectedImage != tempImage {
                    selectedImage = nil
                }
            }
        }
        .onAppear { tempImage = selectedImage }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Take a Picture")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(Color("PrimaryGreen"))
            Spacer()
            Button { isPresented = false } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .font(.system(size: 12))
                }
                .padding(8)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }

    private var subtitle: some View {
        Text("Take a photo of your meal and optionally add notes for better analysis.")
            .font(.system(size: 14))
            .foregroundColor(.gray)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)
    }

    private var selectImageButton: some View {
        Button(action: { showingCamera = true }) {
            HStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .medium))
                Text(selectedImage == nil ? "Take Photo" : "Retake Photo")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("PrimaryGreen"))
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }

    private var notesField: some View {
        TextField("Add extra notes (e.g. gluten-free pasta)", text: $mealNotes)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .tint(Color("PrimaryGreen"))
            .foregroundColor(.primary)
            .padding(.horizontal)
    }

    private var analyzeButton: some View {
        Button(action: analyzeImage) {
            HStack {
                Image(systemName: "sparkle")
                Text("Analyze").fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color("PrimaryGreen"))
            .clipShape(Capsule())
            .padding(.horizontal)
        }
        .disabled(selectedImage == nil || isLoading)
        .opacity(selectedImage == nil || isLoading ? 0.5 : 1)
        .padding(.bottom)
    }

    // MARK: - Actions

    private func handleCameraDismiss() {
        // No action needed; tempImage ensures we know if the user exits
    }

    private func analyzeImage() {
        guard let image = selectedImage else { return }
        isLoading = true

        let userAllergens = profileStore.profile?.allergens ?? []
        let userDiets = profileStore.profile?.diets ?? []

        openAIService.analyzeMealImage(
            image,
            notes: mealNotes,
            userAllergens: userAllergens,
            userDiets: userDiets
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let payload):
                    let (name, formattedText) = payload
                    self.mealName = name
                    self.onAnalysisComplete(formattedText, name, self.selectedImage)
                case .failure(let err):
                    let friendly: String
                    if let openAIError = err as? OpenAIServiceError {
                        switch openAIError {
                        case .missingAPIKey: friendly = "Missing API key."
                        case .invalidURL: friendly = "Could not reach AI service."
                        case .noData: friendly = "No data received."
                        case .unexpectedResponse: friendly = "Unexpected AI response."
                        case .imageConversionFailed: friendly = "Could not read image."
                        case .jsonDecodingFailed(let details): friendly = "JSON error: \(details)"
                        case .networkError(let message): friendly = "Network error: \(message)"
                        }
                    } else { friendly = err.localizedDescription }
                    self.errorMessage = friendly
                    self.showError = true
                }
            }
        }
    }
}
