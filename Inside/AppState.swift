import SwiftUI

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var step: OnboardingStep

    // Shared app objects
    @Published var profileStore = ProfileStore.shared
    @Published var historyManager = ScanHistoryManager.shared

    // Active sheets
    enum ActiveSheet: Identifiable {
        case restrictionSelection
        case result(scan: ScanEntry)
        case customInput(option: String)

        var id: String {
            switch self {
            case .restrictionSelection: return "restrictionSelection"
            case .result(let scan): return "result_\(scan.id.uuidString)"
            case .customInput(let option): return "customInput_\(option)"
            }
        }
    }

    @Published var activeSheet: ActiveSheet? = nil

    init() {
        if let _ = UserDefaults.standard.data(forKey: "userData") {
            step = .mainApp
        } else {
            step = .splash // new user starts onboarding
        }
    }
}
