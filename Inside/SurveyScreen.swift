import Foundation

enum ScreenType {
    case camera
    case location
    case generic
    case agreements
}

struct SurveyScreen: Identifiable, Equatable {
    let id = UUID()
    let title: String
    var content: String
    var imageName: String?
    var subText: String?
    var type: ScreenType = .generic
}


