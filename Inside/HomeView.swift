import SwiftUI
import MapKit

struct HomeView: View {
    // Data sources
    @ObservedObject var profileStore = ProfileStore.shared
    @ObservedObject var historyManager = ScanHistoryManager.shared

    // UI state
    @State private var showingTagSelector = false
    @State private var wrapHeight: CGFloat = 0
    @State private var selectedScan: ScanEntry?      // <- use item sheet

    // Tags shown in the quick “restrictions” card
    private var combinedTags: [String] {
        (profileStore.profile?.allergens ?? [])
        + (profileStore.profile?.diets ?? [])
        + ["__addButton__"]
    }

    private var displayName: String {
        let raw = profileStore.profile?.name ?? ""
        return raw.isEmpty ? "there" : raw
    }

    private var savedScans: [ScanEntry] {
        historyManager.scans.filter { $0.bookmarked }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                // MARK: - Top Section
                VStack(alignment: .leading, spacing: 14) {
                    Text("Hey \(displayName)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Text("Current Dietary Restrictions")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        WrapHStack(items: combinedTags, totalHeight: $wrapHeight) { tag in
                            if tag == "__addButton__" {
                                Button {
                                    showingTagSelector = true
                                } label: {
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
                }
                .padding(.top, 8)
                .padding(.bottom, 8)

                // MARK: - Saved Meals
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
                                    selectedScan = scan          // <- set item; triggers sheet(item:)
                                } label: {
                                    SavedMealCardView(
                                        scan: scan,
                                        bookmarkAction: {
                                            historyManager.toggleBookmark(scan)
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTagSelector, onDismiss: {
            if let profile = profileStore.profile {
                profileStore.saveProfile(profile)
            }
        }) {
            RestrictionSelectionView()
        }
        // Present ResultView using item sheet — prevents blank first-open
        .sheet(item: $selectedScan) { s in
            ResultView(
                scan: s,
                isPresented: Binding(
                    get: { selectedScan != nil },
                    set: { if !$0 { selectedScan = nil } }
                ),
                onClose: { selectedScan = nil }
            )
            .id(s.id) // ensure fresh view for each scan id
        }
    }
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
        default:     return Color("PrimaryGreen")
        }
    }
}
