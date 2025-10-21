import SwiftUI

@main
struct InsideApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var historyManager = ScanHistoryManager.shared

    var body: some Scene {
        WindowGroup {
            OnboardingFlowView()
                .environmentObject(appState)
                .environmentObject(historyManager)
        }
    }
}
