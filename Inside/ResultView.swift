import SwiftUI
import UIKit
import MapKit
import CoreLocation

struct ResultView: View {
    @ObservedObject var scan: ScanEntry                  // ScanEntry must be ObservableObject
    @ObservedObject var historyManager = ScanHistoryManager.shared
    @Binding var isPresented: Bool
    let onClose: () -> Void

    @State private var animatedScore: Double = 0
    @State private var showContent = false
    @State private var region: MKCoordinateRegion

    private var ingredientsText: String {
        scan.ingredients.isEmpty ? "N/A" : scan.ingredients.joined(separator: ", ")
    }

    private var progressColor: Color {
        switch scan.score {
        case 1...4: return Color(hex: "#D90C0C")
        case 5...7: return Color(hex: "#F6CD15")
        case 8...10: return Color("PrimaryGreen")
        default: return Color.gray
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: scan.scannedDate ?? Date())
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scan.scannedDate ?? Date())
    }

    // MARK: - Init
    init(scan: ScanEntry, isPresented: Binding<Bool>, onClose: @escaping () -> Void) {
        self.scan = scan
        self._isPresented = isPresented
        self.onClose = onClose
        if let loc = scan.scannedLocation?.coordinate {
            self._region = State(initialValue: MKCoordinateRegion(center: loc, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        } else {
            self._region = State(initialValue: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Analysis Result")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color("PrimaryGreen"))
                Spacer()
                Button(action: {
                    isPresented = false
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.black)
                        .font(.system(size: 12, weight: .medium))
                        .padding(8)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Meal Image
                    if let mealImage = scan.thumbnailImage {
                        Image(uiImage: mealImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .aspectRatio(4/3, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                            .padding(.top, 16)
                    } else {
                        Spacer().frame(height: 16)
                    }

                    // Meal Name + Bookmark
                    HStack {
                        Text(scan.name.isEmpty ? "Meal Name Unavailable" : scan.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                        Button(action: toggleBookmark) {
                            Image(systemName: scan.bookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(Color("PrimaryGreen"))
                        }
                    }
                    .padding(.horizontal)

                    parsedAnalysisView
                }
            }
        }
        .background(Color.white)
        .onAppear {
            withAnimation {
                showContent = true
                animatedScore = Double(scan.score)
            }
        }
    }

    // MARK: - Bookmark toggle helper
    private func toggleBookmark() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scan.bookmarked.toggle()
            historyManager.saveScans()
        }
    }

    private var parsedAnalysisView: some View {
        VStack(spacing: 22) {
            sectionHeader(icon: "list.bullet", title: "Ingredients")
            sectionBody(ingredientsText, delay: 0.2)

            sectionHeader(icon: "heart.text.clipboard", title: "Safety Score", trailing: "\(scan.score)/10")
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                GeometryReader { geo in
                    Capsule()
                        .fill(progressColor)
                        .frame(width: geo.size.width * CGFloat(animatedScore) / 10, height: 16)
                        .animation(.easeOut(duration: 1.0), value: animatedScore)
                }
                .frame(height: 16)
            }
            .padding(.horizontal)
            .opacity(showContent ? 1 : 0)
            .animation(.easeIn(duration: 0.5).delay(0.4), value: showContent)

            sectionHeader(icon: "exclamationmark.triangle", title: "Reason")
            sectionBody(scan.reason, delay: 0.6)

            sectionHeader(icon: "lightbulb", title: "Suggestions")
            sectionBody(scan.suggestions, delay: 0.8)

            // Date + Time
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Date", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundColor(.black)
                    Text(formattedDate)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Time", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.black)
                    Text(formattedTime)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            // Location
            sectionHeader(icon: "mappin.and.ellipse", title: "Location")
            if let location = scan.scannedLocation?.coordinate {
                ZStack {
                    Map(coordinateRegion: $region,
                        interactionModes: [],
                        showsUserLocation: false,
                        annotationItems: [AnnotatedLocation(coordinate: region.center)]) { loc in
                        MapMarker(coordinate: loc.coordinate, tint: Color("PrimaryGreen"))
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Button(action: { openInAppleMaps(location: location) }) {
                        Color.clear
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 20)
    }

    private func openInAppleMaps(location: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: location)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = scan.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    // MARK: - Subviews
    @ViewBuilder
    private func sectionHeader(icon: String, title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
            Text(title)
                .font(.headline)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.subheadline)
                    .bold()
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func sectionBody(_ text: String, delay: Double) -> some View {
        Text(text)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .opacity(showContent ? 1 : 0)
            .animation(.easeIn(duration: 0.5).delay(delay), value: showContent)
            .padding(.horizontal)
    }
}

struct AnnotatedLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
