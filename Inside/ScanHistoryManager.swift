import SwiftUI
import Combine
import CoreLocation

// MARK: - Scan Types
enum ScanType: String, Codable {
    case barcode, text, camera, upload
}

// MARK: - ScanEntry
final class ScanEntry: Identifiable, ObservableObject, Codable {
    let id: UUID
    let name: String
    let ingredients: [String]
    let score: Int
    let reason: String
    let suggestions: String
    @Published var bookmarked: Bool
    let thumbnailImageData: Data?
    let scannedDate: Date?
    let scannedLocation: CodableCoordinate?
    let scanType: ScanType
    
    var thumbnailImage: UIImage? {
        guard let data = thumbnailImageData else { return nil }
        return UIImage(data: data)
    }
    
    // Codable keys
    enum CodingKeys: String, CodingKey {
        case id, name, ingredients, score, reason, suggestions, bookmarked, thumbnailImageData, scannedDate, scannedLocation, scanType
    }
    
    init(id: UUID = UUID(),
         name: String,
         ingredients: [String],
         score: Int,
         reason: String = "",
         suggestions: String = "",
         bookmarked: Bool = false,
         thumbnailImageData: Data? = nil,
         scannedDate: Date? = nil,
         scannedLocation: CodableCoordinate? = nil,
         scanType: ScanType) {
        self.id = id
        self.name = name
        self.ingredients = ingredients
        self.score = score
        self.reason = reason
        self.suggestions = suggestions
        self.bookmarked = bookmarked
        self.thumbnailImageData = thumbnailImageData
        self.scannedDate = scannedDate
        self.scannedLocation = scannedLocation
        self.scanType = scanType
    }
    
    // Codable conformance for class with @Published
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        score = try container.decode(Int.self, forKey: .score)
        reason = try container.decode(String.self, forKey: .reason)
        suggestions = try container.decode(String.self, forKey: .suggestions)
        bookmarked = try container.decode(Bool.self, forKey: .bookmarked)
        thumbnailImageData = try container.decodeIfPresent(Data.self, forKey: .thumbnailImageData)
        scannedDate = try container.decodeIfPresent(Date.self, forKey: .scannedDate)
        scannedLocation = try container.decodeIfPresent(CodableCoordinate.self, forKey: .scannedLocation)
        scanType = try container.decode(ScanType.self, forKey: .scanType)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(score, forKey: .score)
        try container.encode(reason, forKey: .reason)
        try container.encode(suggestions, forKey: .suggestions)
        try container.encode(bookmarked, forKey: .bookmarked)
        try container.encode(thumbnailImageData, forKey: .thumbnailImageData)
        try container.encode(scannedDate, forKey: .scannedDate)
        try container.encode(scannedLocation, forKey: .scannedLocation)
        try container.encode(scanType, forKey: .scanType)
    }
}

// MARK: - CodableCoordinate
struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    init(coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

// MARK: - ScanHistoryManager
final class ScanHistoryManager: ObservableObject {
    static let shared = ScanHistoryManager()
    @Published var scans: [ScanEntry] = []
    
    private init() { loadScans() }
    
    @discardableResult
    func addScan(name: String,
                 ingredients: [String],
                 score: Int,
                 reason: String = "",
                 suggestions: String = "",
                 image: UIImage?,
                 date: Date = Date(),
                 location: CLLocationCoordinate2D? = nil,
                 scanType: ScanType) -> ScanEntry {

        let imageData = image?.jpegData(compressionQuality: 0.8)
        let coordinate = location.map { CodableCoordinate(coordinate: $0) }

        let entry = ScanEntry(name: name,
                              ingredients: ingredients,
                              score: score,
                              reason: reason,
                              suggestions: suggestions,
                              thumbnailImageData: imageData,
                              scannedDate: date,
                              scannedLocation: coordinate,
                              scanType: scanType)

        // insert at front
        scans.insert(entry, at: 0)
        saveScans()

        return entry
    }
    
    func removeScan(_ scan: ScanEntry) {
        scans.removeAll { $0.id == scan.id }
        saveScans()
    }
    
    func toggleBookmark(_ scan: ScanEntry) {
        scan.bookmarked.toggle()
        saveScans()
    }
    
    // MARK: - Persistence
    func saveScans() {
        if let data = try? JSONEncoder().encode(scans) {
            UserDefaults.standard.set(data, forKey: "scanHistory")
        }
    }
    
    private func loadScans() {
        guard let data = UserDefaults.standard.data(forKey: "scanHistory"),
              let savedScans = try? JSONDecoder().decode([ScanEntry].self, from: data) else { return }
        scans = savedScans
    }
    
    func clearHistory() {
        scans.removeAll()
        saveScans()
    }
}
