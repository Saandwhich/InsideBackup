import SwiftUI

struct Scan: Identifiable, Hashable {
    let id = UUID().uuidString
    let name: String
    let ingredients: [String]
    let thumbnailImage: UIImage? // or Data if you save images differently
}

class SheetManager: ObservableObject {
    static let shared = SheetManager()
    @Published var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case restrictionSelection(initialTag: String?)
        case scanDetail(scanEntry: ScanEntry)

        var id: UUID {
            switch self {
            case .restrictionSelection(_):
                return UUID()
            case .scanDetail(let scanEntry):
                return scanEntry.id
            }
        }
    }
}
