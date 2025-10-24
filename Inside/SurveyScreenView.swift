import SwiftUI
import AVFoundation
import Photos
import CoreLocation
import UIKit

struct SurveyScreenView: View {
    @ObservedObject var manager: SurveyManager
    let screen: SurveyScreen
    let onBackToWelcome: () -> Void
    let onComplete: () -> Void

    @State private var showSettingsAlert = false
    @StateObject private var locationManager = LocationPermissionManager()
    @State private var hasAgreedToTerms = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 10)
                GeometryReader { geo in
                    let progress = CGFloat(manager.steps.isEmpty ? 0 : (manager.currentIndex + 1)) / CGFloat(max(manager.steps.count, 1))
                    Capsule()
                        .fill(Color("PrimaryGreen"))
                        .frame(width: geo.size.width * progress, height: 10)
                }
            }
            .frame(height: 10)
            .padding(.top, 20)
            .padding(.horizontal)

            ScrollView {
                Spacer(minLength: 30)
                
                VStack(alignment: .center, spacing: 24) {
                    // Image
                    if let imageName = screen.imageName, !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 250)
                            .clipped()
                            .cornerRadius(24)
                            .padding(.top, 24)
                    }

                    // Title
                    Text(screen.title)
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.02 * 32)
                        .foregroundColor(Color("PrimaryGreen"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Content
                    if !screen.content.isEmpty {
                        Text(screen.content)
                            .foregroundColor(Color(.darkGray))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Terms agreement section (only on terms screen)
                    if screen.title.lowercased().contains("terms") {
                        Button(action: {
                            UISelectionFeedbackGenerator().selectionChanged()
                            hasAgreedToTerms.toggle()
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(Color("PrimaryGreen"))
                                    .font(.system(size: 22, weight: .semibold))
                                Text("I agree to the Terms of Use and Privacy Policy")
                                    .foregroundColor(Color.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)

                        HStack(spacing: 16) {
                            Link(destination: URL(string: "https://insideapp.framer.ai/terms-of-use-and-disclaimer")!) {
                                Text("View Terms of Use")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("PrimaryGreen"))
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }

                            Link(destination: URL(string: "https://insideapp.framer.ai/privacy-policy")!) {
                                Text("View Privacy Policy")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("PrimaryGreen"))
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 80)
                }
            }

            // Bottom Buttons with reserved subtext space to keep buttons pinned consistently
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Back Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if manager.currentIndex == 0 {
                                onBackToWelcome()
                            } else {
                                manager.currentIndex -= 1
                            }
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Color("PrimaryGreen"))
                                .clipShape(Circle())
                        }

                        Spacer(minLength: 0)

                        // Permission screens use neutral "Continue" and always proceed to the system prompt.
                        if screen.title.contains("Camera") {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                requestCameraAccess()
                            }) {
                                Text("Continue")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PrimaryGreen"))
                                    .cornerRadius(32)
                            }
                        } else if screen.title.contains("Location") {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                requestLocationAccess()
                            }) {
                                Text("Continue")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background(Color("PrimaryGreen"))
                                    .cornerRadius(32)
                            }
                        } else {
                            // Default continue/finish with terms gating
                            let isTermsScreen = screen.title.lowercased().contains("terms")
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                manager.nextStep()
                            }) {
                                Text(manager.currentIndex == manager.steps.count - 1 ? "Finish" : "Continue")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(height: 52)
                                    .frame(maxWidth: .infinity)
                                    .background((!isTermsScreen || hasAgreedToTerms) ? Color("PrimaryGreen") : Color(.systemGray3))
                                    .cornerRadius(32)
                            }
                            .disabled(isTermsScreen && !hasAgreedToTerms)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(Color(.systemBackground))
                }

                // Subtext sits below and does not affect button bar height
                Group {
                    if let subText = screen.subText, !subText.isEmpty {
                        Text(subText)
                            .font(.caption2)
                            .foregroundColor(Color(.gray))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                    } else {
                        Spacer().frame(height: 8)
                    }
                }
            }
            .padding(.bottom, 24)
            .background(Color(.systemBackground))
            .navigationBarBackButtonHidden(true)
            .alert("Camera access is required", isPresented: $showSettingsAlert) {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow camera access in Settings to use Inside.")
            }
        }
    }

    // MARK: - Permissions
    private func requestCameraAccess() {
        // Always proceed to the system prompt when user taps Continue
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                // Proceed in the flow either way
                self.manager.nextStep()
                // Optional: keep this alert only for context if they denied
                if !granted {
                    self.showSettingsAlert = true
                }
            }
        }
    }

    private func requestLocationAccess() {
        // Always proceed to the system prompt when user taps Continue
        locationManager.requestLocation { _ in
            DispatchQueue.main.async {
                // Proceed to next onboarding step regardless of user choice
                self.manager.nextStep()
            }
        }
    }
}

// MARK: - Location Manager Helper
class LocationPermissionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            completion(true)
            self.completion = nil
        case .denied, .restricted:
            completion(false)
            self.completion = nil
        @unknown default:
            completion(false)
            self.completion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            completion?(true)
        case .denied, .restricted:
            completion?(false)
        case .notDetermined:
            return
        @unknown default:
            completion?(false)
        }
        completion = nil
    }
}

