//
//  WorkStampTests.swift
//  WorkStampTests
//
//  Created by CJ on 2026/7/1.
//

import Testing
@testable import WorkStamp

struct WorkStampTests {

    @Test func sameDayIsAlwaysDayOne() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = date(2026, 7, 4)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: startDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == 1)
    }

    @Test func weekendsAreSkippedAfterStartDay() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = date(2026, 7, 3)
        let targetDate = date(2026, 7, 6)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == 2)
    }

    @Test func naturalDaysCanBeCountedWithoutWeekendExclusion() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = date(2026, 7, 3)
        let targetDate = date(2026, 7, 6)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: false, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == 4)
    }

    @Test func earlierTargetReturnsNil() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = date(2026, 7, 6)
        let targetDate = date(2026, 7, 3)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == nil)
    }

    @Test func holidayProviderSkipsMarkedHoliday() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let startDate = date(2026, 7, 1)
        let targetDate = date(2026, 7, 3)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: false, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: StubHolidayProvider(holidayDates: [targetDate], adjustedWorkdays: [])
        )

        #expect(result == 2)
    }

    @Test func chinaHolidayProviderSkips2026SpringFestivalBreak() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()
        let startDate = date(2026, 2, 14)
        let targetDate = date(2026, 2, 24)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )

        #expect(result == 2)
    }

    @Test func chinaHolidayProviderTreatsAdjustedWeekendAsWorkday() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()
        let startDate = date(2026, 2, 27)
        let targetDate = date(2026, 2, 28)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )

        #expect(result == 2)
    }

    @Test func chinaHolidayProviderSkips2026NationalDayGoldenWeek() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()
        let startDate = date(2026, 9, 30)
        let targetDate = date(2026, 10, 8)
        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: false, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )

        #expect(result == 2)
    }

    @Test func attendanceStatusSwitchesAfterOffDutyTime() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let onDutyDate = time(2026, 7, 1, 8, 30)
        let offDutyDate = time(2026, 7, 1, 18, 0)

        #expect(
            AttendanceStatusResolver.resolve(
                for: onDutyDate,
                onDutyMinutes: 9 * 60,
                offDutyMinutes: 18 * 60,
                calendar: calendar
            ).displayName == "上班"
        )

        #expect(
            AttendanceStatusResolver.resolve(
                for: offDutyDate,
                onDutyMinutes: 9 * 60,
                offDutyMinutes: 18 * 60,
                calendar: calendar
            ).displayName == "下班"
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? Date.distantPast
    }

    private func time(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date.distantPast
    }

    private struct StubHolidayProvider: ChinaHolidayProviding {
        let holidayDates: [Date]
        let adjustedWorkdays: [Date]
        let supportsHolidayExclusion = true
        let supportedYears: [Int] = []

        func isHoliday(_ date: Date, calendar: Calendar) -> Bool {
            holidayDates.contains { calendar.isDate($0, inSameDayAs: date) }
        }

        func isAdjustedWorkday(_ date: Date, calendar: Calendar) -> Bool {
            adjustedWorkdays.contains { calendar.isDate($0, inSameDayAs: date) }
        }
    }

}
