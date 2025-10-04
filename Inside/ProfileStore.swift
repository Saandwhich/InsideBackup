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

    // Load profile from UserDefaults, or use default Guest profile
    func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
            print("✅ Loaded profile:", decoded)
        } else {
            // Default Guest profile
            self.profile = UserProfile(
                name: "Guest",
                allergens: [],
                dietaryStruggles: [],
                diets: [],
                reason: ""
            )
            print("❌ Failed to load profile, using Guest profile")
        }
    }
}
