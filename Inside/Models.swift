import Foundation
import Combine
import UIKit
import CoreLocation

// UserProfile now includes allergen/diet severity mapping
class UserProfile: ObservableObject, Codable {
    @Published var name: String
    @Published var allergens: [String]
    @Published var dietaryStruggles: [String]
    @Published var diets: [String]
    @Published var reason: String


    init(
        name: String = "",
        allergens: [String] = [],
        dietaryStruggles: [String] = [],
        diets: [String] = [],
        reason: String = ""
    ) {
        self.name = name
        self.allergens = allergens
        self.dietaryStruggles = dietaryStruggles
        self.diets = diets
        self.reason = reason
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case name, allergens, dietaryStruggles, diets, reason, restrictionSeverities
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.allergens = try container.decode([String].self, forKey: .allergens)
        self.dietaryStruggles = try container.decode([String].self, forKey: .dietaryStruggles)
        self.diets = try container.decode([String].self, forKey: .diets)
        self.reason = try container.decode(String.self, forKey: .reason)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(allergens, forKey: .allergens)
        try container.encode(dietaryStruggles, forKey: .dietaryStruggles)
        try container.encode(diets, forKey: .diets)
        try container.encode(reason, forKey: .reason)
    }
}

// Simple container for saved meal analysis (unchanged)
struct MealAnalysis: Decodable {
    let mealName: String
    let ingredients: String
    let safetyScore: Int
    let reason: String
    let suggestions: String
}
