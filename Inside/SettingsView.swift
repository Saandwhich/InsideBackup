import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject private var profileStore = ProfileStore.shared
    @AppStorage("userName") private var fallbackName: String = ""
    @State private var showingClearAlert = false

    private var displayName: String {
        if let name = profileStore.profile?.name, !name.isEmpty {
            return name
        } else if !fallbackName.isEmpty {
            return fallbackName
        } else {
            return "User"
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryGreen"))
                    .padding(.top, 20)
                    .padding(.horizontal)

                // Profile Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Profile")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        NavigationLink(destination: ManageNameViewBox()) {
                            SettingsButton(icon: "person.crop.circle", text: "Manage Name")
                        }
                        NavigationLink(destination: RestrictionSelectionView()) {
                            SettingsButton(icon: "leaf", text: "Manage Dietary Restrictions")
                        }
                    }
                }

                // App Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("App Settings")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        NavigationLink(destination: CameraSettingsViewBox()) {
                            SettingsButton(icon: "camera", text: "Camera Settings")
                        }
                        NavigationLink(destination: LocationSettingsViewBox()) {
                            SettingsButton(icon: "location", text: "Manage Location Settings")
                        }
                        NavigationLink(destination: AboutAppViewBox()) {
                            SettingsButton(icon: "info.circle", text: "About App")
                        }
                    }
                }

                // Clear History Button
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal)

                    Button(action: {
                        showingClearAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear History")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .alert(isPresented: $showingClearAlert) {
                        Alert(
                            title: Text("Clear History?"),
                            message: Text("This will permanently delete all your scan history."),
                            primaryButton: .destructive(Text("Clear")) {
                                ScanHistoryManager.shared.clearHistory()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }

                Spacer()
            }
            .navigationBarHidden(true)
            .background(Color.white.ignoresSafeArea())
        }
        .accentColor(Color("PrimaryGreen"))
    }
}

// MARK: - Settings Button
struct SettingsButton: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
                .foregroundColor(.black)

            Text(text)
                .font(.body)
                .foregroundColor(.black)

            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}


// MARK: - Manage Name Screen
struct ManageNameViewBox: View {
    @ObservedObject private var profileStore = ProfileStore.shared
    @AppStorage("userName") private var fallbackName: String = ""
    @State private var newName: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CircleBackButton(action: { dismiss() })
                .padding(.top)
                .padding(.leading)

            Text("Manage Name")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Name")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                TextField("Enter your name", text: $newName)
                    .padding()
                    .background(Color(.white))
                    .cornerRadius(12)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            Button(action: saveName) {
                Text("Save")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if let current = profileStore.profile?.name, !current.trimmingCharacters(in: .whitespaces).isEmpty {
                newName = current
            } else {
                newName = fallbackName
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func saveName() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if var profile = profileStore.profile {
            profile.name = trimmed
            profileStore.saveProfile(profile)
        } else {
            fallbackName = trimmed
        }
        dismiss()
    }
}

// MARK: - Camera Settings Screen
struct CameraSettingsViewBox: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CircleBackButton(action: { dismiss() })
                .padding(.top)
                .padding(.leading)

            Text("Camera Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Manage camera & photo permissions. Tap the button below to open iOS Settings and change permissions for the app.")
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            Button(action: openSystemSettings) {
                Text("Open iOS Settings")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white.ignoresSafeArea())
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Location Settings Screen
struct LocationSettingsViewBox: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CircleBackButton(action: { dismiss() })
                .padding(.top)
                .padding(.leading)

            Text("Location Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Manage location permissions for Inside. Tap the button below to open iOS Settings and change location access for the app.")
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            Button(action: openSystemSettings) {
                Text("Open iOS Settings")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white.ignoresSafeArea())
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - About App Screen
struct AboutAppViewBox: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CircleBackButton(action: { dismiss() })
                .padding(.top)
                .padding(.leading)

            Text("About Inside")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Inside helps you analyze meals and packaged products against your dietary restrictions and allergens. We use a combination of image analysis, Open Food Facts and AI to provide personalized guidance.")
                    .foregroundColor(.black)
                Text("-------------------------")
                    .foregroundColor(.gray)
                Text("Version 1.0.0")
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white.ignoresSafeArea())
    }
}
