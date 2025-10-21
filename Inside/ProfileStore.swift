import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()
    @Published var profile: UserProfile?

    private let storageKey = "userProfile"

    private init() {
        loadProfile()
    }

    // Save profile to UserDefaults
    func saveProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            self.profile = profile
            print("✅ Saved profile:", profile)
        } else {
            print("❌ Failed to encode UserProfile")
        }
    }

    // Load profile from UserDefaults, or leave nil until a real profile is saved
    func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
            print("✅ Loaded profile:", decoded)
        } else {
            self.profile = nil
            print("ℹ️ No saved profile found (profile is nil until survey completes)")
        }
    }
}
