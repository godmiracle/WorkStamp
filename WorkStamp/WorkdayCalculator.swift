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
    var supportedYears: [Int] { get }
    func isHoliday(_ date: Date, calendar: Calendar) -> Bool
    func isAdjustedWorkday(_ date: Date, calendar: Calendar) -> Bool
}

struct ChinaHolidayProvider: ChinaHolidayProviding {
    let supportsHolidayExclusion = true
    let supportedYears = [2026]

    func isHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: normalizedDate)
        return schedule(for: year, calendar: calendar)?.holidayDates.contains(normalizedDate) == true
    }

    func isAdjustedWorkday(_ date: Date, calendar: Calendar) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: normalizedDate)
        return schedule(for: year, calendar: calendar)?.adjustedWorkdays.contains(normalizedDate) == true
    }

    private func schedule(for year: Int, calendar: Calendar) -> ChinaHolidaySchedule? {
        switch year {
        case 2026:
            return make2026Schedule(calendar: calendar)
        default:
            return nil
        }
    }

    private func make2026Schedule(calendar: Calendar) -> ChinaHolidaySchedule {
        ChinaHolidaySchedule(
            holidayDates: makeDates(
                [
                    (1, 1),
                    (2, 15), (2, 16), (2, 17), (2, 18), (2, 19), (2, 20), (2, 21), (2, 22), (2, 23),
                    (4, 4), (4, 5), (4, 6),
                    (5, 1), (5, 2), (5, 3), (5, 4), (5, 5),
                    (6, 19), (6, 20), (6, 21),
                    (9, 25), (9, 26), (9, 27),
                    (10, 1), (10, 2), (10, 3), (10, 4), (10, 5), (10, 6), (10, 7)
                ],
                year: 2026,
                calendar: calendar
            ),
            adjustedWorkdays: makeDates(
                [
                    (2, 28),
                    (4, 26),
                    (9, 27),
                    (10, 10)
                ],
                year: 2026,
                calendar: calendar
            )
        )
    }

    private func makeDates(
        _ monthDays: [(Int, Int)],
        year: Int,
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            monthDays.compactMap { month, day in
                gregorianDate(year: year, month: month, day: day, calendar: calendar)
                    .map { calendar.startOfDay(for: $0) }
            }
        )
    }

    private func gregorianDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        return components.date
    }
}

private struct ChinaHolidaySchedule {
    let holidayDates: Set<Date>
    let adjustedWorkdays: Set<Date>
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
        if options.excludeChinaHolidays,
           holidayProvider.supportsHolidayExclusion,
           holidayProvider.isAdjustedWorkday(date, calendar: calendar) {
            return true
        }

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
