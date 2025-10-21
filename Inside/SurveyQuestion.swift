import Foundation

struct SurveyQuestion: Identifiable, Equatable {
    let id = UUID()
    let question: String
    var options: [String]
    var isMultiSelect: Bool
    var allowsCustomInput: Bool = false
    var showsSearchBar: Bool = true
    var optionAlignmentLeading: Bool = false
}
