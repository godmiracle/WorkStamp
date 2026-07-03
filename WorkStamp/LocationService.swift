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
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    private var nearbyPOISearch: MKLocalSearch?
    private var lastGeocodedLocation: CLLocation?
    private var lastResolvedAreaLocation: CLLocation?
    private var lastResolvedAreaAddress: String?
    private var bestLocation: CLLocation?
    private var isGeocoding = false
    private let poiSearchMaximumRadius: CLLocationDistance = 1500

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
            DispatchQueue.main.async {
                self.isRefreshing = true
            }
            locationManager.requestLocation()
        case .notDetermined:
            DispatchQueue.main.async {
                self.isRefreshing = true
            }
            locationManager.requestWhenInUseAuthorization()
        default:
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
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
        geocoder.cancelGeocode()
        reverseGeocodingRequest?.cancel()
        nearbyPOISearch?.cancel()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh-Hans-CN")) { placemarks, error in
            if let error,
               let message = self.userFacingGeocodeMessage(for: error) {
                DispatchQueue.main.async {
                    self.errorMessage = message
                }
            }

            self.lastGeocodedLocation = location

            let baseAddress = self.formattedAddress(from: placemarks?.first)
            let fallbackAddress = baseAddress.isEmpty ? self.nearbyAreaFallback(for: location) : baseAddress

            if let fallbackAddress, !fallbackAddress.isEmpty {
                self.lastResolvedAreaLocation = location
                self.lastResolvedAreaAddress = fallbackAddress
            }

            self.updateAddress(fallbackAddress)
            self.enrichAddressWithMapKit(for: location, fallbackAddress: fallbackAddress)
        }
    }

    private func poiBackedAddress(from mapItem: MKMapItem?) -> String? {
        let address = formattedAddress(from: mapItem)
        return address.isEmpty ? nil : address
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

    private func formattedAddress(from mapItem: MKMapItem?) -> String {
        guard let mapItem else {
            return ""
        }

        let primaryName = preferredPOIName(from: mapItem)
        let shortAddress = mapItem.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullAddress = mapItem.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLineAddress = mapItem.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let preferredAddress = [singleLineAddress, fullAddress, shortAddress]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        guard let primaryName, !primaryName.isEmpty else {
            return ""
        }

        if let preferredAddress, !preferredAddress.contains(primaryName) {
            return "\(primaryName)·\(preferredAddress)"
        }

        return primaryName
    }

    private func enrichAddressWithMapKit(for location: CLLocation, fallbackAddress: String?) {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            finishGeocoding(for: location, resolvedAddress: fallbackAddress)
            return
        }

        request.preferredLocale = Locale(identifier: "zh-Hans-CN")
        reverseGeocodingRequest = request

        request.getMapItems(completionHandler: { mapItems, error in
            defer { self.reverseGeocodingRequest = nil }

            if let error,
               let message = self.userFacingGeocodeMessage(for: error) {
                DispatchQueue.main.async {
                    self.errorMessage = message
                }
            }

            let mapItem = self.bestMapItem(from: mapItems ?? [], anchor: location)
            let mapKitAddress = self.poiBackedAddress(from: mapItem)
            let resolvedAddress = self.preferredResolvedAddress(mapKitAddress, fallbackAddress: fallbackAddress)

            if let resolvedAddress, !resolvedAddress.isEmpty {
                self.lastResolvedAreaLocation = location
                self.lastResolvedAreaAddress = resolvedAddress
            }

            self.updateAddress(resolvedAddress)

            if self.shouldSearchNearbyPOI(for: mapItem, resolvedAddress: resolvedAddress) {
                self.searchNearbyPOI(for: location, fallbackAddress: resolvedAddress ?? fallbackAddress)
            } else {
                self.finishGeocoding(for: location, resolvedAddress: resolvedAddress ?? fallbackAddress)
            }
        })
    }

    private func preferredResolvedAddress(_ mapKitAddress: String?, fallbackAddress: String?) -> String? {
        let trimmedMapKitAddress = mapKitAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedMapKitAddress, !trimmedMapKitAddress.isEmpty else {
            return trimmedFallback
        }

        guard let trimmedFallback, !trimmedFallback.isEmpty else {
            return trimmedMapKitAddress
        }

        let mapKitLooksLikePOI = looksLikePointOfInterestCandidate(trimmedMapKitAddress)
        let fallbackLooksLikePOI = looksLikePointOfInterestCandidate(trimmedFallback)

        if mapKitLooksLikePOI && !fallbackLooksLikePOI {
            return trimmedMapKitAddress
        }

        if mapKitLooksLikePOI == fallbackLooksLikePOI,
           trimmedMapKitAddress.count > trimmedFallback.count,
           !looksLikeStreetAddress(trimmedMapKitAddress) {
            return trimmedMapKitAddress
        }

        return trimmedFallback
    }

    private func looksLikePointOfInterestCandidate(_ value: String) -> Bool {
        if value.hasSuffix("附近") {
            return false
        }

        if value.contains("·") {
            return true
        }

        return looksLikePointOfInterestName(value)
    }

    private func updateAddress(_ address: String?) {
        let trimmedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
            self.snapshot = LocationSnapshot(
                latitude: self.snapshot.latitude,
                longitude: self.snapshot.longitude,
                altitude: self.snapshot.altitude,
                horizontalAccuracy: self.snapshot.horizontalAccuracy,
                timestamp: self.snapshot.timestamp,
                address: trimmedAddress?.isEmpty == false ? trimmedAddress : nil
            )
        }
    }

    private func finishGeocoding(for location: CLLocation, resolvedAddress: String?) {
        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = location
            lastResolvedAreaAddress = resolvedAddress
        }

        isGeocoding = false
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

    private func preferredPOIName(from mapItem: MKMapItem?) -> String? {
        guard let mapItem,
              let rawName = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else {
            return nil
        }

        let addressCandidates = [
            mapItem.address?.shortAddress,
            mapItem.address?.fullAddress,
            mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        let hasPOICategory = mapItem.pointOfInterestCategory != nil

        if hasPOICategory {
            return rawName
        }

        if addressCandidates.contains(where: { $0 == rawName || $0.contains(rawName) || rawName.contains($0) }) {
            return nil
        }

        if looksLikePointOfInterestName(rawName) {
            return rawName
        }

        return nil
    }

    private func looksLikePointOfInterestName(_ value: String) -> Bool {
        let poiMarkers = [
            "园区", "科技园", "产业园", "创意园", "广场", "中心", "商场", "商城",
            "大厦", "写字楼", "公园", "地铁站", "车站", "机场", "酒店", "医院",
            "学校", "大学", "园", "城"
        ]

        if poiMarkers.contains(where: { value.contains($0) }) {
            return true
        }

        return !looksLikeStreetAddress(value)
    }

    private func looksLikeStreetAddress(_ value: String) -> Bool {
        let addressMarkers = ["路", "街", "道", "巷", "弄", "号", "室", "栋", "楼"]
        let hasDigits = value.rangeOfCharacter(from: .decimalDigits) != nil

        if hasDigits && addressMarkers.contains(where: { value.contains($0) }) {
            return true
        }

        return false
    }

    private func shouldSearchNearbyPOI(for mapItem: MKMapItem?, resolvedAddress: String?) -> Bool {
        guard let resolvedAddress, !resolvedAddress.isEmpty else {
            return true
        }

        if preferredPOIName(from: mapItem) != nil {
            return false
        }

        if resolvedAddress.hasSuffix("附近") {
            return true
        }

        return looksLikeStreetAddress(resolvedAddress)
    }

    private func searchNearbyPOI(
        for location: CLLocation,
        fallbackAddress: String?,
        radius: CLLocationDistance? = nil
    ) {
        let radius = radius ?? min(max(location.horizontalAccuracy * 4, 180), 600)
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
        let search = MKLocalSearch(request: request)
        nearbyPOISearch = search

        search.start(completionHandler: { response, error in
            guard self.nearbyPOISearch === search else {
                return
            }
            self.nearbyPOISearch = nil

            guard error == nil, let response else {
                self.finishGeocoding(for: location, resolvedAddress: fallbackAddress)
                return
            }

            let nearbyItem = self.bestMapItem(from: response.mapItems, anchor: location)

            guard let nearbyItem,
                  let poiName = self.preferredPOIName(from: nearbyItem) else {
                let didRetry = self.retryNearbyPOISearchIfNeeded(
                    for: location,
                    fallbackAddress: fallbackAddress,
                    currentRadius: radius
                )
                if !didRetry {
                    self.finishGeocoding(for: location, resolvedAddress: fallbackAddress)
                }
                return
            }

            let enrichedAddress = self.composeEnrichedAddress(
                poiName: poiName,
                fallbackAddress: fallbackAddress,
                poiAddress: self.formattedAddress(from: nearbyItem)
            )

            guard !enrichedAddress.isEmpty else {
                self.finishGeocoding(for: location, resolvedAddress: fallbackAddress)
                return
            }

            DispatchQueue.main.async {
                self.snapshot = LocationSnapshot(
                    latitude: self.snapshot.latitude,
                    longitude: self.snapshot.longitude,
                    altitude: self.snapshot.altitude,
                    horizontalAccuracy: self.snapshot.horizontalAccuracy,
                    timestamp: self.snapshot.timestamp,
                    address: enrichedAddress
                )
            }
            self.finishGeocoding(for: location, resolvedAddress: enrichedAddress)
        })
    }

    private func retryNearbyPOISearchIfNeeded(
        for location: CLLocation,
        fallbackAddress: String?,
        currentRadius: CLLocationDistance
    ) -> Bool {
        let expandedRadius = min(max(currentRadius * 2, 900), poiSearchMaximumRadius)

        guard expandedRadius > currentRadius else {
            return false
        }

        searchNearbyPOI(
            for: location,
            fallbackAddress: fallbackAddress,
            radius: expandedRadius
        )
        return true
    }

    private func composeEnrichedAddress(poiName: String, fallbackAddress: String?, poiAddress: String) -> String {
        let trimmedFallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPOIAddress = poiAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedFallback,
           !trimmedFallback.isEmpty,
           !trimmedFallback.contains(poiName) {
            return "\(poiName)·\(trimmedFallback)"
        }

        if !trimmedPOIAddress.isEmpty, !trimmedPOIAddress.contains(poiName) {
            return "\(poiName)·\(trimmedPOIAddress)"
        }

        return poiName
    }

    private func bestMapItem(from items: [MKMapItem], anchor location: CLLocation) -> MKMapItem? {
        items
            .compactMap { item -> (item: MKMapItem, score: Int)? in
                guard let poiName = preferredPOIName(from: item), !poiName.isEmpty else {
                    return nil
                }

                return (item, scoreForMapItem(item, poiName: poiName, anchor: location))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.item.location.distance(from: location) < rhs.item.location.distance(from: location)
                }

                return lhs.score > rhs.score
            }
            .first?
            .item
    }

    private func scoreForMapItem(_ item: MKMapItem, poiName: String, anchor location: CLLocation) -> Int {
        let distance = item.location.distance(from: location)
        var score = 0

        if item.pointOfInterestCategory != nil {
            score += 120
        }

        if looksLikeStrongPointOfInterestName(poiName) {
            score += 55
        } else {
            score += 25
        }

        if distance <= 40 {
            score += 35
        } else if distance <= 100 {
            score += 28
        } else if distance <= 220 {
            score += 20
        } else if distance <= 450 {
            score += 10
        }

        if let address = item.address?.shortAddress,
           looksLikeStreetAddress(address) {
            score -= 8
        }

        return score
    }

    private func looksLikeStrongPointOfInterestName(_ value: String) -> Bool {
        let strongMarkers = [
            "产业园", "科技园", "创意园", "工业园", "软件园", "广场", "商场", "商城",
            "中心", "大厦", "写字楼", "地铁站", "园区", "公司", "园", "城"
        ]

        return strongMarkers.contains(where: { value.contains($0) })
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
        if let clError = error as? CLError {
            switch clError.code {
            case .geocodeCanceled, .geocodeFoundNoResult, .network, .locationUnknown:
                return nil
            default:
                return "地址解析失败：\(clError.localizedDescription)"
            }
        }

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
            DispatchQueue.main.async {
                self.isRefreshing = false
            }
            return
        }

        if let bestLocation {
            updateSnapshot(with: bestLocation)
        }

        DispatchQueue.main.async {
            self.isRefreshing = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRefreshing = false
        }

        guard let message = userFacingLocationMessage(for: error) else {
            return
        }

        DispatchQueue.main.async {
            self.errorMessage = message
        }
    }
}
