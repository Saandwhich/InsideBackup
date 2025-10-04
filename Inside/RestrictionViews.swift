import SwiftUI

// MARK: - Restriction Selection View
struct RestrictionSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileStore = ProfileStore.shared
    @State private var searchText = ""
    @State private var showingCustomAdd = false

    // MARK: - Predefined Allergen List
    private let allergenList: [String] = [
        "Alcohol","Barley","Capsaicin (peppers)","Celery","Chocolate","Citrus fruit","Corn","Eggs","Fish","Fruits","Garlic",
        "Onion","Basil","Licorice","Oregano","Peppermint","Rosemary","Sage","Thai Basil","Thyme","Honey","Beans",
        "Chickpeas","Lentils","Peanuts","Peas","Soybeans","Lupin","Milk","Mushrooms","Mustard","Nightshades","Oats",
        "Peanut","Duck","Goose","Chicken","Turkey","Beef","Exotic Meat","Goat","Pork","Sheep (Lamb)","Rice","Rye",
        "Amaranth Seeds","Buckwheat Seeds","Chia Seeds","Flax Seeds","Hemp Seeds","Millet Seeds","Poppy Seeds","Quinoa",
        "Sunflower Seeds","Sesame","Crustacean","Mollusk","Shellfish","Soy","Allspice","Anise","Black Pepper","Cinnamon",
        "Cloves","Corriandor","Fennel","Ginger","Nutmeg","Turmeric","Vanilla","Almonds","Brazil Nuts","Cashew Nuts",
        "Chestnuts","Hazelnuts","Macadamia","Pecan","Pistachio","Walnuts","Artichoke","Asparagus","Beets","Bell Peppers",
        "Broccoli","Brussel sprouts","Cabbage","Carrots","Cauliflower","Cucumber","Kale","Lettuce","Pickles","Potato",
        "Spinach","Squash","Sweet Potato","Zucchini","Wheat","Yeast"
    ]

    // MARK: - Predefined Diet List
    private let dietList: [String] = [
        "Anti-inflammatory","Caffeine free","Breastfeeding","Candida overgrowth","Citric acid intolerance",
        "Fructose free","Emulsifier free","Gluten free","Gut Friendly","Lactose Free","Latex free","Low FODMAP",
        "Low Histamine","Mediterranean diet","Mold detox","Paleo","Pescatarian","Plantricious","PCOS","Pregnancy",
        "Vegan","Vegetarian","30 Whole Days","Lacto - Vegetarian","Halal","Kosher","High-protein","Diabetes",
        "Chronic Kidney Disease","GERD"
    ]

    // MARK: - Filtered Allergen & Diet Lists
    private var filteredAllergens: [String] {
        let saved = profileStore.profile?.allergens ?? []
        let merged = Set(allergenList + saved)
        let sorted = merged.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return searchText.isEmpty ? sorted : sorted.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredDiets: [String] {
        let saved = profileStore.profile?.diets ?? []
        let merged = Set(dietList + saved)
        let sorted = merged.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return searchText.isEmpty ? sorted : sorted.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: Top Toolbar
            HStack {
                CircleBackButton {
                    dismiss()
                }

                Spacer()

                Text("Manage Dietary Restrictions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    saveProfile()
                    dismiss()
                }) {
                    Text("Done")
                        .foregroundColor(Color("PrimaryGreen"))
                        .bold()
                }
            }
            .padding()

            // MARK: Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search...", text: $searchText)
                    .foregroundColor(.primary)
                    .tint(Color("PrimaryGreen"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(30)
            .padding(.horizontal)

            // MARK: Restrictions List
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    // Add Custom Restriction
                    RestrictionRow(title: "➕ Add Your Own", isSelected: false) {
                        showingCustomAdd = true
                    }
                    .padding(.horizontal)
                    .frame(height: 48)

                    // Allergens Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Allergens")
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryGreen"))
                            .padding(.horizontal)

                        ForEach(filteredAllergens, id: \.self) { allergen in
                            RestrictionRow(
                                title: allergen,
                                isSelected: profileStore.profile?.allergens.contains(allergen) ?? false
                            ) {
                                toggleAllergen(allergen)
                            }
                            .padding(.horizontal)
                            .frame(height: 48)
                        }
                    }

                    // Diets Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Diets")
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryGreen"))
                            .padding(.horizontal)

                        ForEach(filteredDiets, id: \.self) { diet in
                            RestrictionRow(
                                title: diet,
                                isSelected: profileStore.profile?.diets.contains(diet) ?? false
                            ) {
                                toggleDiet(diet)
                            }
                            .padding(.horizontal)
                            .frame(height: 48)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.white)
        }
        // MARK: Custom Restriction Sheet
        .sheet(isPresented: $showingCustomAdd) {
            CustomRestrictionView { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }

                if var profile = profileStore.profile {
                    if !profile.allergens.contains(trimmed) && !profile.diets.contains(trimmed) {
                        profile.allergens.append(trimmed)
                        profileStore.profile = profile
                        profileStore.saveProfile(profile)
                    }
                } else {
                    var newProfile = UserProfile()
                    newProfile.allergens.append(trimmed)
                    profileStore.profile = newProfile
                    profileStore.saveProfile(newProfile)
                }
                showingCustomAdd = false
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white.ignoresSafeArea())
        .dismissKeyboardOnTap()
    }

    // MARK: - Actions
    private func toggleAllergen(_ item: String) {
        guard var profile = profileStore.profile else {
            var newProfile = UserProfile()
            newProfile.allergens.append(item)
            profileStore.profile = newProfile
            profileStore.saveProfile(newProfile)
            return
        }

        if profile.allergens.contains(item) {
            profile.allergens.removeAll { $0 == item }
        } else {
            profile.allergens.append(item)
        }

        profileStore.profile = profile
        profileStore.saveProfile(profile)
    }

    private func toggleDiet(_ item: String) {
        guard var profile = profileStore.profile else {
            var newProfile = UserProfile()
            newProfile.diets.append(item)
            profileStore.profile = newProfile
            profileStore.saveProfile(newProfile)
            return
        }

        if profile.diets.contains(item) {
            profile.diets.removeAll { $0 == item }
        } else {
            profile.diets.append(item)
        }

        profileStore.profile = profile
        profileStore.saveProfile(profile)
    }

    private func saveProfile() {
        if let profile = profileStore.profile {
            profileStore.saveProfile(profile)
        }
    }
}

// MARK: - Restriction Row
struct RestrictionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .font(.body)
            }
            .background(isSelected ? Color("PrimaryGreen") : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Restriction View
struct CustomRestrictionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var onSave: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Add a custom restriction")
                    .font(.headline)
                    .padding(.top)

                TextField("Restriction name", text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                Button("Save") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("PrimaryGreen"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Circle Back Button
struct CircleBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 32, height: 32)

                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 12, weight: .regular))
            }
            .padding(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
