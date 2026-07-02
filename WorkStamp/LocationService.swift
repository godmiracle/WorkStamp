//
//  LocationService.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import Combine
import CoreLocation
import Foundation

final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var snapshot = LocationSnapshot.empty
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?
    private var bestLocation: CLLocation?
    private var isGeocoding = false

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start() {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            errorMessage = "没有定位权限，地址、经纬度和海拔水印将不可用。"
        }
    }

    func refreshOneShot() {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func currentSnapshot() -> LocationSnapshot {
        snapshot
    }

    private func reverseGeocodeIfNeeded(for location: CLLocation) {
        guard !isGeocoding else {
            return
        }

        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 80 else {
            return
        }

        if let lastGeocodedLocation, location.distance(from: lastGeocodedLocation) < 30, snapshot.address != nil {
            return
        }

        isGeocoding = true
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            defer { self.isGeocoding = false }

            if let error {
                if let message = self.userFacingGeocodeMessage(for: error) {
                    DispatchQueue.main.async {
                        self.errorMessage = message
                    }
                }
                return
            }

            self.lastGeocodedLocation = location
            let placemark = placemarks?.first
            let address = self.formattedAddress(from: placemark)

            DispatchQueue.main.async {
                self.snapshot = LocationSnapshot(
                    latitude: self.snapshot.latitude,
                    longitude: self.snapshot.longitude,
                    altitude: self.snapshot.altitude,
                    horizontalAccuracy: self.snapshot.horizontalAccuracy,
                    timestamp: self.snapshot.timestamp,
                    address: address.isEmpty ? nil : address
                )
            }
        }
    }

    private func formattedAddress(from placemark: CLPlacemark?) -> String {
        guard let placemark else {
            return ""
        }

        let primaryParts = [
            placemark.areasOfInterest?.first,
            placemark.name
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let areaParts = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.subLocality
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let roadParts = [
            placemark.thoroughfare,
            placemark.subThoroughfare
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        if let firstPrimary = primaryParts.first {
            let suffix = (areaParts + roadParts)
                .filter { !$0.contains(firstPrimary) }
                .joined()
            return suffix.isEmpty ? firstPrimary : "\(suffix)·\(firstPrimary)"
        }

        return (areaParts + roadParts).joined()
    }

    private func shouldPromote(_ newLocation: CLLocation, over currentLocation: CLLocation?) -> Bool {
        guard newLocation.horizontalAccuracy > 0 else {
            return false
        }

        guard let currentLocation else {
            return true
        }

        let currentAge = Date().timeIntervalSince(currentLocation.timestamp)
        let improvedAccuracy = newLocation.horizontalAccuracy + 10 < currentLocation.horizontalAccuracy
        let staleCurrent = currentAge > 20
        let movedMeaningfully = newLocation.distance(from: currentLocation) > 30
        let similarAccuracy = newLocation.horizontalAccuracy <= currentLocation.horizontalAccuracy + 15

        return improvedAccuracy || staleCurrent || (movedMeaningfully && similarAccuracy)
    }

    private func updateSnapshot(with location: CLLocation) {
        DispatchQueue.main.async {
            self.snapshot = LocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp,
                address: self.snapshot.address
            )
            self.errorMessage = nil
        }
    }

    private func userFacingLocationMessage(for error: Error) -> String? {
        guard let clError = error as? CLError else {
            return "定位失败：\(error.localizedDescription)"
        }

        switch clError.code {
        case .locationUnknown:
            return nil
        case .denied:
            return "没有定位权限，地址、经纬度和海拔水印将不可用。"
        case .network:
            return "定位网络不可用，当前位置可能不准确。"
        default:
            return "定位失败：\(clError.localizedDescription)"
        }
    }

    private func userFacingGeocodeMessage(for error: Error) -> String? {
        guard let clError = error as? CLError else {
            return "地址解析失败：\(error.localizedDescription)"
        }

        switch clError.code {
        case .geocodeCanceled, .geocodeFoundNoResult, .network, .locationUnknown:
            return nil
        default:
            return "地址解析失败：\(clError.localizedDescription)"
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let sortedLocations = locations
            .filter { $0.horizontalAccuracy > 0 }
            .sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }

        guard let candidate = sortedLocations.first else {
            return
        }

        if shouldPromote(candidate, over: bestLocation) {
            bestLocation = candidate
            updateSnapshot(with: candidate)
            reverseGeocodeIfNeeded(for: candidate)
            return
        }

        if let bestLocation {
            updateSnapshot(with: bestLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let message = userFacingLocationMessage(for: error) else {
            return
        }

        DispatchQueue.main.async {
            self.errorMessage = message
        }
    }
}
