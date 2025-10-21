import SwiftUI
import PhotosUI

struct UploadImageView: View {
    @Binding var isPresented: Bool
    @Binding var selectedImage: UIImage?
    @Binding var mealNotes: String

    @State private var isLoading = false
    @State private var mealName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @FocusState private var notesFocused: Bool

    private let openAIService = OpenAIService()
    private let profileStore = ProfileStore.shared

    var onAnalysisComplete: (String, String, UIImage?) -> Void

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
                    .keyboardAdaptive()
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
            .onDisappear {
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
            Text("Upload An Image")
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
                        .font(.system(size: 12, weight: .regular))
                }
                .padding(8)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal)
    }

    private var subtitle: some View {
        Text("Choose an image of your meal and optionally add notes for better analysis.")
            .font(.system(size: 14))
            .foregroundColor(.gray)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)
    }

    private var selectImageButton: some View {
        Button(action: { showingPhotoPicker = true }) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18, weight: .medium))
                Text(selectedImage == nil ? "Select Image" : "Change Image")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("PrimaryGreen"))
            .foregroundColor(.white)
            .cornerRadius(14)
            .padding(.horizontal)
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { oldItem, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedImage = uiImage
                }
            }
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
                Image(systemName: "sparkle").font(.system(size: 18))
                Text("Analyze").font(.system(size: 18, weight: .semibold))
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
                isLoading = false
                switch result {
                case .success(let payload):
                    let (name, formattedText) = payload
                    self.mealName = name

                    // Attempt to decode the AI JSON into MealVisionJSON 
                    if let data = formattedText.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(MealVisionJSON.self, from: data) {
                        let ingredientsCSV = decoded.ingredients ?? ""
                        let ingredients = ingredientsCSV
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let score = decoded.safetyScore ?? 0
                        let reason = decoded.reason ?? ""
                        let suggestions = decoded.suggestions ?? ""
                    }

                    // Keep existing callback for compatibility with parent presentation logic
                    self.onAnalysisComplete(formattedText, name, self.selectedImage)
                case .failure(let err):
                    self.errorMessage = friendlyError(err)
                    self.showError = true
                }
            }
        }
    }

    private func friendlyError(_ err: Error) -> String {
        if let openAIError = err as? OpenAIServiceError {
            switch openAIError {
            case .missingAPIKey: return "Missing API key."
            case .invalidURL: return "Could not reach AI service."
            case .noData: return "No data received."
            case .unexpectedResponse: return "Unexpected AI response."
            case .imageConversionFailed: return "Could not read image."
            case .jsonDecodingFailed(let details): return "JSON error: \(details)"
            case .networkError(let message): return "Network error: \(message)"
            }
        } else {
            return err.localizedDescription
        }
    }
}
