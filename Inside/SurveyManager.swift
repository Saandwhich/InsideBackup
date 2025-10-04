import Foundation

@MainActor
class SurveyManager: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var answers: [Int: [String]] = [:]
    @Published var customOptions: [Int: [String]] = [:]
    @Published var isSurveyComplete = false

    @Published var questions: [SurveyQuestion] = [
        SurveyQuestion(
            question: "What is your name?",
            options: [],
            isMultiSelect: false
        ),
        SurveyQuestion(
            question: "What allergens do you have?",
            options: [
                "Alcohol", "Barley", "Capsaicin", "Celery", "Chocolate", "Citrus fruit", "Corn", "Eggs", "Fish", "Fruits", "Garlic", "Onion", "Basil", "Licorice", "Oregano", "Peppermint", "Rosemary", "Sage", "Thai Basil", "Thyme", "Honey", "Beans", "Chickpeas", "Lentils", "Peanuts", "Peas", "Soybeans", "Lupin", "Milk", "Mushrooms", "Mustard", "Nightshades", "Oats", "Peanut", "Duck", "Goose", "Chicken", "Turkey", "Beef", "Exotic Meat", "Goat", "Pork", "Sheep", "Rice", "Rye", "Amaranth Seeds", "Buckwheat Seeds", "Chia Seeds", "Flax Seeds", "Hemp Seeds", "Millet Seeds", "Poppy Seeds", "Quinoa", "Sunflower Seeds", "Sesame", "Crustacean", "Mollusk", "Shellfish", "Soy", "Allspice", "Anise", "Black Pepper", "Cinnamon", "Cloves", "Coriander", "Fennel", "Ginger", "Nutmeg", "Turmeric", "Vanilla", "Almonds", "Brazil Nuts", "Cashew Nuts", "Chestnuts", "Hazelnuts", "Macadamia", "Pecan", "Pistachio", "Walnuts", "Artichoke", "Asparagus", "Beets", "Bell Peppers", "Broccoli", "Brussels Sprouts", "Cabbage", "Carrots", "Cauliflower", "Cucumber", "Kale", "Lettuce", "Pickles", "Potato", "Spinach", "Squash", "Sweet Potato", "Zucchini", "Wheat", "Yeast"
            ],
            isMultiSelect: true,
            allowsCustomInput: true
        ),
        SurveyQuestion(
            question: "Where do you struggle the most with your diet?",
            options: [
                "Reading and understanding food labels",
                "Knowing if a food meets my dietary needs",
                "Avoiding hidden ingredients or allergens",
                "Understanding what's really in my food",
                "Staying consistent when eating out or on the go",
                "Other"
            ],
            isMultiSelect: false
        ),
        SurveyQuestion(
            question: "What diets do you follow?",
            options: [
                "Anti-inflammatory", "Caffeine free", "Breastfeeding", "Candida overgrowth", "Citric acid intolerance", "Fructose free", "Emulsifier free", "Gluten free", "Gut Friendly", "Lactose Free", "Latex free", "Low FODMAP", "Low Histamine", "Mediterranean diet", "Mold detox", "Paleo", "Pescatarian", "Plantricious", "PCOS", "Pregnancy", "Vegan", "Vegetarian", "30 Whole Days", "Lacto - Vegetarian", "Halal", "Kosher", "High-protein", "Diabetes / Prediabetes", "Chronic Kidney Disease (CKD)", "GERD / Acid Reflux"
            ],
            isMultiSelect: true
        ),
        SurveyQuestion(
            question: "What’s your biggest reason for using Inside?",
            options: [
                "To avoid allergens in my meals",
                "To better manage my dietary restrictions",
                "To feel more confident about what I eat",
                "To understand what’s really in my food",
                "Other"
            ],
            isMultiSelect: false
        )
    ]

    func saveProfile() {
        let rawName = answers[0]?.first ?? ""
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)

        func dedupPreserveOrder(_ arr: [String]) -> [String] {
            var seen = Set<String>()
            var result: [String] = []
            for s in arr.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                if !s.isEmpty && !seen.contains(s) {
                    seen.insert(s)
                    result.append(s)
                }
            }
            return result
        }

        let allergens = dedupPreserveOrder(answers[1] ?? [])
        let dietaryStruggles = dedupPreserveOrder(answers[2] ?? [])
        let diets = dedupPreserveOrder(answers[3] ?? [])
        let reason = (answers[4]?.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let profile = UserProfile(
            name: name,
            allergens: allergens,
            dietaryStruggles: dietaryStruggles,
            diets: diets,
            reason: reason
        )

        ProfileStore.shared.saveProfile(profile)

        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userData")
        }

        print("✅ Profile saved (SurveyManager):", profile)
    }

    func loadProfile() -> UserProfile? {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return decoded
        }
        return nil
    }
}
