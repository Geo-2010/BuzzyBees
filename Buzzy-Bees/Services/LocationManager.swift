//
//  LocationManager.swift
//  Buzzy-Bees
//

import Foundation
import CoreLocation

@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var userLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// True until the user has made a first choice — safe to call `requestPermission()` again.
    var needsPermissionRequest: Bool { authorizationStatus == .notDetermined }

    /// True once the user has said no — the system won't re-prompt, only Settings can fix it.
    var isPermissionDenied: Bool { authorizationStatus == .denied || authorizationStatus == .restricted }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    /// Calculate distance in kilometers from user to a coordinate
    func distanceToUser(latitude: Double, longitude: Double) -> Double? {
        guard let userLocation else { return nil }
        let eventLocation = CLLocation(latitude: latitude, longitude: longitude)
        return userLocation.distance(from: eventLocation) / 1000.0 // meters to km
    }

    /// Geocode a location string into coordinates
    static func geocode(_ address: String) async -> (latitude: Double, longitude: Double)? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            if let coordinate = placemarks.first?.location?.coordinate {
                return (coordinate.latitude, coordinate.longitude)
            }
        } catch {
            // Geocoding failed — not critical
        }
        return nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location failed — keep userLocation as nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
