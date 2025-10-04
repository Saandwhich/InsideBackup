import Foundation
import CoreLocation
import SwiftUI

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager() // singleton

    @Published var userLocation: CLLocation?

    private let manager = CLLocationManager()
    private let requestedKey = "locationPermissionRequested"

    private override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocationPermission() {
        let status = manager.authorizationStatus
        let hasRequested = UserDefaults.standard.bool(forKey: requestedKey)

        if !hasRequested && status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            UserDefaults.standard.set(true, forKey: requestedKey)
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        // else: denied, do nothing
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }
}
