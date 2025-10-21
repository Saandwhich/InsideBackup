import SwiftUI
import MapKit

// MARK: - HomeView
struct HomeView: View {
    // MARK: - Data Sources
    @ObservedObject var profileStore = ProfileStore.shared
    @ObservedObject var historyManager = ScanHistoryManager.shared
    
    // MARK: - UI State
    @State private var showingTagSelector = false
    @State private var wrapHeight: CGFloat = 0
    @State private var selectedScan: ScanEntry?
    @State private var pendingDelete: ScanEntry? = nil
    
    // Suggestions
    @State private var selectedSuggestionCategory: String = {
        ["Cultural Spotlight", "Product Suggestions", "Safe Meals", "Meal Facts"].randomElement() ?? "Cultural Spotlight"
    }()
    @State private var suggestionLoading = false
    @State private var suggestions: [String: String] = [
        "Cultural Spotlight": "Loading...",
        "Product Suggestions": "Loading...",
        "Safe Meals": "Loading...",
        "Meal Facts": "Loading..."
    ]
    
    private let openAIService = OpenAIService()
    
    // MARK: - Computed Properties
    private var combinedTags: [String] {
        (profileStore.profile?.allergens ?? []) + (profileStore.profile?.diets ?? []) + ["__addButton__"]
    }
    
    private var displayName: String {
        let raw = profileStore.profile?.name ?? ""
        return raw.isEmpty ? "there" : raw
    }
    
    private var savedScans: [ScanEntry] {
        historyManager.scans.filter { $0.bookmarked }
    }
    
    private var streakDays: Int {
        computeStreakDays(from: historyManager.scans)
    }
    
    private var weeklyScans: Int {
        computeWeeklyScans(from: historyManager.scans)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    
                    // Greeting
                    Text("Hey \(displayName)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Dietary Restrictions
                    Text("Current Dietary Restrictions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        WrapHStack(items: combinedTags, totalHeight: $wrapHeight) { tag in
                            if tag == "__addButton__" {
                                Button { showingTagSelector = true } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .frame(width: 32, height: 32)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                            } else {
                                Text(tag)
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(minHeight: 44, maxHeight: wrapHeight)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    // Suggestions
                    Text("Suggestions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Button {
                                cycleSuggestionCategory()
                                fetchPersonalizedSuggestion(for: selectedSuggestionCategory)
                            } label: {
                                HStack(spacing: 6) {
                                    categoryIcon(for: selectedSuggestionCategory)
                                        .foregroundColor(.black)
                                    Text(selectedSuggestionCategory)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.black)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                // Refresh also cycles category
                                cycleSuggestionCategory()
                                fetchPersonalizedSuggestion(for: selectedSuggestionCategory)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color("PrimaryGreen"))
                            }
                        }
                        
                        if suggestionLoading {
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(suggestions[selectedSuggestionCategory] ?? "")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Progress
                    Text("Your Progress")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    GeometryReader { geo in
                        HStack(spacing: 20) {
                            // Weekly Scans
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(min(Double(weeklyScans)/7.0, 1.0)))
                                        .stroke(Color("PrimaryGreen"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                        .frame(width: 60, height: 60)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeOut(duration: 0.5), value: weeklyScans)
                                    Text("\(weeklyScans)")
                                        .font(.title3.bold())
                                        .foregroundColor(Color("PrimaryGreen"))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("This Week")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.black)
                                    Text("Scans completed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: geo.size.width * 0.5, alignment: .leading)
                            
                            Divider()
                                .frame(height: 70)
                            
                            // Streak
                            HStack(spacing: 10) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(streakDays) Days")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(Color("PrimaryGreen"))
                                    Text("Current Streak")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: geo.size.width * 0.5, alignment: .leading)
                        }
                    }
                    .frame(height: 80)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                    
                    // Saved Meals
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Meals")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 4)
                        
                        if savedScans.isEmpty {
                            Text("You haven't saved any meals yet.")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(savedScans) { scan in
                                    Button {
                                        DispatchQueue.main.async {
                                            selectedScan = scan
                                        }
                                    } label: {
                                        SavedMealCardView(scan: scan) {
                                            historyManager.toggleBookmark(scan)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            pendingDelete = scan
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .navigationBarHidden(true)
        }
        // MARK: Sheets
        .sheet(isPresented: $showingTagSelector) {
            RestrictionSelectionView()
        }
        .sheet(item: $selectedScan) { s in
            ResultView(
                scan: s,
                isPresented: Binding(
                    get: { selectedScan != nil },
                    set: { if !$0 { selectedScan = nil } }
                ),
                onClose: { selectedScan = nil }
            )
        }
        .alert("Delete Meal?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let toDelete = pendingDelete {
                    historyManager.removeScan(toDelete)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this meal from your history?")
        }
        .onAppear {
            fetchPersonalizedSuggestion(for: selectedSuggestionCategory)
        }
    }
    
    // MARK: - Helpers
    
    private func fetchPersonalizedSuggestion(for category: String) {
        suggestionLoading = true
        openAIService.fetchCustomPrompt(
            for: category,
            userAllergens: profileStore.profile?.allergens ?? [],
            userDiets: profileStore.profile?.diets ?? []
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    suggestions[category] = text
                    suggestionLoading = false
                case .failure(let error):
                    suggestions[category] = "Failed to load suggestion."
                    suggestionLoading = false
                    print("Error fetching prompt: \(error)")
                }
            }
        }
    }
    
    private func categoryIcon(for category: String) -> Image {
        switch category {
        case "Cultural Spotlight": return Image(systemName: "globe")
        case "Product Suggestions": return Image(systemName: "cart.fill")
        case "Safe Meals": return Image(systemName: "fork.knife")
        case "Meal Facts": return Image(systemName: "brain")
        default: return Image(systemName: "lightbulb")
        }
    }
    
    private func cycleSuggestionCategory() {
        let all = Array(suggestions.keys.sorted())
        if let index = all.firstIndex(of: selectedSuggestionCategory) {
            selectedSuggestionCategory = all[(index + 1) % all.count]
        }
    }
    
    // MARK: - Streak & Weekly Scan Logic
    private func computeWeeklyScans(from scans: [ScanEntry]) -> Int {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return scans.filter { $0.scannedDate ?? Date.distantPast >= weekStart }.count
    }
    
    private func computeStreakDays(from scans: [ScanEntry]) -> Int {
        let calendar = Calendar.current
        let sortedDates = scans.compactMap { $0.scannedDate }.sorted(by: { $0 > $1 })
        var streak = 0
        var currentDate = Date()
        
        for date in sortedDates {
            if calendar.isDate(date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: currentDate)!) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
        }
        
        return streak
    }
    


    
    // MARK: - SavedMealCardView
    private struct SavedMealCardView: View {
        let scan: ScanEntry
        var bookmarkAction: () -> Void
        
        private let thumb: CGFloat = 64
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                if let image = scan.thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: thumb, height: thumb)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ZStack {
                        Color(.lightGray)
                        Image(systemName: placeholderIcon(for: scan.scanType))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: thumb, height: thumb)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(scan.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Button(action: bookmarkAction) {
                            Image(systemName: scan.bookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("PrimaryGreen"))
                        }
                        .contentShape(Rectangle())
                    }
                    
                    MiniScoreBar(score: scan.score)
                    
                    HStack(spacing: 8) {
                        if let date = scan.scannedDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(date, style: .date)
                            }
                        }
                        Spacer(minLength: 12)
                        if let coord = scan.scannedLocation?.coordinate {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                Text("View Map")
                            }
                            .onTapGesture { openInMaps(coord, title: scan.name) }
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
                .frame(minHeight: thumb, maxHeight: thumb)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        
        private func placeholderIcon(for type: ScanType) -> String {
            switch type {
            case .barcode: return "barcode.viewfinder"
            case .text: return "text.alignleft"
            case .camera, .upload: return "photo"
            }
        }
        
        private func openInMaps(_ coordinate: CLLocationCoordinate2D, title: String) {
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = title
            mapItem.openInMaps(launchOptions: nil)
        }
    }
    
    // MARK: - MiniScoreBar
    private struct MiniScoreBar: View {
        let score: Int
        
        var body: some View {
            GeometryReader { geo in
                let total = max(geo.size.width, 1)
                let fillWidth = total * CGFloat(min(max(score, 0), 10)) / 10.0
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 16)
                    
                    ZStack {
                        Capsule()
                            .fill(scoreColor(score))
                            .frame(width: fillWidth, height: 16)
                        
                        Text("\(score)/10")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: fillWidth, height: 16, alignment: .center)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 16)
        }
        
        private func scoreColor(_ s: Int) -> Color {
            switch s {
            case 0..<4: return .red
            case 4..<7: return .yellow
            default: return Color("PrimaryGreen")
            }
        }
    }
}

