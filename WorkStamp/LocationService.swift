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

struct LocationSourceValue: Sendable, Equatable {
    let isSimulatedBySoftware: Bool?
    let isProducedByAccessory: Bool?

    nonisolated init(
        isSimulatedBySoftware: Bool? = nil,
        isProducedByAccessory: Bool? = nil
    ) {
        self.isSimulatedBySoftware = isSimulatedBySoftware
        self.isProducedByAccessory = isProducedByAccessory
    }

    static let unavailable = LocationSourceValue()

    var displayName: String {
        if isSimulatedBySoftware == true && isProducedByAccessory == true {
            return "软件模拟 + 外接定位设备"
        }
        if isSimulatedBySoftware == true {
            return "软件模拟定位"
        }
        if isProducedByAccessory == true {
            return "外接定位设备"
        }
        if isSimulatedBySoftware == false && isProducedByAccessory == false {
            return "系统定位（非模拟/非外接）"
        }
        return "未提供源标记"
    }

    var flagsDescription: String {
        guard let isSimulatedBySoftware, let isProducedByAccessory else {
            return "系统未提供模拟/外接标记"
        }

        return "模拟：\(isSimulatedBySoftware ? "是" : "否") · 外接：\(isProducedByAccessory ? "是" : "否")"
    }
}

enum LocationResolverStatus: String, Sendable, Equatable {
    case notStarted
    case pending
    case returned
    case empty
    case failed

    var displayName: String {
        switch self {
        case .notStarted:
            return "尚未发起"
        case .pending:
            return "等待返回"
        case .returned:
            return "已返回"
        case .empty:
            return "无结果"
        case .failed:
            return "失败"
        }
    }
}

struct LocationQueryCoordinateDiagnostics: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct CoreGeocoderPlacemarkDiagnostics: Sendable, Equatable {
    let name: String?
    let areasOfInterest: [String]
    let administrativeArea: String?
    let locality: String?
    let subLocality: String?
    let thoroughfare: String?
    let subThoroughfare: String?
    let postalCode: String?
    let country: String?
    let isoCountryCode: String?
}

struct CoreGeocoderDiagnostics: Sendable, Equatable {
    let status: LocationResolverStatus
    let coordinate: LocationQueryCoordinateDiagnostics
    let placemarks: [CoreGeocoderPlacemarkDiagnostics]
    let formattedAddress: String?
    let errorDescription: String?
}

struct LocationMapItemDiagnostics: Sendable, Equatable {
    let name: String?
    let shortAddress: String?
    let fullAddress: String?
    let singleLineAddress: String?
    let hasPOICategory: Bool
    let latitude: Double
    let longitude: Double
    let distance: CLLocationDistance
}

struct MapKitReverseGeocodingDiagnostics: Sendable, Equatable {
    let status: LocationResolverStatus
    let coordinate: LocationQueryCoordinateDiagnostics
    let items: [LocationMapItemDiagnostics]
    let errorDescription: String?
}

struct NearbyPOISearchDiagnostics: Sendable, Equatable {
    let status: LocationResolverStatus
    let radius: CLLocationDistance
    let items: [LocationMapItemDiagnostics]
    let errorDescription: String?
}

struct NearbyPOIDiagnostics: Sendable, Equatable {
    let coordinate: LocationQueryCoordinateDiagnostics
    let attempts: [NearbyPOISearchDiagnostics]

    var status: LocationResolverStatus {
        attempts.last?.status ?? .notStarted
    }
}

enum LocationCandidateDecision: String, Sendable, Equatable {
    case promoted
    case retainedExisting
    case noUsableCandidate

    var displayName: String {
        switch self {
        case .promoted:
            return "已采纳本次回调"
        case .retainedExisting:
            return "保留当前快照"
        case .noUsableCandidate:
            return "没有可用回调"
        }
    }
}

struct LocationDiagnostics: Sendable, Equatable {
    let latestCallback: LocationValue?
    let selectedCandidate: LocationValue?
    let decision: LocationCandidateDecision?
    let acceptedLocation: LocationValue?
    let firstCallback: LocationValue?
    let callbackCount: Int
    let coreGeocoderAddress: String?
    let mapKitCandidate: LocationMapCandidateDiagnostics?
    let nearbyPOICandidate: LocationMapCandidateDiagnostics?
    let coreGeocoderRawResult: CoreGeocoderDiagnostics?
    let mapKitRawResult: MapKitReverseGeocodingDiagnostics?
    let nearbyPOIRawResult: NearbyPOIDiagnostics?

    init(
        latestCallback: LocationValue?,
        selectedCandidate: LocationValue?,
        decision: LocationCandidateDecision?,
        acceptedLocation: LocationValue?,
        firstCallback: LocationValue? = nil,
        callbackCount: Int = 0,
        coreGeocoderAddress: String? = nil,
        mapKitCandidate: LocationMapCandidateDiagnostics? = nil,
        nearbyPOICandidate: LocationMapCandidateDiagnostics? = nil,
        coreGeocoderRawResult: CoreGeocoderDiagnostics? = nil,
        mapKitRawResult: MapKitReverseGeocodingDiagnostics? = nil,
        nearbyPOIRawResult: NearbyPOIDiagnostics? = nil
    ) {
        self.latestCallback = latestCallback
        self.selectedCandidate = selectedCandidate
        self.decision = decision
        self.acceptedLocation = acceptedLocation
        self.firstCallback = firstCallback
        self.callbackCount = callbackCount
        self.coreGeocoderAddress = coreGeocoderAddress
        self.mapKitCandidate = mapKitCandidate
        self.nearbyPOICandidate = nearbyPOICandidate
        self.coreGeocoderRawResult = coreGeocoderRawResult
        self.mapKitRawResult = mapKitRawResult
        self.nearbyPOIRawResult = nearbyPOIRawResult
    }

    var firstToLatestDistance: CLLocationDistance? {
        guard let firstCallback, let latestCallback else {
            return nil
        }

        return firstCallback.distance(from: latestCallback)
    }

    static let empty = LocationDiagnostics(
        latestCallback: nil,
        selectedCandidate: nil,
        decision: nil,
        acceptedLocation: nil
    )
}

enum CaptureLocationResolver {
    static func resolve(
        result: LocationRefreshResult,
        cachedSnapshot: LocationSnapshot,
        referenceDate: Date
    ) -> LocationSnapshot {
        switch result {
        case let .success(snapshot):
            guard snapshot.canBeUsedAsCaptureFallback(at: referenceDate) else {
                return cachedSnapshot.canBeUsedAsCaptureFallback(at: referenceDate)
                    ? cachedSnapshot
                    : .empty
            }

            return snapshot.withRecentAddress(from: cachedSnapshot, at: referenceDate)
        case .failure:
            return cachedSnapshot.canBeUsedAsCaptureFallback(at: referenceDate)
                ? cachedSnapshot
                : .empty
        }
    }
}

struct LocationValue: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let timestamp: Date
    let source: LocationSourceValue

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        verticalAccuracy: Double,
        timestamp: Date,
        source: LocationSourceValue = .unavailable
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
        self.source = source
    }

    nonisolated init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
        timestamp = location.timestamp
        source = LocationSourceValue(
            isSimulatedBySoftware: location.sourceInformation?.isSimulatedBySoftware,
            isProducedByAccessory: location.sourceInformation?.isProducedByAccessory
        )
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

enum LocationCandidatePolicy {
    static func isCaptureQualityAcceptable(
        _ candidate: LocationValue,
        at referenceDate: Date
    ) -> Bool {
        guard candidate.isUsable,
              candidate.horizontalAccuracy <= LocationQualityPolicy.captureMaximumHorizontalAccuracy else {
            return false
        }

        let age = referenceDate.timeIntervalSince(candidate.timestamp)
        return age >= 0 && age <= LocationQualityPolicy.captureMaximumAge
    }

    /// Core Location may return a recent cached sample whose source timestamp
    /// predates the call to `requestLocation()`. Receipt time, not that source
    /// timestamp ordering, determines whether a one-shot refresh can finish.
    static func canSatisfyOneShotRefresh(
        _ candidate: LocationValue,
        receivedAt: Date
    ) -> Bool {
        isCaptureQualityAcceptable(candidate, at: receivedAt)
    }

    static func shouldPromote(
        _ newLocation: LocationValue,
        over currentLocation: LocationValue?,
        now: Date,
        isExplicitRefresh: Bool = false
    ) -> Bool {
        guard isCaptureQualityAcceptable(newLocation, at: now) else {
            return false
        }

        guard let currentLocation else {
            return true
        }

        guard newLocation.timestamp >= currentLocation.timestamp else {
            return false
        }

        let distance = newLocation.distance(from: currentLocation)
        let currentAge = max(0, now.timeIntervalSince(currentLocation.timestamp))
        let improvedAccuracy = newLocation.horizontalAccuracy + 10 < currentLocation.horizontalAccuracy
        let staleCurrent = currentAge > 20
        let movedMeaningfully = distance > 30
        let similarAccuracy = newLocation.horizontalAccuracy <= currentLocation.horizontalAccuracy + 15
        let significantRelocation = LocationQualityPolicy.isSignificantRelocation(
            distance: distance,
            currentHorizontalAccuracy: currentLocation.horizontalAccuracy,
            candidateHorizontalAccuracy: newLocation.horizontalAccuracy
        )
        let explicitRefreshRelocation = isExplicitRefresh && distance > max(
            LocationQualityPolicy.explicitRefreshMinimumDistance,
            currentLocation.horizontalAccuracy + 15
        )

        return improvedAccuracy
            || staleCurrent
            || (movedMeaningfully && similarAccuracy)
            || significantRelocation
            || explicitRefreshRelocation
    }
}

struct MapItemValue: Sendable, Equatable {
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

enum LocationPOISelectionTier: Int, Sendable, Equatable {
    case exact
    case regional
}

struct LocationMapCandidateDiagnostics: Sendable, Equatable {
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let distance: CLLocationDistance
    let tier: LocationPOISelectionTier
}

struct LocationPOICandidate: Sendable, Equatable {
    let item: MapItemValue
    let poiName: String
}

struct LocationPOISelection: Sendable, Equatable {
    let candidate: LocationPOICandidate
    let distance: CLLocationDistance
    let tier: LocationPOISelectionTier
}

enum LocationPOISelectionPolicy {
    nonisolated static func isStrongPOIName(_ value: String) -> Bool {
        ["产业园", "科技园", "创意园", "工业园", "软件园", "广场", "商场", "商城", "中心", "大厦", "写字楼", "地铁站", "园区", "公司", "园", "城"]
            .contains { value.contains($0) }
    }

    nonisolated static func tier(
        distance: CLLocationDistance,
        horizontalAccuracy: CLLocationDistance,
        isStrongPOI: Bool
    ) -> LocationPOISelectionTier? {
        if LocationQualityPolicy.acceptsTrustedPOI(
            distance: distance,
            horizontalAccuracy: horizontalAccuracy
        ) {
            return .exact
        }

        guard isStrongPOI,
              distance <= LocationQualityPolicy.regionalPOIMaximumDistance(for: horizontalAccuracy) else {
            return nil
        }
        return .regional
    }

    nonisolated static func rank(
        _ candidates: [LocationPOICandidate],
        anchor: LocationValue
    ) -> LocationPOISelection? {
        candidates
            .compactMap { candidate -> (selection: LocationPOISelection, score: Int)? in
                let candidateDistance = distance(from: candidate.item, to: anchor)
                guard let candidateTier = tier(
                    distance: candidateDistance,
                    horizontalAccuracy: anchor.horizontalAccuracy,
                    isStrongPOI: isStrongPOIName(candidate.poiName)
                ) else {
                    return nil
                }

                return (
                    selection: LocationPOISelection(
                        candidate: candidate,
                        distance: candidateDistance,
                        tier: candidateTier
                    ),
                    score: score(
                        for: candidate,
                        tier: candidateTier,
                        distance: candidateDistance
                    )
                )
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.selection.tier != rhs.selection.tier {
                    return lhs.selection.tier.rawValue < rhs.selection.tier.rawValue
                }
                return lhs.selection.distance < rhs.selection.distance
            }
            .first?
            .selection
    }

    private nonisolated static func score(
        for candidate: LocationPOICandidate,
        tier: LocationPOISelectionTier,
        distance: CLLocationDistance
    ) -> Int {
        var score = tier == .exact ? 20 : 0
        if candidate.item.hasPOICategory {
            score += 120
        }
        score += isStrongPOIName(candidate.poiName) ? 180 : 25

        if distance <= 40 {
            score += 35
        } else if distance <= 100 {
            score += 28
        } else if distance <= 220 {
            score += 20
        } else if distance <= 450 {
            score += 10
        }

        if let address = candidate.item.shortAddress,
           looksLikeStreetAddress(address) {
            score -= 8
        }
        return score
    }

    private nonisolated static func distance(from item: MapItemValue, to anchor: LocationValue) -> CLLocationDistance {
        CLLocation(latitude: item.latitude, longitude: item.longitude).distance(from: anchor.location)
    }

    private nonisolated static func looksLikeStreetAddress(_ value: String) -> Bool {
        let markers = ["路", "街", "道", "巷", "弄", "号", "室", "栋", "楼"]
        let hasDigits = value.rangeOfCharacter(from: .decimalDigits) != nil
        return hasDigits && markers.contains { value.contains($0) }
    }
}

private struct MapKitResolution: Sendable {
    let address: String?
    let addressSource: LocationAddressSource?
    let addressDistance: CLLocationDistance?
    let shouldSearchNearby: Bool
    let candidate: LocationMapCandidateDiagnostics?
}

private struct NearbyPOIResolution: Sendable {
    let enrichedAddress: String?
    let didFindPOI: Bool
    let distance: CLLocationDistance?
    let addressSource: LocationAddressSource?
    let candidate: LocationMapCandidateDiagnostics?
}

@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var snapshot = LocationSnapshot.empty
    @Published private(set) var diagnostics = LocationDiagnostics.empty
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
    private var nearbyPOISearch: MKLocalSearch?
    private var nearbySearchID: UInt64?
    private var mapKitFallbackTask: Task<Void, Never>?
    private var lastGeocodedLocation: LocationValue?
    private var lastResolvedAreaLocation: LocationValue?
    private var lastResolvedAreaAddress: String?
    private var bestLocation: LocationValue?
    // Keep the original Core Location object for reverse geocoding. Rebuilding
    // CLLocation from its scalar fields preserves the visible coordinate but
    // changes the geocoder result on the same device.
    private var bestRawLocation: CLLocation?
    private var activeGeocodeID: UInt64?
    private var isGeocoding = false
    private var isActive = false
    private var requestGeneration = RequestGeneration()
    private var refreshGeneration = RequestGeneration()
    private var activeRefreshID: UInt64?
    private var refreshContinuation: CheckedContinuation<LocationRefreshResult, Never>?
    private var refreshTimeoutTask: Task<Void, Never>?
    private let poiSearchMaximumRadius: CLLocationDistance = 1500
    private var firstCallback: LocationValue?
    private var callbackCount = 0
    private var coreGeocoderAddress: String?
    private var mapKitCandidate: LocationMapCandidateDiagnostics?
    private var nearbyPOICandidate: LocationMapCandidateDiagnostics?
    private var coreGeocoderRawResult: CoreGeocoderDiagnostics?
    private var mapKitRawResult: MapKitReverseGeocodingDiagnostics?
    private var nearbyPOIRawResult: NearbyPOIDiagnostics?

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        let wasInactive = !isActive
        isActive = true
        authorizationStatus = locationManager.authorizationStatus

        if wasInactive {
            locationManager.stopUpdatingLocation()
        }
        handleAuthorizationChange(authorizationStatus)

        guard wasInactive else {
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
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

    func refreshOneShot(timeout: Duration = .seconds(8)) async -> LocationRefreshResult {
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

    func refreshOneShotForCapture(
        locationTimeout: Duration = .seconds(2),
        addressTimeout: TimeInterval = 4
    ) async -> LocationRefreshResult {
        let result = await refreshOneShot(timeout: locationTimeout)
        guard case .success = result else {
            return result
        }

        ensureAddressResolutionForCapture()
        await waitForAddressResolution(timeout: addressTimeout)
        return .success(snapshot)
    }

    private func ensureAddressResolutionForCapture() {
        guard snapshot.address == nil,
              let bestLocation,
              snapshotMatches(bestLocation) else {
            return
        }

        if !isGeocoding {
            reverseGeocodeIfNeeded(for: bestLocation, rawLocation: bestRawLocation)
        }
    }

    private func waitForAddressResolution(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)

        while isGeocoding && Date() < deadline {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
        }
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
            locationManager.startUpdatingLocation()
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
        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = nil
        geocoder.cancelGeocode()
    }

    private func nextRequestIdentifier() -> UInt64 {
        requestGeneration.next()
    }

    private func reverseGeocodeIfNeeded(
        for value: LocationValue,
        rawLocation: CLLocation? = nil,
        force: Bool = false
    ) {
        guard isActive,
              value.horizontalAccuracy > 0,
              value.horizontalAccuracy <= LocationQualityPolicy.captureMaximumHorizontalAccuracy,
              snapshotMatches(value) else {
            return
        }

        if !force,
           let lastGeocodedLocation,
           value.distance(from: lastGeocodedLocation) < 20,
           snapshot.address != nil {
            return
        }

        let requestID = nextRequestIdentifier()
        activeGeocodeID = requestID
        isGeocoding = true
        let queryLocation = rawLocation ?? value.location
        let fallbackAddress = nearbyAreaFallback(for: value)
        let coordinate = LocationQueryCoordinateDiagnostics(
            latitude: value.latitude,
            longitude: value.longitude
        )
        coreGeocoderRawResult = CoreGeocoderDiagnostics(
            status: .pending,
            coordinate: coordinate,
            placemarks: [],
            formattedAddress: nil,
            errorDescription: nil
        )
        mapKitRawResult = MapKitReverseGeocodingDiagnostics(
            status: .pending,
            coordinate: coordinate,
            items: [],
            errorDescription: nil
        )
        nearbyPOIRawResult = NearbyPOIDiagnostics(
            coordinate: coordinate,
            attempts: []
        )
        updateAddressDiagnostics()

        geocoder.cancelGeocode()
        reverseGeocodingRequest?.cancel()
        nearbyPOISearch?.cancel()
        nearbyPOISearch = nil
        nearbySearchID = nil
        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = nil

        geocoder.reverseGeocodeLocation(queryLocation, preferredLocale: Locale(identifier: "zh-Hans-CN")) { [weak self] placemarks, error in
            let baseAddress = Self.formattedAddress(from: placemarks?.first)
            let placemarkValues = (placemarks ?? []).map(Self.placemarkDiagnostics(from:))
            let rawResult = CoreGeocoderDiagnostics(
                status: error == nil
                    ? (placemarkValues.isEmpty ? .empty : .returned)
                    : .failed,
                coordinate: coordinate,
                placemarks: placemarkValues,
                formattedAddress: baseAddress.isEmpty ? nil : baseAddress,
                errorDescription: error?.localizedDescription
            )
            let message = error.flatMap(Self.userFacingGeocodeMessage(for:))

            Task { @MainActor [weak self] in
                self?.handleCoreGeocodeResult(
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    baseAddress: baseAddress,
                    rawResult: rawResult,
                    errorMessage: message,
                    rawLocation: queryLocation
                )
            }
        }
    }

    private func handleCoreGeocodeResult(
        requestID: UInt64,
        value: LocationValue,
        fallbackAddress: String?,
        baseAddress: String,
        rawResult: CoreGeocoderDiagnostics,
        errorMessage: String?,
        rawLocation: CLLocation
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        let placemarkSummary = rawResult.placemarks.map { placemark in
            let areas = placemark.areasOfInterest.joined(separator: ",")
            let road = [placemark.thoroughfare, placemark.subThoroughfare]
                .compactMap { $0 }
                .joined()
            return "name=\(placemark.name ?? "-") areas=\(areas.isEmpty ? "-" : areas) area=\(placemark.subLocality ?? "-") road=\(road.isEmpty ? "-" : road)"
        }.joined(separator: " | ")
        debugLog(
            "core id=\(requestID) status=\(rawResult.status.rawValue) error=\(rawResult.errorDescription ?? "-") base=\(baseAddress.isEmpty ? "-" : baseAddress) fallback=\(fallbackAddress ?? "-") placemarks=[\(placemarkSummary.isEmpty ? "-" : placemarkSummary)]"
        )

        if let errorMessage {
            self.errorMessage = errorMessage
        }

        lastGeocodedLocation = value
        let resolvedAddress = baseAddress.isEmpty ? fallbackAddress : baseAddress
        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = resolvedAddress
        }

        coreGeocoderAddress = baseAddress.isEmpty ? nil : baseAddress
        coreGeocoderRawResult = rawResult
        updateAddressDiagnostics()
        let source: LocationAddressSource? = baseAddress.isEmpty
            ? (fallbackAddress == nil ? nil : .areaFallback)
            : .coreGeocoder
        updateAddress(resolvedAddress, source: source, distance: nil, for: value)
        enrichAddressWithMapKit(
            for: value,
            rawLocation: rawLocation,
            fallbackAddress: resolvedAddress,
            requestID: requestID
        )
    }

    private func enrichAddressWithMapKit(
        for value: LocationValue,
        rawLocation: CLLocation,
        fallbackAddress: String?,
        requestID: UInt64
    ) {
        guard let request = MKReverseGeocodingRequest(location: rawLocation) else {
            mapKitRawResult = MapKitReverseGeocodingDiagnostics(
                status: .failed,
                coordinate: LocationQueryCoordinateDiagnostics(
                    latitude: value.latitude,
                    longitude: value.longitude
                ),
                items: [],
                errorDescription: "无法创建 MapKit 反查请求"
            )
            updateAddressDiagnostics()
            finishGeocoding(requestID: requestID, value: value, resolvedAddress: fallbackAddress)
            return
        }

        request.preferredLocale = Locale(identifier: "zh-Hans-CN")
        reverseGeocodingRequest = request

        request.getMapItems { [weak self] mapItems, error in
            let values = (mapItems ?? []).map(Self.mapItemValue(from:))
            let resolution = Self.resolveMapKitItems(values, anchor: value)
            let rawResult = MapKitReverseGeocodingDiagnostics(
                status: error == nil
                    ? (values.isEmpty ? .empty : .returned)
                    : .failed,
                coordinate: LocationQueryCoordinateDiagnostics(
                    latitude: value.latitude,
                    longitude: value.longitude
                ),
                items: values.map { Self.mapItemDiagnostics(from: $0, anchor: value) },
                errorDescription: error?.localizedDescription
            )
            let message = error.flatMap(Self.userFacingGeocodeMessage(for:))

            Task { @MainActor [weak self] in
                self?.handleMapKitResult(
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    resolution: resolution,
                    rawResult: rawResult,
                    errorMessage: message
                )
            }
        }

        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            guard let self,
                  self.isCurrentGeocode(requestID: requestID, value: value) else {
                return
            }

            self.mapKitFallbackTask = nil
            self.mapKitRawResult = MapKitReverseGeocodingDiagnostics(
                status: .failed,
                coordinate: LocationQueryCoordinateDiagnostics(
                    latitude: value.latitude,
                    longitude: value.longitude
                ),
                items: [],
                errorDescription: "MapKit 反查超时，已转入附近 POI 搜索"
            )
            self.updateAddressDiagnostics()
            self.searchNearbyPOI(
                for: value,
                fallbackAddress: fallbackAddress,
                requestID: requestID
            )
        }
    }

    private func handleMapKitResult(
        requestID: UInt64,
        value: LocationValue,
        fallbackAddress: String?,
        resolution: MapKitResolution,
        rawResult: MapKitReverseGeocodingDiagnostics,
        errorMessage: String?
    ) {
        guard isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        debugLog(
            "mapkit id=\(requestID) status=\(rawResult.status.rawValue) error=\(rawResult.errorDescription ?? "-") items=\(rawResult.items.count) [\(debugMapItems(rawResult.items))] selected=\(debugCandidate(resolution.candidate)) address=\(resolution.address ?? "-") source=\(resolution.addressSource?.rawValue ?? "-") distance=\(resolution.addressDistance.map { String($0) } ?? "-") nearby=\(resolution.shouldSearchNearby)"
        )

        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = nil
        reverseGeocodingRequest = nil
        mapKitRawResult = rawResult
        if let errorMessage {
            self.errorMessage = errorMessage
        }

        mapKitCandidate = resolution.candidate
        updateAddressDiagnostics()
        let resolvedAddress = Self.preferredResolvedAddress(
            resolution.address,
            fallbackAddress: fallbackAddress,
            addressSource: resolution.addressSource
        )
        if let resolvedAddress, !resolvedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = resolvedAddress
        }
        let usesMapKitAddress = resolution.address != nil && resolution.address == resolvedAddress
        let source: LocationAddressSource? = usesMapKitAddress
            ? resolution.addressSource
            : (fallbackAddress == nil ? nil : (snapshot.addressSource ?? .areaFallback))
        let distance = usesMapKitAddress ? resolution.addressDistance : nil
        updateAddress(
            resolvedAddress,
            source: source,
            distance: distance,
            for: value
        )

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

        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = nil
        nearbyPOISearch?.cancel()
        nearbyPOISearch = nil
        nearbySearchID = nil

        let radius = radius ?? min(max(value.horizontalAccuracy * 4, 180), 600)
        let coordinate = LocationQueryCoordinateDiagnostics(
            latitude: value.latitude,
            longitude: value.longitude
        )
        let pendingAttempt = NearbyPOISearchDiagnostics(
            status: .pending,
            radius: radius,
            items: [],
            errorDescription: nil
        )
        if let nearbyPOIRawResult,
           nearbyPOIRawResult.coordinate == coordinate {
            self.nearbyPOIRawResult = NearbyPOIDiagnostics(
                coordinate: coordinate,
                attempts: nearbyPOIRawResult.attempts + [pendingAttempt]
            )
        } else {
            nearbyPOIRawResult = NearbyPOIDiagnostics(
                coordinate: coordinate,
                attempts: [pendingAttempt]
            )
        }
        updateAddressDiagnostics()

        let request = MKLocalPointsOfInterestRequest(center: value.location.coordinate, radius: radius)
        let search = MKLocalSearch(request: request)
        let searchID = nextRequestIdentifier()
        nearbyPOISearch = search
        nearbySearchID = searchID

        search.start { [weak self] response, error in
            let values = (response?.mapItems ?? []).map(Self.mapItemValue(from:))
            let resolution = Self.resolveNearbyPOI(values, anchor: value, fallbackAddress: fallbackAddress)
            let didFail = error != nil
            let rawResult = NearbyPOISearchDiagnostics(
                status: error == nil
                    ? (values.isEmpty ? .empty : .returned)
                    : .failed,
                radius: radius,
                items: values.map { Self.mapItemDiagnostics(from: $0, anchor: value) },
                errorDescription: error?.localizedDescription
            )

            Task { @MainActor [weak self] in
                self?.handleNearbyPOIResult(
                    searchID: searchID,
                    requestID: requestID,
                    value: value,
                    fallbackAddress: fallbackAddress,
                    currentRadius: radius,
                    resolution: resolution,
                    rawResult: rawResult,
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
        rawResult: NearbyPOISearchDiagnostics,
        didFail: Bool
    ) {
        guard nearbySearchID == searchID,
              isCurrentGeocode(requestID: requestID, value: value) else {
            return
        }

        debugLog(
            "nearby request=\(requestID) search=\(searchID) status=\(rawResult.status.rawValue) radius=\(currentRadius)m error=\(rawResult.errorDescription ?? "-") items=\(rawResult.items.count) [\(debugMapItems(rawResult.items))] selected=\(debugCandidate(resolution.candidate)) enriched=\(resolution.enrichedAddress ?? "-") found=\(resolution.didFindPOI)"
        )

        nearbySearchID = nil
        nearbyPOISearch = nil

        let coordinate = LocationQueryCoordinateDiagnostics(
            latitude: value.latitude,
            longitude: value.longitude
        )
        if let nearbyPOIRawResult,
           nearbyPOIRawResult.coordinate == coordinate,
           !nearbyPOIRawResult.attempts.isEmpty {
            var attempts = nearbyPOIRawResult.attempts
            attempts[attempts.index(before: attempts.endIndex)] = rawResult
            self.nearbyPOIRawResult = NearbyPOIDiagnostics(
                coordinate: coordinate,
                attempts: attempts
            )
        } else {
            nearbyPOIRawResult = NearbyPOIDiagnostics(
                coordinate: coordinate,
                attempts: [rawResult]
            )
        }

        nearbyPOICandidate = resolution.candidate
        updateAddressDiagnostics()
        if let enrichedAddress = resolution.enrichedAddress, !enrichedAddress.isEmpty {
            lastResolvedAreaLocation = value
            lastResolvedAreaAddress = enrichedAddress
            updateAddress(
                enrichedAddress,
                source: resolution.addressSource ?? .nearbyPOI,
                distance: resolution.distance,
                for: value
            )
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
        reverseGeocodingRequest?.cancel()
        reverseGeocodingRequest = nil
        nearbyPOISearch?.cancel()
        nearbyPOISearch = nil
        nearbySearchID = nil
        mapKitFallbackTask?.cancel()
        mapKitFallbackTask = nil
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

    private func updateAddress(
        _ address: String?,
        source: LocationAddressSource?,
        distance: CLLocationDistance?,
        for value: LocationValue
    ) {
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
            address: trimmedAddress?.isEmpty == false ? trimmedAddress : nil,
            addressSource: trimmedAddress?.isEmpty == false ? source : nil,
            addressDistance: trimmedAddress?.isEmpty == false ? distance : nil
        )
        debugLog(
            "address applied value=\(debugLocation(value)) address=\(trimmedAddress ?? "-") source=\(source?.rawValue ?? "-") distance=\(distance.map { String($0) } ?? "-") snapshot=\(debugSnapshot(snapshot))"
        )
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[Location] \(message)")
#else
        _ = message
#endif
    }

    private func debugLocation(_ value: LocationValue) -> String {
        "lat=\(value.latitude),lon=\(value.longitude),hAcc=\(value.horizontalAccuracy),vAcc=\(value.verticalAccuracy),timestamp=\(value.timestamp.timeIntervalSince1970),source=\(value.source.flagsDescription)"
    }

    private func debugSnapshot(_ value: LocationSnapshot) -> String {
        "lat=\(value.latitude.map { String($0) } ?? "-"),lon=\(value.longitude.map { String($0) } ?? "-"),address=\(value.address ?? "-"),source=\(value.addressSource?.rawValue ?? "-"),distance=\(value.addressDistance.map { String($0) } ?? "-")"
    }

    private func debugCandidate(_ value: LocationMapCandidateDiagnostics?) -> String {
        guard let value else {
            return "-"
        }

        return "name=\(value.name),tier=\(value.tier),distance=\(value.distance)m,address=\(value.address ?? "-")"
    }

    private func debugMapItems(_ values: [LocationMapItemDiagnostics]) -> String {
        let summary = values.prefix(20).map { value in
            "name=\(value.name ?? "-"),short=\(value.shortAddress ?? "-"),poi=\(value.hasPOICategory),distance=\(value.distance)m,coord=\(value.latitude),\(value.longitude)"
        }.joined(separator: " | ")
        return summary.isEmpty ? "-" : summary
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
            address: keepsAddress ? snapshot.address : nil,
            addressSource: keepsAddress ? snapshot.addressSource : nil,
            addressDistance: keepsAddress ? snapshot.addressDistance : nil
        )
        errorMessage = nil
    }

    private func nearbyAreaFallback(for value: LocationValue) -> String? {
        guard let lastResolvedAreaLocation,
              let lastResolvedAreaAddress,
              LocationQualityPolicy.acceptsCachedArea(
                  distance: value.distance(from: lastResolvedAreaLocation)
              ) else {
            return nil
        }

        return lastResolvedAreaAddress
    }

    private func updateAddressDiagnostics() {
        diagnostics = LocationDiagnostics(
            latestCallback: diagnostics.latestCallback,
            selectedCandidate: diagnostics.selectedCandidate,
            decision: diagnostics.decision,
            acceptedLocation: diagnostics.acceptedLocation,
            firstCallback: firstCallback,
            callbackCount: callbackCount,
            coreGeocoderAddress: coreGeocoderAddress,
            mapKitCandidate: mapKitCandidate,
            nearbyPOICandidate: nearbyPOICandidate,
            coreGeocoderRawResult: coreGeocoderRawResult,
            mapKitRawResult: mapKitRawResult,
            nearbyPOIRawResult: nearbyPOIRawResult
        )
    }

    private func rawLocation(matching value: LocationValue, in locations: [CLLocation]) -> CLLocation? {
        locations.first { LocationValue($0) == value }
    }

    private func handleLocationValues(
        _ values: [LocationValue],
        rawLocations: [CLLocation]
    ) {
        guard isActive else {
            return
        }

        let callbackSummary = values.map(debugLocation).joined(separator: " | ")
        debugLog(
            "callback count=\(values.count) refresh=\(activeRefreshID.map { String($0) } ?? "-") values=[\(callbackSummary)]"
        )

        if firstCallback == nil {
            firstCallback = values.first
        }
        callbackCount += values.count

        let now = Date()
        let latestCallback = values.max { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        let candidates = values
            .filter(\.isUsable)
            .sorted { lhs, rhs in
                let lhsIsAcceptable = LocationCandidatePolicy.isCaptureQualityAcceptable(lhs, at: now)
                let rhsIsAcceptable = LocationCandidatePolicy.isCaptureQualityAcceptable(rhs, at: now)
                if lhsIsAcceptable != rhsIsAcceptable {
                    return lhsIsAcceptable
                }
                if lhs.horizontalAccuracy != rhs.horizontalAccuracy {
                    return lhs.horizontalAccuracy < rhs.horizontalAccuracy
                }
                return lhs.timestamp > rhs.timestamp
            }

        guard let candidate = candidates.first else {
            diagnostics = LocationDiagnostics(
                latestCallback: latestCallback,
                selectedCandidate: nil,
                decision: .noUsableCandidate,
                acceptedLocation: bestLocation,
                firstCallback: firstCallback,
                callbackCount: callbackCount,
                coreGeocoderAddress: coreGeocoderAddress,
                mapKitCandidate: mapKitCandidate,
                nearbyPOICandidate: nearbyPOICandidate,
                coreGeocoderRawResult: coreGeocoderRawResult,
                mapKitRawResult: mapKitRawResult,
                nearbyPOIRawResult: nearbyPOIRawResult
            )
            return
        }

        let isExplicitRefresh = activeRefreshID != nil
        let promoted = LocationCandidatePolicy.shouldPromote(
            candidate,
            over: bestLocation,
            now: now,
            isExplicitRefresh: isExplicitRefresh
        )
        let currentDescription = bestLocation.map(debugLocation) ?? "-"
        let distanceFromCurrent = bestLocation.map { candidate.distance(from: $0) }
        let candidateRawLocation = rawLocation(matching: candidate, in: rawLocations)
        debugLog(
            "candidate=\(debugLocation(candidate)) promoted=\(promoted) explicit=\(isExplicitRefresh) current=\(currentDescription) distance=\(distanceFromCurrent.map { String($0) } ?? "-")"
        )
        if promoted {
            bestLocation = candidate
            bestRawLocation = candidateRawLocation
            coreGeocoderAddress = nil
            mapKitCandidate = nil
            nearbyPOICandidate = nil
            coreGeocoderRawResult = nil
            mapKitRawResult = nil
            nearbyPOIRawResult = nil
            updateSnapshot(with: candidate)
            reverseGeocodeIfNeeded(
                for: candidate,
                rawLocation: candidateRawLocation,
                force: isExplicitRefresh
            )
        } else if isExplicitRefresh,
                  !isGeocoding,
                  let bestLocation {
            // A manual refresh may return the same coordinate that already
            // has an address. Re-run the resolver so a corrected MapKit/POI
            // result can replace a stale CLGeocoder area name.
            reverseGeocodeIfNeeded(for: bestLocation, rawLocation: bestRawLocation, force: true)
        }

        diagnostics = LocationDiagnostics(
            latestCallback: latestCallback,
            selectedCandidate: candidate,
            decision: promoted ? .promoted : .retainedExisting,
            acceptedLocation: bestLocation,
            firstCallback: firstCallback,
            callbackCount: callbackCount,
            coreGeocoderAddress: coreGeocoderAddress,
            mapKitCandidate: mapKitCandidate,
            nearbyPOICandidate: nearbyPOICandidate,
            coreGeocoderRawResult: coreGeocoderRawResult,
            mapKitRawResult: mapKitRawResult,
            nearbyPOIRawResult: nearbyPOIRawResult
        )

        if let refreshID = activeRefreshID,
           LocationCandidatePolicy.canSatisfyOneShotRefresh(candidate, receivedAt: now) {
            // A valid callback is enough to complete a refresh. The current
            // snapshot may intentionally be retained when the candidate does
            // not meet the promotion threshold.
            finishOneShotRefresh(id: refreshID, result: .success(snapshot))
        }

        debugLog(
            "state accepted=\(bestLocation.map(debugLocation) ?? "-") snapshot=\(debugSnapshot(snapshot)) geocoding=\(isGeocoding)"
        )

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

    private nonisolated static func placemarkDiagnostics(
        from placemark: CLPlacemark
    ) -> CoreGeocoderPlacemarkDiagnostics {
        CoreGeocoderPlacemarkDiagnostics(
            name: trimmed(placemark.name),
            areasOfInterest: (placemark.areasOfInterest ?? []).compactMap(trimmed),
            administrativeArea: trimmed(placemark.administrativeArea),
            locality: trimmed(placemark.locality),
            subLocality: trimmed(placemark.subLocality),
            thoroughfare: trimmed(placemark.thoroughfare),
            subThoroughfare: trimmed(placemark.subThoroughfare),
            postalCode: trimmed(placemark.postalCode),
            country: trimmed(placemark.country),
            isoCountryCode: trimmed(placemark.isoCountryCode)
        )
    }

    private nonisolated static func mapItemDiagnostics(
        from item: MapItemValue,
        anchor: LocationValue
    ) -> LocationMapItemDiagnostics {
        LocationMapItemDiagnostics(
            name: item.name,
            shortAddress: item.shortAddress,
            fullAddress: item.fullAddress,
            singleLineAddress: item.singleLineAddress,
            hasPOICategory: item.hasPOICategory,
            latitude: item.latitude,
            longitude: item.longitude,
            distance: CLLocation(latitude: item.latitude, longitude: item.longitude)
                .distance(from: anchor.location)
        )
    }

    private nonisolated static func trimmed(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
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

    nonisolated static func preferredPOIName(from item: MapItemValue) -> String? {
        guard let rawName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty else {
            return nil
        }

        let addressCandidates = [item.shortAddress, item.fullAddress, item.singleLineAddress]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if item.hasPOICategory {
            return rawName
        }

        if addressCandidates.contains(where: { $0 == rawName || $0.contains(rawName) || rawName.contains($0) }),
           !LocationPOISelectionPolicy.isStrongPOIName(rawName) {
            return nil
        }

        return looksLikePointOfInterestName(rawName) ? rawName : nil
    }

    private nonisolated static func resolveMapKitItems(
        _ items: [MapItemValue],
        anchor: LocationValue
    ) -> MapKitResolution {
        let selection = selectMapItem(from: items, anchor: anchor)
        let address = selection.flatMap { selection in
            let formatted = formattedAddress(from: selection.candidate.item)
            return formatted.isEmpty ? nil : formatted
        }
        let source: LocationAddressSource? = address == nil
            ? nil
            : (selection?.tier == .regional ? .regionalPOI : .mapKit)
        return MapKitResolution(
            address: address,
            addressSource: source,
            addressDistance: selection?.distance,
            shouldSearchNearby: shouldSearchNearbyPOI(
                for: selection?.candidate.item,
                resolvedAddress: address
            ),
            candidate: selection.map(Self.mapCandidateDiagnostics(from:))
        )
    }

    private nonisolated static func resolveNearbyPOI(
        _ items: [MapItemValue],
        anchor: LocationValue,
        fallbackAddress: String?
    ) -> NearbyPOIResolution {
        guard let selection = selectMapItem(from: items, anchor: anchor) else {
            return NearbyPOIResolution(
                enrichedAddress: nil,
                didFindPOI: false,
                distance: nil,
                addressSource: nil,
                candidate: nil
            )
        }

        let poiName = selection.candidate.poiName
        let poiAddress = [
            selection.candidate.item.singleLineAddress,
            selection.candidate.item.fullAddress,
            selection.candidate.item.shortAddress
        ]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? ""
        let enriched = composeEnrichedAddress(
            poiName: poiName,
            fallbackAddress: fallbackAddress,
            poiAddress: poiAddress
        )
        return NearbyPOIResolution(
            enrichedAddress: enriched.isEmpty ? nil : enriched,
            didFindPOI: true,
            distance: selection.distance,
            addressSource: selection.tier == .regional ? .regionalPOI : .nearbyPOI,
            candidate: mapCandidateDiagnostics(from: selection)
        )
    }

    private nonisolated static func mapCandidateDiagnostics(
        from selection: LocationPOISelection
    ) -> LocationMapCandidateDiagnostics {
        let address = [
            selection.candidate.item.singleLineAddress,
            selection.candidate.item.fullAddress,
            selection.candidate.item.shortAddress
        ]
            .compactMap { $0 }
            .first { !$0.isEmpty }

        return LocationMapCandidateDiagnostics(
            name: selection.candidate.poiName,
            address: address,
            latitude: selection.candidate.item.latitude,
            longitude: selection.candidate.item.longitude,
            distance: selection.distance,
            tier: selection.tier
        )
    }

    nonisolated static func preferredResolvedAddress(
        _ mapKitAddress: String?,
        fallbackAddress: String?,
        addressSource: LocationAddressSource? = nil
    ) -> String? {
        let mapKit = mapKitAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let mapKit, !mapKit.isEmpty else { return fallback }
        guard let fallback, !fallback.isEmpty else { return mapKit }

        if addressSource == .mapKit || addressSource == .regionalPOI {
            return mapKit
        }

        let mapKitIsPOI = looksLikePointOfInterestCandidate(mapKit)
        let fallbackIsPOI = looksLikePointOfInterestCandidate(fallback)
        if mapKitIsPOI && !fallbackIsPOI { return mapKit }
        if mapKitIsPOI == fallbackIsPOI && mapKit.count > fallback.count && !looksLikeStreetAddress(mapKit) {
            return mapKit
        }
        return fallback
    }

    nonisolated static func shouldSearchNearbyPOI(for item: MapItemValue?, resolvedAddress: String?) -> Bool {
        guard let resolvedAddress, !resolvedAddress.isEmpty else { return true }

        guard let poiName = item.flatMap(preferredPOIName(from:)) else {
            return true
        }

        // A residential compound or other weakly named map result should not
        // prevent a nearby search from finding a stronger venue such as a
        // science park, campus, mall, or office complex.
        return !LocationPOISelectionPolicy.isStrongPOIName(poiName)
    }

    private nonisolated static func selectMapItem(
        from items: [MapItemValue],
        anchor: LocationValue
    ) -> LocationPOISelection? {
        let candidates = items.compactMap { item -> LocationPOICandidate? in
            guard let poiName = preferredPOIName(from: item) else {
                return nil
            }
            return LocationPOICandidate(item: item, poiName: poiName)
        }
        return LocationPOISelectionPolicy.rank(candidates, anchor: anchor)
    }

    nonisolated static func composeEnrichedAddress(
        poiName: String,
        fallbackAddress: String?,
        poiAddress: String
    ) -> String {
        let fallback = fallbackAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = poiAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty {
            return composePreferredAddress(primaryName: poiName, detailAddress: detail)
        }
        if let fallback, !fallback.isEmpty {
            return composePreferredAddress(primaryName: poiName, detailAddress: fallback)
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
            self?.handleLocationValues(values, rawLocations: locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let result = Self.userFacingLocationMessage(for: error)
        Task { @MainActor [weak self] in
            self?.handleLocationFailure(message: result.message, isTransient: result.isTransient)
        }
    }
}
