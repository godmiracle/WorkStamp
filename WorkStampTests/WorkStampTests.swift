//
//  WorkStampTests.swift
//  WorkStampTests
//
//  Created by CJ on 2026/7/1.
//

import Foundation
import Testing
@testable import WorkStamp

@MainActor
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
        let result = WorkdayCalculator.workdayNumber(
            from: date(2026, 7, 3),
            to: date(2026, 7, 6),
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == 2)
    }

    @Test func naturalDaysCanBeCountedWithoutWeekendExclusion() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let result = WorkdayCalculator.workdayNumber(
            from: date(2026, 7, 3),
            to: date(2026, 7, 6),
            options: WorkdayCalculationOptions(excludeWeekends: false, excludeChinaHolidays: false),
            calendar: calendar
        )

        #expect(result == 4)
    }

    @Test func earlierTargetReturnsNil() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let result = WorkdayCalculator.workdayNumber(
            from: date(2026, 7, 6),
            to: date(2026, 7, 3),
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
        let result = WorkdayCalculator.workdayNumber(
            from: date(2026, 2, 14),
            to: date(2026, 2, 24),
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: ChinaHolidayProvider()
        )

        #expect(result == 2)
    }

    @Test func officialAdjustedWorkdaysOverrideWeekendExclusion() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()
        let adjustedDates = [
            (1, 4), (2, 14), (2, 28), (5, 9), (9, 20), (10, 10)
        ]

        for (month, day) in adjustedDates {
            #expect(provider.isAdjustedWorkday(date(2026, month, day), calendar: calendar))
            let result = WorkdayCalculator.workdayNumber(
                from: date(2026, month, day - 1),
                to: date(2026, month, day),
                options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
                calendar: calendar,
                holidayProvider: provider
            )
            #expect(result == 2)
        }
    }

    @Test func officialNewYearHolidayIncludesJanuarySecondAndThird() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()
        let startDate = date(2025, 12, 31)
        let targetDate = date(2026, 1, 4)

        #expect(provider.isHoliday(date(2026, 1, 1), calendar: calendar))
        #expect(provider.isHoliday(date(2026, 1, 2), calendar: calendar))
        #expect(provider.isHoliday(date(2026, 1, 3), calendar: calendar))
        #expect(provider.isAdjustedWorkday(targetDate, calendar: calendar))

        let result = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: targetDate,
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )
        #expect(result == 2)
    }

    @Test func erroneousAdjustedDatesDoNotOverrideRules() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let provider = ChinaHolidayProvider()

        #expect(!provider.isAdjustedWorkday(date(2026, 4, 26), calendar: calendar))
        #expect(!provider.isAdjustedWorkday(date(2026, 9, 27), calendar: calendar))
        #expect(provider.isHoliday(date(2026, 9, 27), calendar: calendar))

        let aprilResult = WorkdayCalculator.workdayNumber(
            from: date(2026, 4, 25),
            to: date(2026, 4, 26),
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )
        let septemberResult = WorkdayCalculator.workdayNumber(
            from: date(2026, 9, 26),
            to: date(2026, 9, 27),
            options: WorkdayCalculationOptions(excludeWeekends: true, excludeChinaHolidays: true),
            calendar: calendar,
            holidayProvider: provider
        )

        #expect(aprilResult == 1)
        #expect(septemberResult == 1)
    }

    @Test func attendanceStatusUsesAllThreeBoundaries() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let onDuty = 9 * 60
        let offDuty = 18 * 60

        #expect(
            AttendanceStatusResolver.resolve(
                for: time(2026, 7, 1, 8, 59),
                onDutyMinutes: onDuty,
                offDutyMinutes: offDuty,
                calendar: calendar
            ) == .beforeDuty
        )
        #expect(
            AttendanceStatusResolver.resolve(
                for: time(2026, 7, 1, 9, 0),
                onDutyMinutes: onDuty,
                offDutyMinutes: offDuty,
                calendar: calendar
            ) == .onDuty
        )
        #expect(
            AttendanceStatusResolver.resolve(
                for: time(2026, 7, 1, 17, 59),
                onDutyMinutes: onDuty,
                offDutyMinutes: offDuty,
                calendar: calendar
            ) == .onDuty
        )
        #expect(
            AttendanceStatusResolver.resolve(
                for: time(2026, 7, 1, 18, 0),
                onDutyMinutes: onDuty,
                offDutyMinutes: offDuty,
                calendar: calendar
            ) == .offDuty
        )
    }

    @Test func attendanceSettingsBothChangeTheResolvedState() async throws {
        let date = time(2026, 7, 1, 17, 30)

        #expect(
            AttendanceStatusResolver.resolve(
                for: date,
                onDutyMinutes: 9 * 60,
                offDutyMinutes: 18 * 60
            ) == .onDuty
        )
        #expect(
            AttendanceStatusResolver.resolve(
                for: date,
                onDutyMinutes: 9 * 60,
                offDutyMinutes: 17 * 60
            ) == .offDuty
        )
        #expect(
            AttendanceStatusResolver.resolve(
                for: time(2026, 7, 1, 8, 30),
                onDutyMinutes: 10 * 60,
                offDutyMinutes: 18 * 60
            ) == .beforeDuty
        )
    }

    @Test func captureFlightGateRejectsDuplicatesAndIgnoresLateFinishes() async throws {
        var gate = CaptureFlightGate()
        let firstID = gate.begin()

        #expect(firstID != nil)
        let duplicateID = gate.begin()
        #expect(duplicateID == nil)
        #expect(gate.finish(id: (firstID ?? 0) + 1) == false)
        let didFinish = gate.finish(id: firstID ?? 0)
        #expect(didFinish)
        let didFinishLate = gate.finish(id: firstID ?? 0)
        #expect(!didFinishLate)
        let nextID = gate.begin()
        #expect(nextID != nil)
    }

    @Test func requestGenerationRejectsStaleTokens() async throws {
        var generation = RequestGeneration()
        let first = generation.next()
        let second = generation.next()

        #expect(!generation.accepts(first))
        #expect(generation.accepts(second))
        generation.invalidate()
        #expect(!generation.accepts(second))
    }

    @Test func failedFreshLocationUsesRecentCachedSnapshot() async throws {
        let captureDate = date(2026, 8, 20, 14, 20)
        let cachedSnapshot = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 50,
            verticalAccuracy: 18,
            timestamp: captureDate.addingTimeInterval(-20),
            address: "测试地点"
        )

        let resolved = CaptureLocationResolver.resolve(
            result: .failure(.timedOut),
            cachedSnapshot: cachedSnapshot,
            referenceDate: captureDate
        )

        #expect(resolved == cachedSnapshot)
    }

    @Test func staleCachedSnapshotDoesNotBecomeCaptureMetadata() async throws {
        let captureDate = date(2026, 8, 20, 14, 20)
        let staleSnapshot = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 50,
            verticalAccuracy: 18,
            timestamp: captureDate.addingTimeInterval(-46),
            address: "过期地点"
        )

        let resolved = CaptureLocationResolver.resolve(
            result: .failure(.timedOut),
            cachedSnapshot: staleSnapshot,
            referenceDate: captureDate
        )

        #expect(resolved == .empty)
    }

    @Test func successfulFreshLocationKeepsRecentCachedAddress() async throws {
        let captureDate = date(2026, 8, 20, 14, 20)
        let cachedSnapshot = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 50,
            verticalAccuracy: 18,
            timestamp: captureDate.addingTimeInterval(-20),
            address: "测试地点"
        )
        let freshSnapshot = LocationSnapshot(
            latitude: 31.23045,
            longitude: 121.47372,
            altitude: 8.6,
            horizontalAccuracy: 12,
            verticalAccuracy: 10,
            timestamp: captureDate,
            address: nil
        )

        let resolved = CaptureLocationResolver.resolve(
            result: .success(freshSnapshot),
            cachedSnapshot: cachedSnapshot,
            referenceDate: captureDate
        )

        #expect(resolved.address == "测试地点")
        #expect(resolved.latitude == freshSnapshot.latitude)
        #expect(resolved.horizontalAccuracy == freshSnapshot.horizontalAccuracy)
    }

    @Test func unavailableLocationDoesNotCreatePhotoMetadata() async throws {
        #expect(LocationSnapshot.empty.photoAssetMetadata == nil)

        let incomplete = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: nil,
            horizontalAccuracy: 12,
            verticalAccuracy: nil,
            timestamp: Date(timeIntervalSince1970: 1_750_000_000),
            address: nil
        )
        #expect(incomplete.photoAssetMetadata == nil)
    }

    @Test func validLocationPreservesPhotoMetadataWithoutSyntheticValues() async throws {
        let timestamp = Date(timeIntervalSince1970: 1_750_000_000)
        let snapshot = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 12,
            verticalAccuracy: 18,
            timestamp: timestamp,
            address: "测试地点"
        )

        let metadata = snapshot.photoAssetMetadata
        #expect(metadata?.altitude == 8.5)
        #expect(metadata?.horizontalAccuracy == 12)
        #expect(metadata?.verticalAccuracy == 18)
        #expect(metadata?.timestamp == timestamp)
    }

    @Test func photoLibraryCancellationGateIgnoresLateSuccess() async throws {
        let gate = PhotoLibraryCancellationGate<Int>()
        gate.cancel()

        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
                #expect(!gate.install(continuation))
            }
            Issue.record("Cancellation should win before the Photos completion.")
        } catch is CancellationError {
            // Expected: a late Photos success must not replace cancellation.
        } catch {
            Issue.record("Expected CancellationError, got \(error.localizedDescription).")
        }

        gate.resolve(.success(42))
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
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
