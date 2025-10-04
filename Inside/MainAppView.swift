import SwiftUI
import UIKit
import CoreLocation
import MapKit

struct MainAppView: View {
    @State private var selectedTab: Tab = .home
    @StateObject private var profileStore = ProfileStore.shared

    @State private var showAddMealOptions = false
    @State private var showDescribeMeal = false
    @State private var showUploadImage = false
    @State private var showTakePhoto = false
    @State private var showResultView = false
    @State private var showBarcodeScanner = false

    @State private var selectedImage: UIImage? = nil
    @State private var mealNotes: String = ""
    @State private var selectedScan: ScanEntry? = nil

    @StateObject private var locationManager = LocationManager.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                contentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 48) {
                    tabButton(icon: "house", title: "Home", tab: .home)
                    tabButton(icon: "clock.arrow.trianglehead.counterclockwise.rotate.90", title: "History", tab: .history)
                    tabButton(icon: "gearshape", title: "Settings", tab: .settings)
                }
                .padding(.leading, 42)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.white
                        .shadow(color: .black.opacity(0.05), radius: 8, y: -1)
                        .ignoresSafeArea(edges: .bottom)
                )
            }

            // Floating Add Button
            Button {
                showAddMealOptions = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 78, height: 78)
                    .background(Color("PrimaryGreen"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
            .sheet(isPresented: $showAddMealOptions) {
                AddMealOptionsView(
                    onDescribeMealTap: {
                        showAddMealOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showDescribeMeal = true }
                    },
                    onUploadImageTap: {
                        showAddMealOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showUploadImage = true }
                    },
                    onTakePhotoTap: {
                        showAddMealOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showTakePhoto = true }
                    },
                    onScanBarcodeTap: {
                        showAddMealOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showBarcodeScanner = true }
                    }
                )
                .presentationDetents([.fraction(0.58)])
                .presentationDragIndicator(.hidden)
            }

            // MARK: - Describe Meal (Text)
            .sheet(isPresented: $showDescribeMeal) {
                DescribeMealView(isPresented: $showDescribeMeal) { analysis, name in
                    let allergens = profileStore.profile?.allergens ?? []
                    let diets = profileStore.profile?.diets ?? []
                    OpenAIService().analyzeMealDescription(analysis, userAllergens: allergens, userDiets: diets) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let content):
                                presentResult(analysis: content, name: name, image: nil, scanType: .text)
                            case .failure(let error):
                                presentResult(analysis: "Error: \(error.localizedDescription)", name: name, image: nil, scanType: .text)
                            }
                        }
                    }
                    showDescribeMeal = false
                }
            }

            // MARK: - Upload Image
            .sheet(isPresented: $showUploadImage) {
                UploadImageView(isPresented: $showUploadImage, selectedImage: $selectedImage, mealNotes: $mealNotes) { analysisText, name, image in
                    presentResult(analysis: analysisText, name: name, image: image, scanType: .upload)
                    showUploadImage = false
                }
            }

            // MARK: - Take Photo
            .sheet(isPresented: $showTakePhoto) {
                TakePhotoView(isPresented: $showTakePhoto, selectedImage: $selectedImage, mealNotes: $mealNotes) { analysisText, name, image in
                    presentResult(analysis: analysisText, name: name, image: image, scanType: .camera)
                    showTakePhoto = false
                }
            }

            // MARK: - Barcode Scanner
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView { jsonString in
                    guard let data = jsonString.data(using: .utf8),
                          let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        presentResult(analysis: "Error parsing product data.", name: "Unknown Product", image: nil, scanType: .barcode)
                        showBarcodeScanner = false
                        return
                    }

                    let productName = (dict["product_name_en"] as? String) ??
                                      (dict["product_name"] as? String) ??
                                      "Unknown Product"

                    let ingredientsText = (dict["ingredients_text_en"] as? String) ??
                                          (dict["ingredients_text"] as? String) ??
                                          "Ingredients not listed"

                    let allergens = profileStore.profile?.allergens ?? []
                    let diets = profileStore.profile?.diets ?? []

                    OpenAIService().analyzeOFFProduct(productName: productName,
                                                      ingredients: ingredientsText,
                                                      userAllergens: allergens,
                                                      userDiets: diets,
                                                      extraInfo: "") { result in
                        DispatchQueue.main.async {
                            presentResult(analysis: result, name: productName, image: nil, scanType: .barcode)
                            showBarcodeScanner = false
                        }
                    }
                }
            }

            .sheet(isPresented: $showResultView) {
                if let scan = selectedScan {
                    ResultView(
                        scan: scan,
                        isPresented: $showResultView, // ✅ must pass this
                        onClose: { showResultView = false }
                    )
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Present Result
    private func presentResult(analysis: String, name: String, image: UIImage?, scanType: ScanType) {
        let date = Date()
        let location = locationManager.userLocation?.coordinate

        var decodedIngredients: [String] = []
        var decodedScore = 0
        var decodedReason = "N/A"
        var decodedSuggestions = "N/A"

        if let data = analysis.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(MealVisionJSON.self, from: data) {
            decodedIngredients = decoded.ingredients?.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
            decodedScore = decoded.safetyScore ?? 0
            decodedReason = decoded.reason ?? "N/A"
            decodedSuggestions = decoded.suggestions ?? "N/A"
        } else {
            decodedIngredients = analysis.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        // Convert UIImage -> Data
        let imageData = image?.jpegData(compressionQuality: 0.8)

        // Convert CLLocationCoordinate2D -> CodableCoordinate
        let codableLocation = location.map { CodableCoordinate(coordinate: $0) }

        // ✅ Create ScanEntry
        let newScan = ScanEntry(
            id: UUID(),
            name: name,
            ingredients: decodedIngredients,
            score: decodedScore,
            reason: decodedReason,
            suggestions: decodedSuggestions,
            bookmarked: false,
            thumbnailImageData: imageData,
            scannedDate: date,
            scannedLocation: codableLocation,
            scanType: scanType
        )

        // Save to history
        ScanHistoryManager.shared.addScan(
            name: name,
            ingredients: decodedIngredients,
            score: decodedScore,
            reason: decodedReason,
            suggestions: decodedSuggestions,
            image: image,
            date: date,
            location: location,
            scanType: scanType
        )

        // Show in ResultView
        self.selectedScan = newScan
        self.showResultView = true
    }

    @ViewBuilder
    private func contentView() -> some View {
        switch selectedTab {
        case .home: HomeView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }

    @ViewBuilder
    private func tabButton(icon: String, title: String, tab: Tab) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold))
            Text(title).font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(selectedTab == tab ? Color("PrimaryGreen") : .gray)
        .onTapGesture { selectedTab = tab }
    }

    enum Tab { case home, history, settings }
}
