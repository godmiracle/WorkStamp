//
//  LocationService.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import Combine
import CoreLocation
import Foundation
import MapKit

final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var snapshot = LocationSnapshot.empty
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    private var lastGeocodedLocation: CLLocation?
    private var lastResolvedAreaLocation: CLLocation?
    private var lastResolvedAreaAddress: String?
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

        guard location.horizontalAccuracy > 0, location.horizontalAccuracy <= 180 else {
            return
        }

        if let lastGeocodedLocation, location.distance(from: lastGeocodedLocation) < 20, snapshot.address != nil {
            return
        }

        isGeocoding = true
        reverseGeocodingRequest?.cancel()
        guard let request = MKReverseGeocodingRequest(location: location) else {
            isGeocoding = false
            applyNearbyAreaFallback(for: location)
            return
        }
        request.preferredLocale = Locale(identifier: "zh-Hans-CN")
        reverseGeocodingRequest = request

        request.getMapItems(completionHandler: { mapItems, error in
            defer { self.isGeocoding = false }
            defer { self.reverseGeocodingRequest = nil }

            if let error {
                if let message = self.userFacingGeocodeMessage(for: error) {
                    DispatchQueue.main.async {
                        self.errorMessage = message
                    }
                }

                self.applyNearbyAreaFallback(for: location)
                return
            }

            self.lastGeocodedLocation = location
            let mapItem = mapItems?.first
            let address = self.formattedAddress(from: mapItem)
            let coarseAddress = self.coarseAreaAddress(from: mapItem)
            let resolvedAddress = [address, coarseAddress].first { !$0.isEmpty }

            if !coarseAddress.isEmpty {
                self.lastResolvedAreaLocation = location
                self.lastResolvedAreaAddress = coarseAddress
            } else if let resolvedAddress, !resolvedAddress.isEmpty {
                self.lastResolvedAreaLocation = location
                self.lastResolvedAreaAddress = resolvedAddress
            }

            DispatchQueue.main.async {
                self.snapshot = LocationSnapshot(
                    latitude: self.snapshot.latitude,
                    longitude: self.snapshot.longitude,
                    altitude: self.snapshot.altitude,
                    horizontalAccuracy: self.snapshot.horizontalAccuracy,
                    timestamp: self.snapshot.timestamp,
                    address: resolvedAddress
                )
            }
        })
    }

    private func formattedAddress(from mapItem: MKMapItem?) -> String {
        guard let mapItem else {
            return ""
        }

        let primaryName = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortAddress = mapItem.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullAddress = mapItem.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLineAddress = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let preferredAddress = [shortAddress, singleLineAddress, fullAddress]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        if let preferredAddress, let primaryName, !primaryName.isEmpty, !preferredAddress.contains(primaryName) {
            return "\(preferredAddress)·\(primaryName)"
        }

        if let preferredAddress, !preferredAddress.isEmpty {
            return preferredAddress
        }

        return primaryName ?? ""
    }

    private func coarseAreaAddress(from mapItem: MKMapItem?) -> String {
        guard let mapItem else {
            return ""
        }

        let coarseArea = [
            mapItem.addressRepresentations?.cityWithContext(.short),
            mapItem.addressRepresentations?.cityName,
            mapItem.addressRepresentations?.regionName,
            mapItem.address?.shortAddress
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        guard let coarseArea, !coarseArea.isEmpty else {
            return ""
        }

        if coarseArea.hasSuffix("附近") {
            return coarseArea
        }

        return coarseArea + "附近"
    }

    private func applyNearbyAreaFallback(for location: CLLocation) {
        guard let fallbackAddress = nearbyAreaFallback(for: location) else {
            return
        }

        DispatchQueue.main.async {
            self.snapshot = LocationSnapshot(
                latitude: self.snapshot.latitude,
                longitude: self.snapshot.longitude,
                altitude: self.snapshot.altitude,
                horizontalAccuracy: self.snapshot.horizontalAccuracy,
                timestamp: self.snapshot.timestamp,
                address: fallbackAddress
            )
        }
    }

    private func nearbyAreaFallback(for location: CLLocation) -> String? {
        guard let lastResolvedAreaLocation,
              let lastResolvedAreaAddress,
              location.distance(from: lastResolvedAreaLocation) <= 500 else {
            return nil
        }

        return lastResolvedAreaAddress
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
        let fallbackAddress = nearbyAreaFallback(for: location)

        DispatchQueue.main.async {
            self.snapshot = LocationSnapshot(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                horizontalAccuracy: location.horizontalAccuracy,
                timestamp: location.timestamp,
                address: fallbackAddress ?? self.snapshot.address
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
        let nsError = error as NSError

        if nsError.code == NSUserCancelledError {
            return nil
        }

        return nil
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
