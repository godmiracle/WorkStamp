//
//  WorkdayCalculator.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import Foundation

struct WorkdayCalculationOptions {
    let excludeWeekends: Bool
    let excludeChinaHolidays: Bool
}

protocol ChinaHolidayProviding {
    var supportsHolidayExclusion: Bool { get }
    func isHoliday(_ date: Date, calendar: Calendar) -> Bool
}

struct ChinaHolidayProvider: ChinaHolidayProviding {
    let supportsHolidayExclusion = false

    func isHoliday(_ date: Date, calendar: Calendar) -> Bool {
        false
    }
}

enum WorkdayCalculator {
    static func workdayNumber(
        from startDate: Date,
        to targetDate: Date,
        options: WorkdayCalculationOptions,
        calendar: Calendar = .current,
        holidayProvider: ChinaHolidayProviding = ChinaHolidayProvider()
    ) -> Int? {
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedTargetDate = calendar.startOfDay(for: targetDate)

        guard normalizedTargetDate >= normalizedStartDate else {
            return nil
        }

        guard normalizedTargetDate != normalizedStartDate else {
            return 1
        }

        var workdayNumber = 1
        var cursor = calendar.date(byAdding: .day, value: 1, to: normalizedStartDate) ?? normalizedTargetDate

        while cursor <= normalizedTargetDate {
            if shouldCount(
                cursor,
                options: options,
                calendar: calendar,
                holidayProvider: holidayProvider
            ) {
                workdayNumber += 1
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = nextDay
        }

        return workdayNumber
    }

    private static func shouldCount(
        _ date: Date,
        options: WorkdayCalculationOptions,
        calendar: Calendar,
        holidayProvider: ChinaHolidayProviding
    ) -> Bool {
        if options.excludeWeekends, calendar.isDateInWeekend(date) {
            return false
        }

        if options.excludeChinaHolidays,
           holidayProvider.supportsHolidayExclusion,
           holidayProvider.isHoliday(date, calendar: calendar) {
            return false
        }

        return true
    }
}
