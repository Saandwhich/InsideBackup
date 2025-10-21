import SwiftUI
import CoreLocation

struct DescribeMealView: View {
    @Binding var isPresented: Bool
    @State private var mealName: String = ""
    @State private var mealDescription: String = ""
    @State private var isLoading = false
    @State private var hasStabilizedFirstSheet: Bool = false
    @State private var currentLocation: CLLocation? = nil

    private let openAIService = OpenAIService()
    private let profileStore = ProfileStore.shared
    private let locationHelper = InlineLocationManager()

    var onAnalysisComplete: (String, String, ScanEntry?) -> Void

    // Focused fields for keyboard management
    @FocusState private var focusedField: Field?
    enum Field { case name, description }

    // Lightweight location manager for one-shot location capture
    final class InlineLocationManager: NSObject, CLLocationManagerDelegate {
        private let manager = CLLocationManager()
        var onUpdate: ((CLLocation) -> Void)?

        override init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }

        func request() {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.startUpdatingLocation()
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
            case .denied, .restricted:
                // Do nothing; location will remain nil
                break
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let loc = locations.last {
                onUpdate?(loc)
                // Stop to save battery after first fix
                self.manager.stopUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // Ignore errors; location stays nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Text("Describe A Meal")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color("PrimaryGreen"))
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
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

                    Text("Enter the meal name and a short description for analysis.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)

                    // Meal Name
                    TextField("Meal Name", text: $mealName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                        .tint(Color("PrimaryGreen"))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)

                    // Meal Description (optional)
                    ZStack(alignment: .topLeading) {
                        Color(.systemGray6)
                            .cornerRadius(14)

                        if mealDescription.isEmpty {
                            Text("Enter your meal description here (optional)...")
                                .foregroundColor(Color.gray.opacity(0.5))
                                .padding(EdgeInsets(top: 16, leading: 12, bottom: 0, trailing: 0))
                        }

                        TextEditor(text: $mealDescription)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.primary)
                            .tint(Color("PrimaryGreen"))
                            .focused($focusedField, equals: .description)
                            .frame(minHeight: 140)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)

                    // Analyze Button
                    Button(action: analyzeMeal) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                            Text("Analyze")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                                    ? Color.gray.opacity(0.5)
                                    : Color("PrimaryGreen"))
                        .clipShape(Capsule())
                        .padding(.horizontal)
                    }
                    .disabled(mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .padding(.bottom, 20)
                }
                .padding(.bottom, 60)
                .onTapGesture { hideKeyboard() }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(24)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .interactiveDismissDisabled(true)
        .onAppear {
            locationHelper.onUpdate = { loc in
                self.currentLocation = loc
            }
            locationHelper.request()
        }
        .transition(.opacity)
        .zIndex(1)
    }

    private func analyzeMeal() {
        isLoading = true

        let allergens = profileStore.profile?.allergens ?? []
        let diets = profileStore.profile?.diets ?? []
        let dietaryRestrictions = "Allergens: \(allergens.joined(separator: ", ")); Diets: \(diets.joined(separator: ", "))"

        let analysisPrompt = """
        You are an expert nutritionist, diet coach, and medical doctor specializing in personalized dietary guidance. Your top priority is to provide safe, accurate, and clear dietary advice strictly based on the user's specified dietary restrictions: \(dietaryRestrictions)

        Given the meal description provided by the user, analyze the meal strictly based on its traditional, standard recipe and ingredients, without making any assumptions or modifications unless the user explicitly states otherwise.

        Respond only with the following clearly labeled sections:

        Ingredients: (List only the ingredients of the food in its traditional form strictly as they appear in a nutrition label.)

        Safety Score: (Provide a numeric safety score from 1 to 10 indicating how safe this meal is considering ONLY the user's dietary restrictions.)

        Reason: (Briefly explain why the meal received this safety score, ONLY focusing on allergens or dietary conflicts.)

        Suggestions: (Offer practical advice or alternative options to improve the meal’s safety regarding the dietary restrictions ONLY)

        User query: \(mealDescription), \(mealName)
        """

        openAIService.analyzeMealDescription(analysisPrompt, userAllergens: allergens, userDiets: diets) { result in
            DispatchQueue.main.async {
                // stop loader first
                isLoading = false

                switch result {
                case .success(let analysisText):
                    // Try to decode MealVisionJSON (same logic as Upload/Camera flows)
                    if let data = analysisText.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(MealVisionJSON.self, from: data) {

                        let ingredientsCSV = decoded.ingredients ?? ""
                        let ingredients = ingredientsCSV
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }

                        let score = decoded.safetyScore ?? 0
                        let reason = decoded.reason ?? ""
                        let suggestions = decoded.suggestions ?? ""

                        // Save synchronously and capture returned entry.
                        // NOTE: addScan(...) must be updated to return ScanEntry (see instructions).
                        let savedEntry = ScanHistoryManager.shared.addScan(
                            name: mealName.isEmpty ? (decoded.name ?? "Unknown Meal") : mealName,
                            ingredients: ingredients,
                            score: score,
                            reason: reason,
                            suggestions: suggestions,
                            image: nil,
                            date: Date(),
                            location: currentLocation?.coordinate,
                            scanType: .text
                        )

                        // Immediately invoke completion with the saved entry; parent will present ResultView.
                        // If the parent uses item-based sheet, this ensures data is ready on first render.
                        self.onAnalysisComplete(analysisText, savedEntry.name, savedEntry)

                    } else {
                        // If AI didn't return JSON matching MealVisionJSON, still persist a basic entry so ResultView has a persistent source
                        let savedFallback = ScanHistoryManager.shared.addScan(
                            name: mealName.isEmpty ? "Described Meal" : mealName,
                            ingredients: [],
                            score: 0,
                            reason: "",
                            suggestions: "",
                            image: nil,
                            date: Date(),
                            location: currentLocation?.coordinate,
                            scanType: .text
                        )

                        self.onAnalysisComplete(analysisText, savedFallback.name, savedFallback)
                    }

                case .failure(let error):
                    // On failure, create a minimal persisted record so ResultView has something to fetch and display
                    let savedErrorEntry = ScanHistoryManager.shared.addScan(
                        name: mealName.isEmpty ? "Failed Analysis" : mealName,
                        ingredients: [],
                        score: 0,
                        reason: "Analysis failed: \(error.localizedDescription)",
                        suggestions: "",
                        image: nil,
                        date: Date(),
                        location: currentLocation?.coordinate,
                        scanType: .text
                    )

                    self.onAnalysisComplete("Error: \(error.localizedDescription)", savedErrorEntry.name, savedErrorEntry)
                }
            }
        }
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

