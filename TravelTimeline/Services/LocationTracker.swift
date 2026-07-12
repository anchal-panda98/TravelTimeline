import CoreLocation
import Foundation

@MainActor
final class LocationTracker: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isTracking = false
    @Published private(set) var latestLocation: CLLocation?
    @Published var lastErrorMessage: String?

    private let manager = CLLocationManager()
    private let store: TimelineStore

    init(store: TimelineStore) {
        self.store = store
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = true
    }

    var canTrackInBackground: Bool {
        authorizationStatus == .authorizedAlways
    }

    var authorizationSummary: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location permission has not been requested."
        case .restricted:
            return "Location permission is restricted on this device."
        case .denied:
            return "Location permission is denied. Enable it in Settings to track visits."
        case .authorizedWhenInUse:
            return "Tracking works while the app is open. Allow Always for background timeline updates."
        case .authorizedAlways:
            return "Background location is enabled."
        @unknown default:
            return "Location permission is in an unknown state."
        }
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func startTracking() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestWhenInUsePermission()
            return
        }

        manager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
        manager.startUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
        isTracking = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }
}

extension LocationTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if isTracking {
                manager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            latestLocation = location
            await store.record(location: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            lastErrorMessage = error.localizedDescription
        }
    }
}
