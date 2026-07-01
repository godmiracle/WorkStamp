//
//  AppSettings.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import CoreLocation
import SwiftUI

enum AppSettingKeys {
    static let workStartTimestamp = "workStartTimestamp"
    static let excludeWeekends = "excludeWeekends"
    static let excludeChinaHolidays = "excludeChinaHolidays"
    static let watermarkPosition = "watermarkPosition"
    static let watermarkFontSize = "watermarkFontSize"
    static let onDutyMinutes = "onDutyMinutes"
    static let offDutyMinutes = "offDutyMinutes"
}

struct LocationSnapshot {
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let horizontalAccuracy: Double?
    let timestamp: Date?
    let address: String?

    static let empty = LocationSnapshot(
        latitude: nil,
        longitude: nil,
        altitude: nil,
        horizontalAccuracy: nil,
        timestamp: nil,
        address: nil
    )

    var photoAssetLocation: CLLocation? {
        guard let latitude, let longitude else {
            return nil
        }

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy ?? kCLLocationAccuracyNearestTenMeters,
            verticalAccuracy: altitude == nil ? -1 : 10,
            timestamp: timestamp ?? Date()
        )
    }

    var quality: LocationQuality {
        guard let horizontalAccuracy, let timestamp else {
            return .searching
        }

        let age = Date().timeIntervalSince(timestamp)
        if horizontalAccuracy <= 35 && age <= 20 {
            return .stable
        }

        if horizontalAccuracy <= 120 && age <= 45 {
            return .approximate
        }

        return .searching
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
    var workStampCoordinateString: String {
        String(format: "%.6f", self)
    }

    var workStampAltitudeString: String {
        String(format: "%.1f", self)
    }
}

enum AttendanceStatus {
    case onDuty
    case offDuty

    var displayName: String {
        switch self {
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
            return .onDuty
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
