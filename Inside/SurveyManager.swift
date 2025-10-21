import Foundation
import SwiftUI

@MainActor
class SurveyManager: ObservableObject {
    @Published var currentIndex: Int = 0
    @Published var answers: [Int: [String]] = [:]
    @Published var customOptions: [Int: [String]] = [:]
    @Published var isSurveyComplete = false
    
    private let draftAnswersKey = "surveyDraft.answers"
    private let draftCustomOptionsKey = "surveyDraft.customOptions"
    private let draftCurrentIndexKey = "surveyDraft.currentIndex"
    private let surveyCompletedKey = "survey.completed"
    
    init() {
        loadDraft()
    }
    
    // Mixed array of steps
    @Published var steps: [SurveyStep] = [
        // Questions
        SurveyStep.question(
            SurveyQuestion(
                question: "What is your name?",
                options: [],
                isMultiSelect: false,
                allowsCustomInput: false,
                showsSearchBar: false
            )
        ),
        SurveyStep.question(
            SurveyQuestion(
                question: "What allergens do you have?",
                options: [
                    "Alcohol","Barley","Capsaicin","Celery","Chocolate","Citrus fruit","Corn",
                    "Eggs","Fish","Fruits","Garlic","Onion","Basil","Licorice","Oregano",
                    "Peppermint","Rosemary","Sage","Thai Basil","Thyme","Honey","Beans",
                    "Chickpeas","Lentils","Peanuts","Peas","Soybeans","Lupin","Milk",
                    "Mushrooms","Mustard","Nightshades","Oats","Peanut","Duck","Goose",
                    "Chicken","Turkey","Beef","Exotic Meat","Goat","Pork","Sheep","Rice",
                    "Rye","Amaranth Seeds","Buckwheat Seeds","Chia Seeds","Flax Seeds","Hemp Seeds",
                    "Millet Seeds","Poppy Seeds","Quinoa","Sunflower Seeds","Sesame",
                    "Crustacean","Mollusk","Shellfish","Soy","Allspice","Anise","Black Pepper",
                    "Cinnamon","Cloves","Coriander","Fennel","Ginger","Nutmeg","Turmeric",
                    "Vanilla","Almonds","Brazil Nuts","Cashew Nuts","Chestnuts","Hazelnuts",
                    "Macadamia","Pecan","Pistachio","Walnuts","Artichoke","Asparagus","Beets",
                    "Bell Peppers","Broccoli","Brussels Sprouts","Cabbage","Carrots","Cauliflower",
                    "Cucumber","Kale","Lettuce","Pickles","Potato","Spinach","Squash",
                    "Sweet Potato","Zucchini","Wheat","Yeast"
                ],
                isMultiSelect: true,
                allowsCustomInput: true,
                showsSearchBar: true,
                optionAlignmentLeading: true
            )
        ),
        SurveyStep.question(
            SurveyQuestion(
                question: "What diets do you follow?",
                options: [
                    "Anti-inflammatory","Caffeine free","Breastfeeding","Candida overgrowth","Citric acid intolerance",
                    "Fructose free","Emulsifier free","Gluten free","Gut Friendly","Lactose Free","Latex free","Low FODMAP",
                    "Low Histamine","Mediterranean diet","Mold detox","Paleo","Pescatarian","Plantricious","PCOS","Pregnancy",
                    "Vegan","Vegetarian","30 Whole Days","Lacto - Vegetarian","Halal","Kosher","High-protein","Diabetes / Prediabetes",
                    "Chronic Kidney Disease (CKD)","GERD / Acid Reflux"
                ],
                isMultiSelect: true,
                allowsCustomInput: true,
                showsSearchBar: true,
                optionAlignmentLeading: true
            )
        ),
        SurveyStep.question(
            SurveyQuestion(
                question: "Where do you struggle the most with your diet?",
                options: [
                    "Reading and understanding food labels",
                    "Identifying foods I can eat",
                    "Avoiding hidden ingredients or allergens",
                    "Understanding what's really in my food",
                    "Staying consistent when eating out",
                    "Other"
                ],
                isMultiSelect: true,
                showsSearchBar: false,
                optionAlignmentLeading: true
            )
        ),
        SurveyStep.question(
            SurveyQuestion(
                question: "What’s your biggest reason for using Inside?",
                options: [
                    "To avoid allergens in my meals",
                    "To better manage my dietary restrictions",
                    "To feel more confident about what I eat",
                    "To understand what’s really in my food",
                    "Other"
                ],
                isMultiSelect: true,
                showsSearchBar: false,
                optionAlignmentLeading: true
            )
        ),
        
        // Screens
        SurveyStep.screen(
            SurveyScreen(
                title: "We Need Access To Your Camera and Photos",
                content: "To use Inside, we’re gonna need your camera and photos to analyze your meals. You can always edit these preferences later.",
                imageName: "BlankImage",
                subText: "Remember, Inside doesn't keep track of your data in any way.",
                type: .camera
            )
        ),
        SurveyStep.screen(
            SurveyScreen(
                title: "We Need Location Permission",
                content: "If you want to keep track of where you ate your favorite meals, then click allow. You can always edit these preferences later.",
                imageName: "BlankImage",
                subText: "Remember, Inside doesn't keep track of your data in any way.",
                type: .location
            )
        ),
        SurveyStep.screen(
            SurveyScreen(
                title: "Agree to Terms & Privacy",
                content: "Please agree to our Privacy Policy and Terms of Use to continue using Inside.",
                imageName: nil,
                subText: "You can review these at any time in Settings.",
                type: .generic
            )
        )
    ]
    
    func saveDraft() {
        if let answersData = try? JSONEncoder().encode(answers) {
            UserDefaults.standard.set(answersData, forKey: draftAnswersKey)
        }
        if let customData = try? JSONEncoder().encode(customOptions) {
            UserDefaults.standard.set(customData, forKey: draftCustomOptionsKey)
        }
        UserDefaults.standard.set(currentIndex, forKey: draftCurrentIndexKey)
    }
    
    func loadDraft() {
        if let answersData = UserDefaults.standard.data(forKey: draftAnswersKey),
           let decodedAnswers = try? JSONDecoder().decode([Int: [String]].self, from: answersData) {
            self.answers = decodedAnswers
        }
        if let customData = UserDefaults.standard.data(forKey: draftCustomOptionsKey),
           let decodedCustom = try? JSONDecoder().decode([Int: [String]].self, from: customData) {
            self.customOptions = decodedCustom
        }
        let idx = UserDefaults.standard.integer(forKey: draftCurrentIndexKey)
        self.currentIndex = idx
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftAnswersKey)
        UserDefaults.standard.removeObject(forKey: draftCustomOptionsKey)
        UserDefaults.standard.removeObject(forKey: draftCurrentIndexKey)
    }
    
    var progress: Double {
        Double(currentIndex + 1) / Double(steps.count)
    }
    
    var isCompletedPersisted: Bool {
        UserDefaults.standard.bool(forKey: surveyCompletedKey)
    }
    
    func nextStep() {
        if currentIndex < steps.count - 1 {
            currentIndex += 1
            saveDraft()
        } else {
            saveProfile()
            isSurveyComplete = true
            UserDefaults.standard.set(true, forKey: surveyCompletedKey)
            clearDraft()
        }
    }
    
    // MARK: - Profile Save
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

        let newAllergens = dedupPreserveOrder(answers[1] ?? [])
        // Index 2: "What diets do you follow?" -> diets
        let newDiets = dedupPreserveOrder(answers[2] ?? [])
        // Index 3: "Where do you struggle the most with your diet?" -> dietary struggles
        let newDietaryStruggles = dedupPreserveOrder(answers[3] ?? [])
        // Index 4: "What’s your biggest reason for using Inside?" -> reason (single choice preferred; take first)
        let newReason = (answers[4]?.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Merge with existing profile if present
        let existing = ProfileStore.shared.profile

        let mergedName: String = {
            let existingName = existing?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? existingName : name
        }()

        func mergeLists(_ existing: [String]?, _ incoming: [String]) -> [String] {
            let base = existing ?? []
            // Keep existing order, then append incoming items that aren’t present
            var result: [String] = []
            var seen = Set<String>()
            for s in base {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if !seen.contains(t) {
                    seen.insert(t)
                    result.append(t)
                }
            }
            for s in incoming {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if !seen.contains(t) {
                    seen.insert(t)
                    result.append(t)
                }
            }
            return result
        }

        let mergedAllergens = mergeLists(existing?.allergens, newAllergens)
        let mergedDietaryStruggles = mergeLists(existing?.dietaryStruggles, newDietaryStruggles)
        let mergedDiets = mergeLists(existing?.diets, newDiets)
        let mergedReason: String = {
            let existingReason = existing?.reason.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return newReason.isEmpty ? existingReason : newReason
        }()

        let profile = UserProfile(
            name: mergedName,
            allergens: mergedAllergens,
            dietaryStruggles: mergedDietaryStruggles,
            diets: mergedDiets,
            reason: mergedReason
        )

        ProfileStore.shared.saveProfile(profile)

        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userData")
        }

        print("✅ Profile saved (SurveyManager merged):", profile)
    }
    
    func loadProfile() -> UserProfile? {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return decoded
        }
        return nil
    }
}

// MARK: - SurveyStep enum
enum SurveyStep: Identifiable, Equatable {
    case question(SurveyQuestion)
    case screen(SurveyScreen)
    
    var id: UUID {
        switch self {
        case .question(let q): return q.id
        case .screen(let s): return s.id
        }
    }
}

