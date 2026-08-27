//
//  AppSettings.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import CoreLocation
import Foundation
import SwiftUI

enum AppVersionInfo {
    static var marketingVersion: String {
        value(for: "CFBundleShortVersionString")
    }

    static var buildNumber: String {
        value(for: "CFBundleVersion")
    }

    static var displayValue: String {
        "\(marketingVersion) (\(buildNumber))"
    }

#if DEBUG
    static let channelName = "Debug"
#else
    static let channelName = "Release"
#endif

    private static func value(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return "未知"
        }

        return value
    }
}

enum AppSettingKeys {
    static let workStartTimestamp = "workStartTimestamp"
    static let excludeWeekends = "excludeWeekends"
    static let excludeChinaHolidays = "excludeChinaHolidays"
    static let watermarkPosition = "watermarkPosition"
    static let watermarkFontSize = "watermarkFontSize"
    static let onDutyMinutes = "onDutyMinutes"
    static let offDutyMinutes = "offDutyMinutes"
    static let workdayTemplateName = "workdayTemplateName"
    static let workdayPrefixMigrationVersion = "workdayPrefixMigrationVersion"
}

enum WorkdayPrefixFormatter {
    static let currentMigrationVersion = 1
    static let defaultPrefix = "坐班Bench"

    static func displayPrefix(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultPrefix : trimmed
    }

    static func phrase(prefix: String, dayNumber: Int) -> String {
        "\(displayPrefix(from: prefix))第\(dayNumber)天"
    }

    static func migratedPrefix(from legacyValue: String) -> String {
        let trimmed = legacyValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return defaultPrefix
        }

        if trimmed.hasPrefix("坐班") {
            return trimmed
        }

        return "坐班\(trimmed)"
    }
}

enum LocationAddressSource: String, Sendable, Equatable {
    case coreGeocoder
    case mapKit
    case nearbyPOI
    case regionalPOI
    case areaFallback
    case cached

    var displayName: String {
        switch self {
        case .coreGeocoder:
            return "系统地址"
        case .mapKit:
            return "地图地址"
        case .nearbyPOI:
            return "附近地点"
        case .regionalPOI:
            return "区域地点"
        case .areaFallback:
            return "区域兜底"
        case .cached:
            return "近期缓存"
        }
    }
}

enum LocationQualityPolicy {
    nonisolated static let captureMaximumAge: TimeInterval = 45
    nonisolated static let captureMaximumHorizontalAccuracy: CLLocationDistance = 120
    nonisolated static let trustedPOIBaseDistance: CLLocationDistance = 50
    nonisolated static let trustedPOIMaximumDistance: CLLocationDistance = 120
    nonisolated static let regionalPOIBaseDistance: CLLocationDistance = 180
    nonisolated static let regionalPOIMaximumDistance: CLLocationDistance = 360
    nonisolated static let cachedAreaMaximumDistance: CLLocationDistance = 100
    nonisolated static let relocationMinimumDistance: CLLocationDistance = 150
    nonisolated static let explicitRefreshMinimumDistance: CLLocationDistance = 50

    nonisolated static func trustedPOIMaximumDistance(for horizontalAccuracy: CLLocationDistance) -> CLLocationDistance {
        guard horizontalAccuracy > 0 else {
            return trustedPOIBaseDistance
        }

        return min(
            max(horizontalAccuracy, trustedPOIBaseDistance),
            trustedPOIMaximumDistance
        )
    }

    nonisolated static func acceptsTrustedPOI(
        distance: CLLocationDistance,
        horizontalAccuracy: CLLocationDistance
    ) -> Bool {
        distance <= trustedPOIMaximumDistance(for: horizontalAccuracy)
    }

    nonisolated static func acceptsCachedArea(distance: CLLocationDistance) -> Bool {
        distance <= cachedAreaMaximumDistance
    }

    nonisolated static func isSignificantRelocation(
        distance: CLLocationDistance,
        currentHorizontalAccuracy: CLLocationDistance,
        candidateHorizontalAccuracy: CLLocationDistance
    ) -> Bool {
        distance > max(
            relocationMinimumDistance,
            currentHorizontalAccuracy + candidateHorizontalAccuracy
        )
    }

    nonisolated static func regionalPOIMaximumDistance(
        for horizontalAccuracy: CLLocationDistance
    ) -> CLLocationDistance {
        // A regional POI may be represented by an entrance or centroid farther
        // away than the fused coordinate, but it must remain bounded by both
        // the minimum venue radius and a hard upper limit.
        min(
            max(horizontalAccuracy * 2, regionalPOIBaseDistance),
            regionalPOIMaximumDistance
        )
    }
}

struct LocationSnapshot: Sendable, Equatable {

    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let horizontalAccuracy: Double?
    let verticalAccuracy: Double?
    let timestamp: Date?
    let address: String?
    let addressSource: LocationAddressSource?
    let addressDistance: CLLocationDistance?

    init(
        latitude: Double?,
        longitude: Double?,
        altitude: Double?,
        horizontalAccuracy: Double?,
        verticalAccuracy: Double?,
        timestamp: Date?,
        address: String?,
        addressSource: LocationAddressSource? = nil,
        addressDistance: CLLocationDistance? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.timestamp = timestamp
        self.address = address
        self.addressSource = addressSource
        self.addressDistance = addressDistance
    }

    static let empty = LocationSnapshot(
        latitude: nil,
        longitude: nil,
        altitude: nil,
        horizontalAccuracy: nil,
        verticalAccuracy: nil,
        timestamp: nil,
        address: nil,
        addressSource: nil,
        addressDistance: nil
    )

    var photoAssetMetadata: PhotoAssetLocationMetadata? {
        guard let latitude,
              let longitude,
              let altitude,
              let horizontalAccuracy,
              let verticalAccuracy,
              let timestamp,
              horizontalAccuracy >= 0,
              verticalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) else {
            return nil
        }

        return PhotoAssetLocationMetadata(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var previewAddressText: String {
        if let address, !address.isEmpty {
            return address
        }

        return fallbackResolvedAddress ?? "定位中或不可用"
    }

    var detailAddressText: String {
        if let address, !address.isEmpty {
            return address
        }

        return fallbackResolvedAddress ?? "当前位置暂未获取到地址"
    }

    var watermarkAddressText: String {
        if let address, !address.isEmpty {
            return address
        }

        return fallbackWatermarkAddress ?? "定位中或不可用"
    }

    private var fallbackResolvedAddress: String? {
        guard let coordinateText else {
            return nil
        }

        switch quality {
        case .stable:
            return "当前位置附近（\(coordinateText)）"
        case .approximate:
            return "定位信号一般·当前位置附近（\(coordinateText)）"
        case .searching:
            return "定位信号较弱·当前位置附近（\(coordinateText)）"
        }
    }

    private var fallbackWatermarkAddress: String? {
        guard let coordinateText else {
            return nil
        }

        switch quality {
        case .stable:
            return "当前位置附近（\(coordinateText)）"
        case .approximate:
            return "信号一般·\(coordinateText)附近"
        case .searching:
            return "信号较弱·\(coordinateText)附近"
        }
    }

    private var coordinateText: String? {
        guard let latitude, let longitude else {
            return nil
        }

        return "\(latitude.workStampCoordinateString), \(longitude.workStampCoordinateString)"
    }

    var quality: LocationQuality {
        guard let horizontalAccuracy, let timestamp else {
            return .searching
        }

        let age = Date().timeIntervalSince(timestamp)
        if horizontalAccuracy <= 35 && age <= 20 {
            return .stable
        }

        if horizontalAccuracy <= LocationQualityPolicy.captureMaximumHorizontalAccuracy,
           age <= LocationQualityPolicy.captureMaximumAge {
            return .approximate
        }

        return .searching
    }

    func canBeUsedAsCaptureFallback(at referenceDate: Date) -> Bool {
        guard hasCoordinates,
              let horizontalAccuracy,
              let timestamp,
              horizontalAccuracy > 0,
              horizontalAccuracy <= LocationQualityPolicy.captureMaximumHorizontalAccuracy else {
            return false
        }

        let age = referenceDate.timeIntervalSince(timestamp)
        return age >= 0 && age <= LocationQualityPolicy.captureMaximumAge
    }

    func withRecentAddress(from candidate: LocationSnapshot, at referenceDate: Date) -> LocationSnapshot {
        guard address == nil,
              let candidateAddress = candidate.address,
              !candidateAddress.isEmpty,
              candidate.canBeUsedAsCaptureFallback(at: referenceDate),
              let latitude,
              let longitude,
              let candidateLatitude = candidate.latitude,
              let candidateLongitude = candidate.longitude else {
            return self
        }

        let distance = CLLocation(
            latitude: latitude,
            longitude: longitude
        ).distance(from: CLLocation(
            latitude: candidateLatitude,
            longitude: candidateLongitude
        ))

        guard LocationQualityPolicy.acceptsCachedArea(distance: distance) else {
            return self
        }

        return LocationSnapshot(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp,
            address: candidateAddress,
            addressSource: .cached,
            addressDistance: distance
        )
    }
}

struct PhotoAssetLocationMetadata: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let timestamp: Date

    nonisolated var location: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            timestamp: timestamp
        )
    }
}

struct CaptureContext: Sendable, Equatable {
    let captureDate: Date
    let locationSnapshot: LocationSnapshot

    var photoAssetLocation: PhotoAssetLocationMetadata? {
        locationSnapshot.photoAssetMetadata
    }
}

struct CaptureFlightGate: Sendable {
    private(set) var activeID: UInt64?
    private var nextID: UInt64 = 0

    mutating func begin() -> UInt64? {
        guard activeID == nil else {
            return nil
        }

        nextID &+= 1
        activeID = nextID
        return nextID
    }

    mutating func finish(id: UInt64) -> Bool {
        guard activeID == id else {
            return false
        }

        activeID = nil
        return true
    }
}

struct RequestGeneration: Sendable {
    private(set) var value: UInt64 = 0

    mutating func next() -> UInt64 {
        value &+= 1
        return value
    }

    mutating func invalidate() {
        value &+= 1
    }

    func accepts(_ token: UInt64) -> Bool {
        token == value
    }
}

enum LocationQuality {
    case stable
    case approximate
    case searching

    var displayName: String {
        switch self {
        case .stable:
            return "定位稳定"
        case .approximate:
            return "定位一般"
        case .searching:
            return "定位中"
        }
    }
}

enum WatermarkPosition: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:
            return "左上"
        case .topRight:
            return "右上"
        case .bottomLeft:
            return "左下"
        case .bottomRight:
            return "右下"
        }
    }

    var overlayAlignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }
}

struct WatermarkPositionGrid: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(WatermarkPosition.allCases) { position in
                Button {
                    selection = position.rawValue
                } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: position.overlayAlignment) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(isSelected(position) ? 0.18 : 0.08))
                                .frame(height: 76)

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                                .frame(width: 34, height: 22)
                                .padding(10)
                        }

                        Text(position.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(isSelected(position) ? 0.14 : 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected(position) ? Color.orange.opacity(0.85) : Color.white.opacity(0.10), lineWidth: isSelected(position) ? 1.5 : 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ position: WatermarkPosition) -> Bool {
        selection == position.rawValue
    }
}

extension DateFormatter {
    static let workStampTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let workStampDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let workStampTimeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

extension Double {
    nonisolated var workStampCoordinateString: String {
        String(format: "%.6f", self)
    }

    nonisolated var workStampAltitudeString: String {
        String(format: "%.1f", self)
    }
}

enum AttendanceStatus: Equatable, Sendable {
    case beforeDuty
    case onDuty
    case offDuty

    var displayName: String {
        switch self {
        case .beforeDuty:
            return "上班前"
        case .onDuty:
            return "上班"
        case .offDuty:
            return "下班"
        }
    }
}

enum AttendanceStatusResolver {
    static let defaultOnDutyMinutes = 9 * 60
    static let defaultOffDutyMinutes = 18 * 60

    static func resolve(
        for date: Date,
        onDutyMinutes: Int,
        offDutyMinutes: Int,
        calendar: Calendar = .current
    ) -> AttendanceStatus {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if currentMinutes >= offDutyMinutes {
            return .offDuty
        }

        if currentMinutes < onDutyMinutes {
            return .beforeDuty
        }

        return .onDuty
    }

    static func timeDate(from minutes: Int, calendar: Calendar = .current) -> Date {
        let safeMinutes = max(0, min(23 * 60 + 59, minutes))
        let hour = safeMinutes / 60
        let minute = safeMinutes % 60
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? now
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
