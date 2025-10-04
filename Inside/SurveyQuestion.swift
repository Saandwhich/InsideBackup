import Foundation

struct SurveyQuestion: Identifiable {
    let id = UUID()
    let question: String
    var options: [String]
    var isMultiSelect: Bool
    var allowsCustomInput: Bool = false   // ✅ add this line
}

