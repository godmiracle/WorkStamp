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
        #expect(resolved.addressSource == .cached)
        #expect(resolved.addressDistance != nil)
        #expect(resolved.latitude == freshSnapshot.latitude)
        #expect(resolved.horizontalAccuracy == freshSnapshot.horizontalAccuracy)
    }

    @Test func poorFreshAccuracyDoesNotReplaceRecentCaptureSnapshot() async throws {
        let captureDate = date(2026, 8, 20, 14, 20)
        let cachedSnapshot = LocationSnapshot(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 20,
            verticalAccuracy: 18,
            timestamp: captureDate.addingTimeInterval(-10),
            address: "测试地点"
        )
        let poorFreshSnapshot = LocationSnapshot(
            latitude: 31.2320,
            longitude: 121.4750,
            altitude: 8.6,
            horizontalAccuracy: 240,
            verticalAccuracy: 40,
            timestamp: captureDate,
            address: "附近地点"
        )

        let resolved = CaptureLocationResolver.resolve(
            result: .success(poorFreshSnapshot),
            cachedSnapshot: cachedSnapshot,
            referenceDate: captureDate
        )

        #expect(resolved == cachedSnapshot)
    }

    @Test func olderOrLessAccurateCandidateDoesNotReplaceStableLocation() async throws {
        let referenceDate = date(2026, 8, 20, 14, 20)
        let stable = LocationValue(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 25,
            verticalAccuracy: 18,
            timestamp: referenceDate
        )
        let older = LocationValue(
            latitude: 31.2305,
            longitude: 121.4738,
            altitude: 8.5,
            horizontalAccuracy: 80,
            verticalAccuracy: 18,
            timestamp: referenceDate.addingTimeInterval(-1)
        )
        let nearbyButLessAccurate = LocationValue(
            latitude: 31.23041,
            longitude: 121.47371,
            altitude: 8.5,
            horizontalAccuracy: 80,
            verticalAccuracy: 18,
            timestamp: referenceDate
        )

        #expect(LocationCandidatePolicy.isCaptureQualityAcceptable(stable, at: referenceDate))
        #expect(LocationCandidatePolicy.isCaptureQualityAcceptable(nearbyButLessAccurate, at: referenceDate))
        #expect(!LocationCandidatePolicy.shouldPromote(older, over: stable, now: referenceDate))
        #expect(!LocationCandidatePolicy.shouldPromote(nearbyButLessAccurate, over: stable, now: referenceDate))
    }

    @Test func recentCachedCallbackBeforeRefreshStartCanCompleteOneShotRefresh() async throws {
        let refreshStartedAt = date(2026, 8, 20, 14, 20)
        let receivedAt = refreshStartedAt.addingTimeInterval(0.5)
        let cachedCallback = LocationValue(
            latitude: 31.2304,
            longitude: 121.4737,
            altitude: 8.5,
            horizontalAccuracy: 25,
            verticalAccuracy: 18,
            timestamp: refreshStartedAt.addingTimeInterval(-2)
        )

        #expect(cachedCallback.timestamp < refreshStartedAt)
        #expect(LocationCandidatePolicy.canSatisfyOneShotRefresh(cachedCallback, receivedAt: receivedAt))
    }

    @Test func freshSignificantMoveCanReplaceAnOlderHighAccuracyFix() async throws {
        let referenceDate = date(2026, 8, 20, 14, 20)
        let oldFix = LocationValue(
            latitude: 31.3238,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 9,
            verticalAccuracy: 18,
            timestamp: referenceDate
        )
        let movedFix = LocationValue(
            latitude: 31.3238,
            longitude: 121.4844,
            altitude: 9.5,
            horizontalAccuracy: 80,
            verticalAccuracy: 18,
            timestamp: referenceDate
        )

        #expect(LocationCandidatePolicy.isCaptureQualityAcceptable(movedFix, at: referenceDate))
        #expect(LocationCandidatePolicy.shouldPromote(movedFix, over: oldFix, now: referenceDate))
    }

    @Test func explicitRefreshCanPromoteNewerRelocationWithLowerAccuracy() async throws {
        let referenceDate = date(2026, 8, 20, 14, 20)
        let oldFix = LocationValue(
            latitude: 31.3238,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 9,
            verticalAccuracy: 18,
            timestamp: referenceDate
        )
        let refreshedFix = LocationValue(
            latitude: 31.3247,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 80,
            verticalAccuracy: 18,
            timestamp: referenceDate.addingTimeInterval(1)
        )

        #expect(!LocationCandidatePolicy.shouldPromote(refreshedFix, over: oldFix, now: referenceDate.addingTimeInterval(1)))
        #expect(
            LocationCandidatePolicy.shouldPromote(
                refreshedFix,
                over: oldFix,
                now: referenceDate.addingTimeInterval(1),
                isExplicitRefresh: true
            )
        )
    }

    @Test func rawLocationSourceFlagsRemainVisibleWithoutCoordinateCorrection() async throws {
        let simulated = LocationSourceValue(isSimulatedBySoftware: true)
        let system = LocationSourceValue(
            isSimulatedBySoftware: false,
            isProducedByAccessory: false
        )

        #expect(simulated.displayName == "软件模拟定位")
        #expect(simulated.flagsDescription == "系统未提供模拟/外接标记")
        #expect(system.displayName == "系统定位（非模拟/非外接）")
        #expect(system.flagsDescription == "模拟：否 · 外接：否")
    }

    @Test func locationDiagnosticsKeepsRawAndAcceptedLocationsSeparate() async throws {
        let timestamp = date(2026, 8, 20, 14, 20)
        let rawCallback = LocationValue(
            latitude: 31.3238,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 80,
            verticalAccuracy: 18,
            timestamp: timestamp,
            source: LocationSourceValue(
                isSimulatedBySoftware: false,
                isProducedByAccessory: false
            )
        )
        let acceptedLocation = LocationValue(
            latitude: 31.3238,
            longitude: 121.4844,
            altitude: 9.5,
            horizontalAccuracy: 20,
            verticalAccuracy: 18,
            timestamp: timestamp.addingTimeInterval(-1)
        )
        let diagnostics = LocationDiagnostics(
            latestCallback: rawCallback,
            selectedCandidate: rawCallback,
            decision: .retainedExisting,
            acceptedLocation: acceptedLocation
        )

        #expect(diagnostics.latestCallback?.latitude == rawCallback.latitude)
        #expect(diagnostics.acceptedLocation?.longitude == acceptedLocation.longitude)
        #expect(diagnostics.decision == .retainedExisting)
        #expect(rawCallback.distance(from: acceptedLocation) > 200)
    }

    @Test func locationDiagnosticsRecordsCallbackSequenceAndMapCandidateSeparately() async throws {
        let firstCallback = LocationValue(
            latitude: 31.3238,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 12,
            verticalAccuracy: 18,
            timestamp: date(2026, 8, 20, 14, 20)
        )
        let latestCallback = LocationValue(
            latitude: 31.3252,
            longitude: 121.4814,
            altitude: 9.5,
            horizontalAccuracy: 11,
            verticalAccuracy: 18,
            timestamp: date(2026, 8, 20, 14, 20).addingTimeInterval(5)
        )
        let mapCandidate = LocationMapCandidateDiagnostics(
            name: "上海北大科技园",
            address: "上海市宝山区高逸路88号",
            latitude: 31.3252,
            longitude: 121.4814,
            distance: 18,
            tier: .exact
        )
        let diagnostics = LocationDiagnostics(
            latestCallback: latestCallback,
            selectedCandidate: latestCallback,
            decision: .promoted,
            acceptedLocation: latestCallback,
            firstCallback: firstCallback,
            callbackCount: 3,
            coreGeocoderAddress: "逸景佳苑·上海市宝山区逸仙路1588弄",
            mapKitCandidate: mapCandidate
        )

        #expect(diagnostics.firstCallback == firstCallback)
        #expect(diagnostics.callbackCount == 3)
        #expect((diagnostics.firstToLatestDistance ?? 0) > 100)
        #expect(diagnostics.coreGeocoderAddress?.contains("逸景佳苑") == true)
        #expect(diagnostics.mapKitCandidate?.name == "上海北大科技园")
        #expect(diagnostics.mapKitCandidate?.distance == 18)
    }

    @Test func locationDiagnosticsRetainsRawResolverResultsAndNearbyDistances() async throws {
        let coordinate = LocationQueryCoordinateDiagnostics(
            latitude: 31.323805,
            longitude: 121.481397
        )
        let placemark = CoreGeocoderPlacemarkDiagnostics(
            name: "逸景佳苑",
            areasOfInterest: ["逸景佳苑"],
            administrativeArea: "上海市",
            locality: "上海市",
            subLocality: "宝山区",
            thoroughfare: "逸仙路",
            subThoroughfare: "1588弄",
            postalCode: nil,
            country: "中国",
            isoCountryCode: "CN"
        )
        let mapItem = LocationMapItemDiagnostics(
            name: "上海北大科技园",
            shortAddress: "上海北大科技园",
            fullAddress: "上海市宝山区高逸路88号",
            singleLineAddress: "上海北大科技园·高境镇",
            hasPOICategory: false,
            latitude: 31.3252,
            longitude: 121.4814,
            distance: 18
        )
        let diagnostics = LocationDiagnostics(
            latestCallback: nil,
            selectedCandidate: nil,
            decision: nil,
            acceptedLocation: nil,
            coreGeocoderRawResult: CoreGeocoderDiagnostics(
                status: .returned,
                coordinate: coordinate,
                placemarks: [placemark],
                formattedAddress: "逸景佳苑·上海市宝山区逸仙路1588弄",
                errorDescription: nil
            ),
            mapKitRawResult: MapKitReverseGeocodingDiagnostics(
                status: .returned,
                coordinate: coordinate,
                items: [mapItem],
                errorDescription: nil
            ),
            nearbyPOIRawResult: NearbyPOIDiagnostics(
                coordinate: coordinate,
                attempts: [
                    NearbyPOISearchDiagnostics(
                        status: .returned,
                        radius: 180,
                        items: [mapItem],
                        errorDescription: nil
                    )
                ]
            )
        )

        #expect(diagnostics.coreGeocoderRawResult?.placemarks.first?.name == "逸景佳苑")
        #expect(diagnostics.mapKitRawResult?.items.first?.name == "上海北大科技园")
        #expect(diagnostics.nearbyPOIRawResult?.attempts.first?.items.first?.distance == 18)
        #expect(diagnostics.nearbyPOIRawResult?.status == .returned)
    }

    @Test func trustedPOIRequiresDistanceConsistentWithAccuracy() async throws {
        #expect(LocationQualityPolicy.acceptsTrustedPOI(distance: 60, horizontalAccuracy: 60))
        #expect(!LocationQualityPolicy.acceptsTrustedPOI(distance: 450, horizontalAccuracy: 40))
        #expect(!LocationQualityPolicy.acceptsCachedArea(distance: 101))
        #expect(LocationQualityPolicy.acceptsCachedArea(distance: 100))
    }

    @Test func regionalPOIRequiresStrongVenueName() async throws {
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 160,
                horizontalAccuracy: 20,
                isStrongPOI: true
            ) == .regional
        )
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 160,
                horizontalAccuracy: 20,
                isStrongPOI: false
            ) == nil
        )
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 180,
                horizontalAccuracy: 20,
                isStrongPOI: true
            ) == .regional
        )
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 181,
                horizontalAccuracy: 20,
                isStrongPOI: true
            ) == nil
        )
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 360,
                horizontalAccuracy: 200,
                isStrongPOI: true
            ) == .regional
        )
        #expect(
            LocationPOISelectionPolicy.tier(
                distance: 361,
                horizontalAccuracy: 200,
                isStrongPOI: true
            ) == nil
        )
    }

    @Test func strongPOINameSurvivesAddressDeduplication() async throws {
        let candidate = MapItemValue(
            name: "上海北大科技园",
            shortAddress: "上海北大科技园",
            fullAddress: "上海北大科技园高境镇",
            singleLineAddress: "上海北大科技园高境镇",
            hasPOICategory: false,
            latitude: 31.3200,
            longitude: 121.5000
        )

        #expect(LocationService.preferredPOIName(from: candidate) == "上海北大科技园")
    }

    @Test func strongRegionalPOIBeatsACloserGenericCandidate() async throws {
        let anchor = LocationValue(
            latitude: 31.3200,
            longitude: 121.5000,
            altitude: 8.5,
            horizontalAccuracy: 20,
            verticalAccuracy: 18,
            timestamp: date(2026, 8, 20, 14, 20)
        )
        let nearbyGeneric = MapItemValue(
            name: "普通地点",
            shortAddress: nil,
            fullAddress: nil,
            singleLineAddress: nil,
            hasPOICategory: false,
            latitude: 31.3200,
            longitude: 121.5004
        )
        let regionalVenue = MapItemValue(
            name: "上海北大科技园",
            shortAddress: "上海北大科技园",
            fullAddress: "上海北大科技园高境镇",
            singleLineAddress: "上海北大科技园高境镇",
            hasPOICategory: false,
            latitude: 31.3200,
            longitude: 121.5013
        )

        let selection = LocationPOISelectionPolicy.rank(
            [
                LocationPOICandidate(item: nearbyGeneric, poiName: "普通地点"),
                LocationPOICandidate(item: regionalVenue, poiName: "上海北大科技园")
            ],
            anchor: anchor
        )

        #expect(selection?.candidate.poiName == "上海北大科技园")
        #expect(selection?.tier == .regional)
    }

    @Test func poiAddressTakesPrecedenceOverTheWeakGeocoderFallback() async throws {
        let address = LocationService.composeEnrichedAddress(
            poiName: "上海北大科技园",
            fallbackAddress: "逸景佳苑·上海市宝山区逸仙路1588弄",
            poiAddress: "上海市 高逸路88号(殷高西路地铁站2号出口步行370米)"
        )

        #expect(address.hasPrefix("上海北大科技园"))
        #expect(address.contains("高逸路88号"))
        #expect(!address.contains("逸景佳苑"))
    }

    @Test func selectedMapKitPOIIsPreferredOverCoreGeocoderFallback() async throws {
        let mapKitAddress = "上海北大科技园·高境镇"
        let fallbackAddress = "上海市宝山区高境镇殷高路 88 号"

        #expect(
            LocationService.preferredResolvedAddress(
                mapKitAddress,
                fallbackAddress: fallbackAddress,
                addressSource: .regionalPOI
            ) == mapKitAddress
        )
    }

    @Test func areaCoreGeocoderResultStillSearchesNearbyPOI() async throws {
        #expect(
            LocationService.shouldSearchNearbyPOI(
                for: nil,
                resolvedAddress: "逸景佳苑·高境镇"
            )
        )

        let selectedPOI = MapItemValue(
            name: "上海北大科技园",
            shortAddress: "上海北大科技园",
            fullAddress: "上海北大科技园高境镇",
            singleLineAddress: "上海北大科技园高境镇",
            hasPOICategory: false,
            latitude: 31.3200,
            longitude: 121.5000
        )
        #expect(
            !LocationService.shouldSearchNearbyPOI(
                for: selectedPOI,
                resolvedAddress: "上海北大科技园·高境镇"
            )
        )
    }

    @Test func weakSelectedAreaStillSearchesNearbyPOI() async throws {
        let selectedArea = MapItemValue(
            name: "逸景佳苑",
            shortAddress: "逸景佳苑",
            fullAddress: "逸景佳苑高境镇",
            singleLineAddress: "逸景佳苑高境镇",
            hasPOICategory: true,
            latitude: 31.3238,
            longitude: 121.4814
        )

        #expect(
            LocationService.shouldSearchNearbyPOI(
                for: selectedArea,
                resolvedAddress: "逸景佳苑·高境镇"
            )
        )
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
