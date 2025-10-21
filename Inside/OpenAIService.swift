import UIKit
import Foundation

// NOTE: API Key sourcing
// This service reads the OpenAI API key from Secrets.plist (key: OPENAI_API_KEY) bundled with the app.
// Keep Secrets.plist out of source control and commit a Secrets.sample.plist instead.
// As a fallback, it will also check Info.plist for OPENAI_API_KEY or legacy OpenAIAPIKey.

// MARK: - Meal JSON Model
struct MealVisionJSON: Codable {
    let name: String?
    let ingredients: String?
    let safetyScore: Int?
    let reason: String?
    let suggestions: String?
}

struct ProductAnalysisJSON: Codable {
    let name: String
    let ingredients: String
    let labels: String
    let verifiedClaims: String
    let safetyScore: Int
    let reason: String
    let suggestions: String
}

// MARK: - OpenAI Service Errors
enum OpenAIServiceError: Error {
    case missingAPIKey
    case invalidURL
    case noData
    case unexpectedResponse
    case imageConversionFailed
    case jsonDecodingFailed(String)
    case networkError(String)
}

// MARK: - OpenAI Service
final class OpenAIService {

    // MARK: - API Key
    private var openAIAPIKey: String? {
        // 1) Prefer Secrets.plist bundled with the app (not committed to Git)
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let key = dict["OPENAI_API_KEY"] as? String, !key.isEmpty {
                return key
            }
        }
        // 2) Fallback to Info.plist if present. Support both new and legacy key names.
        if let infoPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let infoDict = NSDictionary(contentsOfFile: infoPath) as? [String: Any] {
            if let key = infoDict["OPENAI_API_KEY"] as? String, !key.isEmpty {
                return key
            }
            if let legacyKey = infoDict["OpenAIAPIKey"] as? String, !legacyKey.isEmpty {
                return legacyKey
            }
        }
        return nil
    }

    // MARK: - Fetch AI Prompt for Category (Personalized)
    func fetchCustomPrompt(
        for category: String,
        userAllergens: [String],
        userDiets: [String],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let apiKey = openAIAPIKey else {
            completion(.failure(OpenAIServiceError.missingAPIKey))
            return
        }

        let allergensList = userAllergens.isEmpty ? "None" : userAllergens.joined(separator: ", ")
        let dietsList = userDiets.isEmpty ? "None" : userDiets.joined(separator: ", ")

        // Create a short personalized prompt depending on the category
        let basePrompt: String
        switch category {
        case "Cultural Spotlight":
            basePrompt = "Give one uncommon meal that is from another cuture, country, or cuisine, that you suggest the user should try based on these dietary restrictions. (Under 35 words)"
        case "Safe Meals":
            basePrompt = "Give one meal that you would suggest a person to try based on these dietary restrictions. (Under 35 words)"
        case "Product Suggestions":
            basePrompt = "Give a list of products and companies in bullet points (Use this '•' symbol) that you suggest for the user based on these dietary restrictions. (Under 35 words)"
        case "Meal Facts":
            basePrompt = "Give a fun fact about one of the users dietary restrictions. It could be about a common food or product they can or shouldnt eat, or about a meal they can or shouldnt eat. (Under 35 words)"
        default:
            basePrompt = "Give one short interesting fact based on the users dietary restrictions. (Under 35 words)"
        }

        let userPrompt = """
        \(basePrompt)
        Allergens: \(allergensList)
        Diets: \(dietsList)
        Output only the suggestion (no JSON or extra commentary).
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 60,
            "temperature": 0.8
        ]

        performRequest(apiKey: apiKey, requestBody: requestBody, debugTag: "CustomPrompt") { result in
            switch result {
            case .success(let content):
                completion(.success(Self.stripCodeFences(content).trimmingCharacters(in: .whitespacesAndNewlines)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }


    // MARK: - Analyze Meal Description
    func analyzeMealDescription(
        _ prompt: String,
        userAllergens: [String],
        userDiets: [String],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let apiKey = openAIAPIKey else {
            completion(.failure(OpenAIServiceError.missingAPIKey))
            return
        }

        let allergensList = userAllergens.isEmpty ? "None" : userAllergens.joined(separator: ", ")
        let dietsList = userDiets.isEmpty ? "None" : userDiets.joined(separator: ", ")

        let scoreReference = """
        SAFETY SCORE REFERENCE:
        1 - Definitely contains all of the user's allergens or conflicts with their dietary restrictions.
        2 - Contains one of the user's allergens or conflicts with their dietary restrictions.
        3-4 - Highly suggested not to eat because it is unclear if the food is safe.
        5-6 - There is likely cross-contamination risk with the user's allergens or dietary restrictions.
        7-8 - Low chance of cross-contamination with the user's allergens or dietary restrictions.
        9 - Appears safe to eat based on the user's dietary restrictions and allergens.
        10 - Meets #9 and is recommended because of additional benefits.
        """

        let systemPrompt = """
        You are a meticulous nutrition assistant. Output STRICT JSON only.
        Schema:
        {
          "name": string,
          "ingredients": string,
          "safetyScore": int,
          "reason": string,
          "suggestions": string
        }
        \(scoreReference)
        """

        let userPrompt = """
        Consider the user's allergens: \(allergensList) and diets: \(dietsList).
        Meal description: \(prompt)
        Produce JSON following the schema above.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 700,
            "temperature": 0.2
        ]

        performRequest(apiKey: apiKey, requestBody: requestBody, debugTag: "Describe") { result in
            switch result {
            case .success(let content):
                print("[Debug Describe] GPT response:\n\(content)")
                let cleaned = Self.stripCodeFences(content)

                guard let data = cleaned.data(using: .utf8) else {
                    completion(.failure(OpenAIServiceError.jsonDecodingFailed("UTF-8 conversion failed.")))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(MealVisionJSON.self, from: data)
                    if let jsonString = try? Self.compactEncodedJSON(decoded) {
                        completion(.success(jsonString))
                    } else {
                        completion(.failure(OpenAIServiceError.jsonDecodingFailed("Re-encoding failed.")))
                    }
                } catch {
                    completion(.failure(OpenAIServiceError.jsonDecodingFailed(error.localizedDescription)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Analyze Product (Barcode / OFF)
    func analyzeOFFProduct(
        productName: String,
        ingredients: String,
        userAllergens: [String],
        userDiets: [String],
        extraInfo: String,
        completion: @escaping (String) -> Void
    ) {
        guard let apiKey = openAIAPIKey else {
            completion("Error: Missing API key")
            return
        }

        let allergensList = userAllergens.isEmpty ? "None" : userAllergens.joined(separator: ", ")
        let dietsList = userDiets.isEmpty ? "None" : userDiets.joined(separator: ", ")

        let scoreReference = """
        SAFETY SCORE REFERENCE:
        1 - Definitely contains all of the user's allergens or conflicts with their dietary restrictions.
        2 - Contains one of the user's allergens or conflicts with their dietary restrictions.
        3-4 - Highly suggested not to eat because it is unclear if the food is safe.
        5-6 - There is likely cross-contamination risk with the user's allergens or dietary restrictions.
        7-8 - Low chance of cross-contamination with the user's allergens or dietary restrictions.
        9 - Appears safe to eat based on the user's dietary restrictions and allergens.
        10 - Meets #9 and is recommended because of additional benefits.
        """

        let systemPrompt = """
        You are a meticulous nutrition assistant. Output STRICT JSON only.
        Schema (product):
        {
          "name": string,
          "ingredients": string,
          "labels": string,
          "verifiedClaims": string,
          "safetyScore": int,
          "reason": string,
          "suggestions": string
        }
        SPECIAL RULES:
        - Use provided labels/claims as authoritative.
        - Verified claims must be reflected correctly.
        - Default to traditional preparation of ingredients.
        \(scoreReference)
        """

        let userPrompt = """
        Consider the user's allergens: \(allergensList) and diets: \(dietsList).
        Product: \(productName)
        Ingredients: \(ingredients)
        Claims/Labels: \(extraInfo.isEmpty ? "None" : extraInfo)
        Return JSON following the schema above.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 600,
            "temperature": 0.15
        ]

        performRequest(apiKey: apiKey, requestBody: requestBody, debugTag: "OFF") { result in
            switch result {
            case .success(let content):
                print("[Debug OFF] GPT response:\n\(content)")
                let cleaned = Self.stripCodeFences(content)
                guard let data = cleaned.data(using: .utf8) else {
                    completion("Error: JSON UTF-8 conversion failed.")
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(ProductAnalysisJSON.self, from: data)
                    if let jsonString = try? Self.compactEncodedJSON(decoded) {
                        completion(jsonString)
                    } else {
                        completion("Error: re-encoding failed.")
                    }
                } catch {
                    completion("Error: JSON parse failed - \(error.localizedDescription)")
                }

            case .failure(let error):
                completion("Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Analyze Meal Image
    func analyzeMealImage(
        _ image: UIImage,
        notes: String,
        userAllergens: [String],
        userDiets: [String],
        completion: @escaping (Result<(name: String, analysis: String), Error>) -> Void
    ) {
        guard let apiKey = openAIAPIKey else {
            completion(.failure(OpenAIServiceError.missingAPIKey))
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(OpenAIServiceError.imageConversionFailed))
            return
        }

        let base64 = imageData.base64EncodedString()
        let allergensList = userAllergens.isEmpty ? "None" : userAllergens.joined(separator: ", ")
        let dietsList = userDiets.isEmpty ? "None" : userDiets.joined(separator: ", ")

        let scoreReference = """
        SAFETY SCORE REFERENCE:
        1 - Definitely contains all of the user's allergens or conflicts with their dietary restrictions.
        2 - Contains one of the user's allergens or conflicts with their dietary restrictions.
        3-4 - Highly suggested not to eat because it is unclear if the food is safe.
        5-6 - There is likely cross-contamination risk with the user's allergens or dietary restrictions.
        7-8 - Low chance of cross-contamination with the user's allergens or dietary restrictions.
        9 - Appears safe to eat based on the user's dietary restrictions and allergens.
        10 - Meets #9 and is recommended because of additional benefits.
        """

        let systemPrompt = """
        You are a meticulous nutrition assistant. Output STRICT JSON only.
        Schema:
        {
          "name": string,
          "ingredients": string,
          "safetyScore": int,
          "reason": string,
          "suggestions": string
        }
        \(scoreReference)
        """

        let userPrompt = """
        Consider the user's allergens: \(allergensList) and diets: \(dietsList).
        Notes: \(notes.isEmpty ? "None" : notes)
        Return JSON following the schema.
        """

        let content: [[String: Any]] = [
            ["type": "text", "text": userPrompt],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
        ]

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": content]
            ],
            "max_tokens": 900,
            "temperature": 0.15
        ]

        performRequest(apiKey: apiKey, requestBody: requestBody, debugTag: "Image") { result in
            switch result {
            case .success(let content):
                print("[Debug Image] GPT response:\n\(content)")
                let cleanJSON = Self.stripCodeFences(content)
                guard let jsonData = cleanJSON.data(using: .utf8) else {
                    completion(.failure(OpenAIServiceError.jsonDecodingFailed("UTF-8 conversion failed.")))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(MealVisionJSON.self, from: jsonData)
                    let jsonString = try Self.compactEncodedJSON(decoded)
                    completion(.success((decoded.name ?? "Unknown Meal", jsonString)))
                } catch {
                    completion(.failure(OpenAIServiceError.jsonDecodingFailed(error.localizedDescription)))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Networking Helper
    private func performRequest(
        apiKey: String,
        requestBody: [String: Any],
        debugTag: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(OpenAIServiceError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(OpenAIServiceError.networkError(error.localizedDescription)))
                return
            }

            guard let data = data else {
                completion(.failure(OpenAIServiceError.noData))
                return
            }

            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let message = choices.first?["message"] as? [String: Any],
                    var content = message["content"] as? String
                else {
                    let raw = String(data: data, encoding: .utf8) ?? "No readable body"
                    print("[OpenAIService:\(debugTag)] Unexpected response: \(raw)")
                    completion(.failure(OpenAIServiceError.unexpectedResponse))
                    return
                }

                content = Self.stripCodeFences(content)
                completion(.success(content))

            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Utilities
    static func stripCodeFences(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```"), let range = s.range(of: "\n") {
            s = String(s[range.upperBound...])
        }
        if s.hasSuffix("```"), let range = s.range(of: "```", options: .backwards) {
            s = String(s[..<range.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func compactEncodedJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        let data = try encoder.encode(value)
        guard let s = String(data: data, encoding: .utf8) else {
            throw OpenAIServiceError.jsonDecodingFailed("Encoding to UTF-8 failed.")
        }
        return s
    }
}
