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

enum LocationRefreshError: LocalizedError, Sendable, Equatable {
    case permissionDenied
    case restricted
    case unavailable
    case timedOut
    case cancelled
    case busy
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied, .restricted:
            return "没有定位权限，地址、经纬度和海拔水印将不可用。"
        case .unavailable:
            return "当前位置暂时不可用。"
        case .timedOut:
            return "定位刷新超时，将使用明确的不可用位置状态。"
        case .cancelled:
            return "定位刷新已取消。"
        case .busy:
            return "定位正在刷新，请等待当前刷新完成。"
        case let .failed(message):
            return "定位失败：\(message)"
        }
    }
}

enum LocationRefreshResult: Sendable, Equatable {
    case success(LocationSnapshot)
    case failure(LocationRefreshError)
}

private struct LocationValue: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let timestamp: Date

    nonisolated init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        timestamp = location.timestamp
    }

    nonisolated var isUsable: Bool {
        CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) &&
        horizontalAccuracy > 0 &&
        timestamp != Date.distantPast
    }

    nonisolated var coordinateKey: String {
        "\(latitude.workStampCoordinateString),\(longitude.workStampCoordinateString)"
    }

    nonisolated var location: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }

    nonisolated func distance(from other: LocationValue) -> CLLocationDistance {
        location.distance(from: other.location)
    }
}

private struct MapItemValue: Sendable, Equatable {
    let name: String?
    let shortAddress: String?
    let fullAddress: String?
    let singleLineAddress: String?
    let hasPOICategory: Bool
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct MapKitResolution: Sendable {
    let address: String?
    let shouldSearchNearby: Bool
}

private struct NearbyPOIResolution: Sendable {
    let enrichedAddress: String?
    let didFindPOI: Bool
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var snapshot = LocationSnapshot.empty
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    private var nearbyPOISearch: MKLocalSearch?
    private var nearbySearchID: UInt64?
    private var lastGeocodedLocation: LocationValue?
    private var lastResolvedAreaLocation: LocationValue?
    private var lastResolvedAreaAddress: String?
    private var bestLocation: LocationValue?
    private var activeGeocodeID: UInt64?
    private var isGeocoding = false
    private var isActive = false
    private var requestGeneration = RequestGeneration()
    private var refreshGeneration = RequestGeneration()
    private var activeRefreshID: UInt64?
    private var refreshStartedAt: Date?
    private var refreshContinuation: CheckedContinuation<LocationRefreshResult, Never>?
    private var refreshTimeoutTask: Task<Void, Never>?
    private let poiSearchMaximumRadius: CLLocationDistance = 1500

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
    }

    func start() {
        isActive = true
        authorizationStatus = locationManager.authorizationStatus
        handleAuthorizationChange(authorizationStatus)
    }

    func stop() {
        isActive = false
        invalidateLocationRequests()
        locationManager.stopUpdatingLocation()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        handleAuthorizationChange(authorizationStatus)
    }

    func refreshOneShot(timeout: Duration = .seconds(2)) async -> LocationRefreshResult {
        await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { (continuation: CheckedContinuation<LocationRefreshResult, Never>) in
                beginOneShotRefresh(continuation: continuation, timeout: timeout)
            }
        }, onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelOneShotRefresh()
            }
        })
    }

    private func beginOneShotRefresh(
        continuation: CheckedContinuation<LocationRefreshResult, Never>,
        timeout: Duration
    ) {
        guard !Task.isCancelled else {
            continuation.resume(returning: .failure(.cancelled))
            return
        }

        guard isActive else {
            continuation.resume(returning: .failure(.cancelled))
            return
        }

        guard activeRefreshID == nil else {
            continuation.resume(returning: .failure(.busy))
            return
        }

        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied:
            errorMessage = LocationRefreshError.permissionDenied.errorDescription
            continuation.resume(returning: .failure(.permissionDenied))
            return
        case .restricted:
            errorMessage = LocationRefreshError.restricted.errorDescription
            continuation.resume(returning: .failure(.restricted))
            return
        case .notDetermined:
            break
        @unknown default:
            continuation.resume(returning: .failure(.unavailable))
            return
        }

        let requestID = refreshGeneration.next()
        activeRefreshID = requestID
        refreshStartedAt = Date()
        refreshContinuation = continuation
        isRefreshing = true

        refreshTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }

            self?.finishOneShotRefresh(id: requestID, result: .failure(.timedOut))
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            finishOneShotRefresh(id: requestID, result: .failure(.unavailable))
        }
    }

    private func cancelOneShotRefresh() {
        guard let requestID = activeRefreshID else {
            return
        }

        invalidateGeocodeRequests()
        finishOneShotRefresh(id: requestID, result: .failure(.cancelled))
    }

    private func finishOneShotRefresh(
        id: UInt64,
        result: LocationRefreshResult
    ) {
        guard activeRefreshID == id, refreshGeneration.accepts(id) else {
            return
        }

        activeRefreshID = nil
        refreshStartedAt = nil
        isRefreshing = false
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil

        let continuation = refreshContinuation
        refreshContinuation = nil
        continuation?.resume(returning: result)
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status

        if let requestID = activeRefreshID {
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            case .denied:
                errorMessage = LocationRefreshError.permissionDenied.errorDescription
                finishOneShotRefresh(id: requestID, result: .failure(.permissionDenied))
            case .restricted:
                errorMessage = LocationRefreshError.restricted.errorDescription
                finishOneShotRefresh(id: requestID, result: .failure(.restricted))
            case .notDetermined:
                break
            @unknown default:
                finishOneShotRefresh(id: requestID, result: .failure(.unavailable))
            }
        }

        guard isActive else {
            return
        }

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            errorMessage = LocationRefreshError.permissionDenied.errorDescription
            locationManager.stopUpdatingLocation()
        }
    }

    private func invalidateLocationRequests() {
        invalidateGeocodeRequests()

        if let requestID = activeRefreshID {
            finishOneShotRefresh(id: requestID, result: .failure(.cancelled))
        } else {
            isRefreshing = false
        }
    }

    private func invalidateGeocodeRequests() {
        requestGeneration.invalidate()
        activeGeocodeID = nil
        isGeocoding = false
        reverseGeocodingRequest?.cancel()
        reverseGeocodingRequest = nil
        nearbyPOISearch?.cancel()
        nearbyPOISearch = nil
        nearbySearchID = nil
        geocoder.cancelGeocode()
    }

    private func nextRequestIdentifier() -> UInt64 {
        requestGeneration.next()
    }

    private func reverseGeocodeIfNeeded(for value: LocationValue) {
        guard isActive,
              value.horizontalAccuracy > 0,
              value.horizontalAccuracy <= 180,
              snapshotMatches(value) else {
            return
        }

        if let lastGeocodedLocation,
           value.distance(from: lastGeocodedLocation) < 20,
           snapshot.address != nil {
            return
        }

        let requestID = nextRequestIdentifier()
        activeGeocodeID = requestID
        isGeocoding = true
        let fallbackAddress = nearbyAreaFallback(for: value)

        geocoder.cancelGeocode()
        reverseGeocodingRequest?.cancel()
        nearbyPOISearch?.cancel()
        nearbyPOISearch = nil
        nearbySearchID = nil

        geocoder.reverseGeocodeLocation(value.location, preferredLocale: Locale(identifier: "zh-Hans-CN")) { [weak self] placemarks, error in
            let baseAddress = Self.formattedAddress(from: placemarks?.first)
            let message = error.flatMap(Self.userFacingGeocodeMessage(for:))

            Task { @MainActor [weak self] in
                self?.handleCoreGeocodeResult(
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    baseAddress: baseAddress,
                    errorMessage: message
                )
            }
        }
    }

    private func handleCoreGeocodeResult(
        requestID: UInt64,
        value: LocationValue,
        fallbackAddress: String?,
        baseAddress: String,
        errorMessage: String?
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        if let errorMessage {
            self.errorMessage = errorMessage
        }

        lastGeocodedLocation = value
        let resolvedAddress = baseAddress.isEmpty ? fallbackAddress : baseAddress
        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = resolvedAddress
        }

        updateAddress(resolvedAddress, for: value)
        enrichAddressWithMapKit(for: value, fallbackAddress: resolvedAddress, requestID: requestID)
    }

    private func enrichAddressWithMapKit(
        for value: LocationValue,
        fallbackAddress: String?,
        requestID: UInt64
    ) {
        guard let request = MKReverseGeocodingRequest(location: value.location) else {
            finishGeocoding(requestID: requestID, value: value, resolvedAddress: fallbackAddress)
            return
        }

        request.preferredLocale = Locale(identifier: "zh-Hans-CN")
        reverseGeocodingRequest = request

        request.getMapItems { [weak self] mapItems, error in
            let values = (mapItems ?? []).map(Self.mapItemValue(from:))
            let resolution = Self.resolveMapKitItems(values, anchor: value)
            let message = error.flatMap(Self.userFacingGeocodeMessage(for:))

            Task { @MainActor [weak self] in
                self?.handleMapKitResult(
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    resolution: resolution,
                    errorMessage: message
                )
            }
        }
    }

    private func handleMapKitResult(
        requestID: UInt64,
        value: LocationValue,
        fallbackAddress: String?,
        resolution: MapKitResolution,
        errorMessage: String?
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        reverseGeocodingRequest = nil
        if let errorMessage {
            self.errorMessage = errorMessage
        }

        let resolvedAddress = Self.preferredResolvedAddress(resolution.address, fallbackAddress: fallbackAddress)
        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = resolvedAddress
        }
        updateAddress(resolvedAddress, for: value)

        if resolution.shouldSearchNearby {
            searchNearbyPOI(for: value, fallbackAddress: resolvedAddress ?? fallbackAddress, requestID: requestID)
        } else {
            finishGeocoding(requestID: requestID, value: value, resolvedAddress: resolvedAddress ?? fallbackAddress)
        }
    }

    private func searchNearbyPOI(
        for value: LocationValue,
        fallbackAddress: String?,
        requestID: UInt64,
        radius: CLLocationDistance? = nil
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        let radius = radius ?? min(max(value.horizontalAccuracy * 4, 180), 600)
        let request = MKLocalPointsOfInterestRequest(center: value.location.coordinate, radius: radius)
        let search = MKLocalSearch(request: request)
        let searchID = nextRequestIdentifier()
        nearbyPOISearch = search
        nearbySearchID = searchID

        search.start { [weak self] response, error in
            let values = (response?.mapItems ?? []).map(Self.mapItemValue(from:))
            let resolution = Self.resolveNearbyPOI(values, anchor: value, fallbackAddress: fallbackAddress)
            let didFail = error != nil

            Task { @MainActor [weak self] in
                self?.handleNearbyPOIResult(
                    searchID: searchID,
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    currentRadius: radius,
                    resolution: resolution,
                    didFail: didFail
                )
            }
        }
    }

    private func handleNearbyPOIResult(
        searchID: UInt64,
        requestID: UInt64,
        value: LocationValue,
        fallbackAddress: String?,
        currentRadius: CLLocationDistance,
        resolution: NearbyPOIResolution,
        didFail: Bool
    ) {
        guard nearbySearchID == searchID,
              isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        nearbySearchID = nil
        nearbyPOISearch = nil

        if let enrichedAddress = resolution.enrichedAddress, !enrichedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = enrichedAddress
            updateAddress(enrichedAddress, for: value)
            finishGeocoding(requestID: requestID, value: value, resolvedAddress: enrichedAddress)
            return
        }

        let expandedRadius = min(max(currentRadius * 2, 900), poiSearchMaximumRadius)
        if !didFail && !resolution.didFindPOI && expandedRadius > currentRadius {
            searchNearbyPOI(
                for: value,
                fallbackAddress: fallbackAddress,
                requestID: requestID,
                radius: expandedRadius
            )
            return
        }

        finishGeocoding(requestID: requestID, value: value, resolvedAddress: fallbackAddress)
    }

    private func finishGeocoding(
        requestID: UInt64,
        value: LocationValue,
        resolvedAddress: String?
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = resolvedAddress
        }
        isGeocoding = false
        activeGeocodeID = nil
        reverseGeocodingRequest = nil
        nearbyPOISearch = nil
        nearbySearchID = nil
    }

    private func isCurrentGeocode(requestID: UInt64, value: LocationValue) -> Bool {
        isActive && activeGeocodeID == requestID && snapshotMatches(value)
    }

    private func snapshotMatches(_ value: LocationValue) -> Bool {
        guard let latitude = snapshot.latitude, let longitude = snapshot.longitude else {
            return false
        }

        let current = CLLocation(latitude: latitude, longitude: longitude)
        return current.distance(from: value.location) < 20
    }

    private func updateAddress(_ address: String?, for value: LocationValue) {
        guard snapshotMatches(value) else {
            return
        }

        let trimmedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot = LocationSnapshot(
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            altitude: snapshot.altitude,
            horizontalAccuracy: snapshot.horizontalAccuracy,
            verticalAccuracy: snapshot.verticalAccuracy,
            timestamp: snapshot.timestamp,
            address: trimmedAddress?.isEmpty == false ? trimmedAddress : nil
        )
    }

    private func updateSnapshot(with value: LocationValue) {
        let keepsAddress = snapshotMatches(value)
        snapshot = LocationSnapshot(
            latitude: value.latitude,
            longitude: value.longitude,
            altitude: value.verticalAccuracy >= 0 ? value.altitude : nil,
            horizontalAccuracy: value.horizontalAccuracy > 0 ? value.horizontalAccuracy : nil,
            verticalAccuracy: value.verticalAccuracy >= 0 ? value.verticalAccuracy : nil,
            timestamp: value.timestamp,
            address: keepsAddress ? snapshot.address : nil
        )
        errorMessage = nil
    }

    private func nearbyAreaFallback(for value: LocationValue) -> String? {
        guard let lastResolvedAreaLocation,
              let lastResolvedAreaAddress,
              value.distance(from: lastResolvedAreaLocation) <= 500 else {
            return nil
        }

        return lastResolvedAreaAddress
    }

    private func shouldPromote(_ newLocation: LocationValue, over currentLocation: LocationValue?) -> Bool {
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

    private func handleLocationValues(_ values: [LocationValue]) {
        guard isActive else {
            return
        }

        let candidates = values
            .filter(\.isUsable)
            .sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }

        guard let candidate = candidates.first else {
            return
        }

        let promoted = shouldPromote(candidate, over: bestLocation)
        if promoted {
            bestLocation = candidate
            updateSnapshot(with: candidate)
            reverseGeocodeIfNeeded(for: candidate)
        }

        if let refreshID = activeRefreshID,
           let refreshStartedAt,
           candidate.timestamp >= refreshStartedAt {
            if !promoted {
                updateSnapshot(with: candidate)
            }
            finishOneShotRefresh(id: refreshID, result: .success(snapshot))
        }
    }

    private func handleLocationFailure(message: String?, isTransient: Bool) {
        guard isActive else {
            return
        }

        if let refreshID = activeRefreshID, !isTransient {
            let failure: LocationRefreshError = message.map(LocationRefreshError.failed) ?? .unavailable
            finishOneShotRefresh(id: refreshID, result: .failure(failure))
        }

        guard let message else {
            return
        }

        errorMessage = message
    }

    private nonisolated static func mapItemValue(from item: MKMapItem) -> MapItemValue {
        MapItemValue(
            name: item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
            shortAddress: item.address?.shortAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
            fullAddress: item.address?.fullAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            singleLineAddress: item.addressRepresentations?
                .fullAddress(includingRegion: false, singleLine: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            hasPOICategory: item.pointOfInterestCategory != nil,
            latitude: item.location.coordinate.latitude,
            longitude: item.location.coordinate.longitude
        )
    }

    private nonisolated static func formattedAddress(from placemark: CLPlacemark?) -> String {
        guard let placemark else {
            return ""
        }

        let primaryName = [placemark.areasOfInterest?.first, placemark.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let areaParts = [placemark.administrativeArea, placemark.locality, placemark.subLocality]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let roadParts = [placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let address = (areaParts + roadParts).joined()

        guard let primaryName, !primaryName.isEmpty else {
            return address
        }
        return composePreferredAddress(primaryName: primaryName, detailAddress: address)
    }

    private nonisolated static func formattedAddress(from item: MapItemValue) -> String {
        guard let primaryName = preferredPOIName(from: item) else {
            return ""
        }

        let preferredAddress = [item.singleLineAddress, item.fullAddress, item.shortAddress]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        return composePreferredAddress(primaryName: primaryName, detailAddress: preferredAddress)
    }

    private nonisolated static func preferredPOIName(from item: MapItemValue) -> String? {
        guard let rawName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty else {
            return nil
        }

        let addressCandidates = [item.shortAddress, item.fullAddress, item.singleLineAddress]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if item.hasPOICategory {
            return rawName
        }

        if addressCandidates.contains(where: { $0 == rawName || $0.contains(rawName) || rawName.contains($0) }) {
            return nil
        }

        return looksLikePointOfInterestName(rawName) ? rawName : nil
    }

    private nonisolated static func resolveMapKitItems(
        _ items: [MapItemValue],
        anchor: LocationValue
    ) -> MapKitResolution {
        let best = bestMapItem(from: items, anchor: anchor)
        let address = best.flatMap(formattedAddress(from:))
        return MapKitResolution(
            address: address,
            shouldSearchNearby: shouldSearchNearbyPOI(for: best, resolvedAddress: address)
        )
    }

    private nonisolated static func resolveNearbyPOI(
        _ items: [MapItemValue],
        anchor: LocationValue,
        fallbackAddress: String?
    ) -> NearbyPOIResolution {
        guard let item = bestMapItem(from: items, anchor: anchor),
              let poiName = preferredPOIName(from: item) else {
            return NearbyPOIResolution(enrichedAddress: nil, didFindPOI: false)
        }

        let poiAddress = [item.singleLineAddress, item.fullAddress, item.shortAddress]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? ""
        let enriched = composeEnrichedAddress(
            poiName: poiName,
            fallbackAddress: fallbackAddress,
            poiAddress: poiAddress
        )
        return NearbyPOIResolution(
            enrichedAddress: enriched.isEmpty ? nil : enriched,
            didFindPOI: true
        )
    }

    private nonisolated static func preferredResolvedAddress(_ mapKitAddress: String?, fallbackAddress: String?) -> String? {
        let mapKit = mapKitAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let mapKit, !mapKit.isEmpty else { return fallback }
        guard let fallback, !fallback.isEmpty else { return mapKit }

        let mapKitIsPOI = looksLikePointOfInterestCandidate(mapKit)
        let fallbackIsPOI = looksLikePointOfInterestCandidate(fallback)
        if mapKitIsPOI && !fallbackIsPOI { return mapKit }
        if mapKitIsPOI == fallbackIsPOI && mapKit.count > fallback.count && !looksLikeStreetAddress(mapKit) {
            return mapKit
        }
        return fallback
    }

    private nonisolated static func shouldSearchNearbyPOI(for item: MapItemValue?, resolvedAddress: String?) -> Bool {
        guard let resolvedAddress, !resolvedAddress.isEmpty else { return true }
        if item.flatMap(preferredPOIName(from:)) != nil { return false }
        if resolvedAddress.hasSuffix("附近") { return true }
        return looksLikeStreetAddress(resolvedAddress)
    }

    private nonisolated static func bestMapItem(from items: [MapItemValue], anchor: LocationValue) -> MapItemValue? {
        items
            .compactMap { item -> (item: MapItemValue, score: Int)? in
                guard let poiName = preferredPOIName(from: item) else { return nil }
                return (item, scoreForMapItem(item, poiName: poiName, anchor: anchor))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return distance(from: lhs.item, to: anchor) < distance(from: rhs.item, to: anchor)
                }
                return lhs.score > rhs.score
            }
            .first?
            .item
    }

    private nonisolated static func scoreForMapItem(_ item: MapItemValue, poiName: String, anchor: LocationValue) -> Int {
        let distance = distance(from: item, to: anchor)
        var score = 0
        if item.hasPOICategory { score += 120 }
        score += looksLikeStrongPointOfInterestName(poiName) ? 55 : 25
        if distance <= 40 { score += 35 }
        else if distance <= 100 { score += 28 }
        else if distance <= 220 { score += 20 }
        else if distance <= 450 { score += 10 }
        if let address = item.shortAddress, looksLikeStreetAddress(address) { score -= 8 }
        return score
    }

    private nonisolated static func distance(from item: MapItemValue, to anchor: LocationValue) -> CLLocationDistance {
        CLLocation(latitude: item.latitude, longitude: item.longitude).distance(from: anchor.location)
    }

    private nonisolated static func composeEnrichedAddress(
        poiName: String,
        fallbackAddress: String?,
        poiAddress: String
    ) -> String {
        let fallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = poiAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallback, !fallback.isEmpty {
            return composePreferredAddress(primaryName: poiName, detailAddress: fallback)
        }
        if !detail.isEmpty {
            return composePreferredAddress(primaryName: poiName, detailAddress: detail)
        }
        return poiName
    }

    private nonisolated static func composePreferredAddress(primaryName: String, detailAddress: String?) -> String {
        let primary = primaryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = detailAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !primary.isEmpty else { return detail }
        guard !detail.isEmpty else { return primary }
        if detail == primary { return primary }
        if let range = detail.range(of: primary) {
            let deduplicated = detail.replacingCharacters(in: range, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "·,，:： ").union(.whitespacesAndNewlines))
            return deduplicated.isEmpty ? primary : "\(primary)·\(deduplicated)"
        }
        if primary.contains(detail) { return primary }
        return "\(primary)·\(detail)"
    }

    private nonisolated static func looksLikePointOfInterestCandidate(_ value: String) -> Bool {
        !value.hasSuffix("附近") && (value.contains("·") || looksLikePointOfInterestName(value))
    }

    private nonisolated static func looksLikePointOfInterestName(_ value: String) -> Bool {
        ["园区", "园", "科技园", "产业园", "创意园", "广场", "中心", "商场", "商城", "大厦", "写字楼", "公园", "地铁站", "车站", "机场", "酒店", "医院", "学校", "大学", "城"]
            .contains { value.contains($0) } || !looksLikeStreetAddress(value)
    }

    private nonisolated static func looksLikeStrongPointOfInterestName(_ value: String) -> Bool {
        ["产业园", "科技园", "创意园", "工业园", "软件园", "广场", "商场", "商城", "中心", "大厦", "写字楼", "地铁站", "园区", "公司", "园", "城"]
            .contains { value.contains($0) }
    }

    private nonisolated static func looksLikeStreetAddress(_ value: String) -> Bool {
        let markers = ["路", "街", "道", "巷", "弄", "号", "室", "栋", "楼"]
        let hasDigits = value.rangeOfCharacter(from: .decimalDigits) != nil
        return hasDigits && markers.contains { value.contains($0) }
    }

    private nonisolated static func userFacingGeocodeMessage(for error: Error) -> String? {
        if let clError = error as? CLError {
            switch clError.code {
            case .geocodeCanceled, .geocodeFoundNoResult, .network, .locationUnknown:
                return nil
            default:
                return "地址解析失败：\(clError.localizedDescription)"
            }
        }
        return nil
    }

    private nonisolated static func userFacingLocationMessage(for error: Error) -> (message: String?, isTransient: Bool) {
        guard let clError = error as? CLError else {
            return ("定位失败：\(error.localizedDescription)", false)
        }

        switch clError.code {
        case .locationUnknown:
            return (nil, true)
        case .denied:
            return ("没有定位权限，地址、经纬度和海拔水印将不可用。", false)
        case .network:
            return ("定位网络不可用，当前位置可能不准确。", false)
        default:
            return ("定位失败：\(clError.localizedDescription)", false)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let rawValue = manager.authorizationStatus.rawValue
        Task { @MainActor [weak self] in
            guard let self,
                  let status = CLAuthorizationStatus(rawValue: rawValue) else {
                return
            }
            handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let values = locations.map(LocationValue.init)
        Task { @MainActor [weak self] in
            self?.handleLocationValues(values)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let result = Self.userFacingLocationMessage(for: error)
        Task { @MainActor [weak self] in
            self?.handleLocationFailure(message: result.message, isTransient: result.isTransient)
        }
    }
}
