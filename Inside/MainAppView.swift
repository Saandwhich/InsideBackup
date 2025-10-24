import SwiftUI
import UIKit
import CoreLocation
import MapKit
import AVFoundation

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

    @ObservedObject private var historyManager = ScanHistoryManager.shared
    @State private var showFirstScanBanner: Bool = false
    @State private var tabBarHeight: CGFloat = 0
    @State private var addButtonSize: CGSize = .zero

    // Camera permission alert
    @State private var showCameraSettingsAlert = false

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
                    GeometryReader { proxy in
                        Color.white
                            .onAppear { tabBarHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, newValue in tabBarHeight = newValue }
                            .overlay(
                                Color.white
                                    .shadow(color: .black.opacity(0.05), radius: 8, y: -1)
                            )
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }

            // Floating Add Button
            Button {
                showAddMealOptions = true
            } label: {
                ZStack {
                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 78, height: 78)
                        .background(Color("PrimaryGreen"))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 4)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear { addButtonSize = proxy.size }
                    }
                )
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
                        // Check camera permission first
                        CameraPermissionManager.checkAndRequestCamera { authorized in
                            DispatchQueue.main.async {
                                if authorized {
                                    showAddMealOptions = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showTakePhoto = true }
                                } else {
                                    // Show settings alert only if denied/restricted
                                    showCameraSettingsAlert = (AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted)
                                }
                            }
                        }
                    },
                    onScanBarcodeTap: {
                        // Check camera permission first
                        CameraPermissionManager.checkAndRequestCamera { authorized in
                            DispatchQueue.main.async {
                                if authorized {
                                    showAddMealOptions = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showBarcodeScanner = true }
                                } else {
                                    showCameraSettingsAlert = (AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted)
                                }
                            }
                        }
                    }
                )
                .presentationDetents([.fraction(0.58)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.white)
            }

            // MARK: - Describe Meal (Text)
            .sheet(isPresented: $showDescribeMeal) {
                DescribeMealView(isPresented: $showDescribeMeal) { analysis, name, savedEntry in
                    if let entry = savedEntry {
                        self.selectedScan = entry
                    } else {
                        presentResult(analysis: analysis, name: name, image: nil, scanType: .text)
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

            .sheet(item: $selectedScan) { s in
                ResultView(
                    scan: s,
                    isPresented: Binding(
                        get: { selectedScan != nil },
                        set: { if !$0 { selectedScan = nil } }
                    ),
                    onClose: { selectedScan = nil }
                )
                .id(s.id)
            }
            
            // Global First Scan Banner
            if showFirstScanBanner {
                GeometryReader { proxy in
                    let safeBottom = proxy.safeAreaInsets.bottom
                    let addButtonClearance = max(addButtonSize.height, 78)
                    ZStack {
                        Button(action: {
                            withAnimation { showAddMealOptions = true }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .foregroundColor(.black)
                                    .imageScale(.large)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scan your first meal")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Text("Tap the green + button to get started")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer(minLength: 8)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        HStack {
                            Spacer()
                            Button(action: { withAnimation { showFirstScanBanner = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .imageScale(.large)
                            }
                            .accessibilityLabel("Dismiss banner")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
                    )
                    .frame(maxWidth: min(proxy.size.width - (24 + addButtonClearance + 16), 600))
                    .padding(.horizontal)
                    .padding(.bottom, max(2, 2 + safeBottom) + tabBarHeight - 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            locationManager.requestLocationPermission()
        }
        .onAppear {
            showFirstScanBanner = historyManager.scans.isEmpty
        }
        .onChange(of: historyManager.scans.count) { _, newCount in
            withAnimation { showFirstScanBanner = (newCount == 0) }
        }
        .alert("Camera access is required", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to use this feature.")
        }
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

        let imageData = image?.jpegData(compressionQuality: 0.8)
        let codableLocation = location.map { CodableCoordinate(coordinate: $0) }

        let savedScan = ScanHistoryManager.shared.addScan(
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

        self.selectedScan = savedScan
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

// MARK: - Camera Permission Manager
enum CameraPermissionManager {
    static func checkAndRequestCamera(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
}
