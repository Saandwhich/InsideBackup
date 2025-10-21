import SwiftUI
import MapKit
import CoreLocation

struct HistoryView: View {
    @ObservedObject var historyManager = ScanHistoryManager.shared
    @State private var searchText: String = ""
    @State private var selectedScan: ScanEntry? = nil   // <- use item sheet
    @State private var pendingDelete: ScanEntry? = nil
    @State private var showAddMealSheet = false

    var filteredScans: [ScanEntry] {
        if searchText.isEmpty { return historyManager.scans }
        return historyManager.scans.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Title
                    Text("History")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color("PrimaryGreen"))
                        .padding(.horizontal)
                        .padding(.top, 20)

                    // MARK: - Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search Recent Scans...", text: $searchText)
                            .foregroundColor(.primary)
                            .accentColor(Color("PrimaryGreen"))
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .padding(.horizontal)

                    // MARK: - Scan Cards or Placeholder
                    if filteredScans.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .font(.system(size: 44))
                                .foregroundColor(Color("PrimaryGreen").opacity(0.8))
                                .padding(.bottom, 4)
                            
                            Text("No scanned meals yet.")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Text("Click the green plus button below to scan your first meal.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding()
                        .sheet(isPresented: $showAddMealSheet) {
                            AddMealOptionsView(
                                onDescribeMealTap: {},
                                onUploadImageTap: {},
                                onTakePhotoTap: {},
                                onScanBarcodeTap: {}
                            )
                            .presentationDetents([.fraction(0.58)])
                            .presentationDragIndicator(.hidden)
                            .presentationBackground(Color.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredScans) { scan in
                                Button(action: {
                                    selectedScan = scan            // <- set item; triggers sheet(item:)
                                }) {
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
            .navigationBarHidden(true)
        }
        // Use item-based sheet to avoid blank/laggy presentation
        .sheet(item: $selectedScan) { s in
            ResultView(
                scan: s,                   // Pass the object
                isPresented: Binding(
                    get: { selectedScan != nil },
                    set: { if !$0 { selectedScan = nil } }
                ),
                onClose: { selectedScan = nil }
            )
            .id(s.id) // ensure a fresh ResultView per selection
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
    }
}

// MARK: - SavedMealCardView (matches HomeView style)
private struct SavedMealCardView: View {
    @ObservedObject var scan: ScanEntry
    var bookmarkAction: () -> Void

    private let thumb: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Thumbnail or placeholder
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

            // Text + score + meta
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

// MARK: - MiniScoreBar (centered score inside capsule)
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
                        .font(.system(size: 10, weight: .bold))
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
        case 4..<8: return .yellow
        default:     return Color("PrimaryGreen")
        }
    }
}
