//
//  ContentView.swift
//  WorkStamp
//
//  Created by CJ on 2026/7/1.
//

import AVFoundation
import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettingKeys.workStartTimestamp) private var workStartTimestamp = 0.0
    @AppStorage(AppSettingKeys.excludeWeekends) private var excludeWeekends = true
    @AppStorage(AppSettingKeys.excludeChinaHolidays) private var excludeChinaHolidays = false
    @AppStorage(AppSettingKeys.watermarkPosition) private var watermarkPositionRawValue = WatermarkPosition.bottomLeft.rawValue
    @AppStorage(AppSettingKeys.watermarkFontSize) private var watermarkFontSize = 16.0
    @AppStorage(AppSettingKeys.onDutyMinutes) private var onDutyMinutes = AttendanceStatusResolver.defaultOnDutyMinutes
    @AppStorage(AppSettingKeys.offDutyMinutes) private var offDutyMinutes = AttendanceStatusResolver.defaultOffDutyMinutes
    @AppStorage(AppSettingKeys.workdayTemplateName) private var workdayTemplateName = "Bench"
    @AppStorage(AppSettingKeys.workdayPrefixMigrationVersion) private var workdayPrefixMigrationVersion = 0
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()
    @State private var isWatermarkEnabled = true
    @State private var showSettings = false
    @State private var showRecentCapturePreview = false
    @State private var showWatermarkPanel = false
    @State private var showLocationPanel = false
    @State private var showTemplatePanel = false
    @State private var bannerMessage: String?
    @State private var isSavingPhoto = false
    @State private var recentCapturedImage: UIImage?
    @State private var showGrid = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    @State private var timerMode: CaptureTimerMode = .off
    @State private var countdownValue: Int?

    private let holidayProvider = ChinaHolidayProvider()

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    private var watermarkPosition: WatermarkPosition {
        WatermarkPosition(rawValue: watermarkPositionRawValue) ?? .bottomLeft
    }

    private var startDate: Date? {
        guard workStartTimestamp > 0 else {
            return nil
        }

        return Date(timeIntervalSince1970: workStartTimestamp)
    }

    private var showHolidayWarning: Bool {
        excludeChinaHolidays && !holidayProvider.supportsHolidayExclusion
    }

    var body: some View {
        NavigationStack {
            ZStack {
                cameraSurface

                VStack(spacing: 0) {
                    topControls
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                    Spacer()

                    if let countdownValue {
                        countdownOverlay(value: countdownValue)
                            .padding(.bottom, 20)
                    }

                    previewStatusOverlay
                        .padding(.horizontal, 18)
                        .padding(.bottom, 22)

                    if isWatermarkEnabled {
                        HStack {
                            if watermarkPosition.overlayAlignment == .topTrailing || watermarkPosition.overlayAlignment == .bottomTrailing {
                                Spacer(minLength: 0)
                            }

                            watermarkOverlay
                                .frame(maxWidth: 320)

                            if watermarkPosition.overlayAlignment == .topLeading || watermarkPosition.overlayAlignment == .bottomLeading {
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 26)
                    }

                    bottomControlPanel
                        .padding(.bottom, 10)
                }
            }
            .background(appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showWatermarkPanel) {
                QuickWatermarkPanel(
                    isWatermarkEnabled: $isWatermarkEnabled,
                    watermarkPositionRawValue: $watermarkPositionRawValue,
                    watermarkFontSize: $watermarkFontSize
                )
                .presentationDetents([.fraction(0.34), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLocationPanel) {
                QuickLocationPanel(
                    snapshot: locationService.snapshot,
                    qualityTitle: locationQualityTitle,
                    qualityTint: locationQualityTint,
                    isRefreshing: locationService.isRefreshing
                ) {
                    refreshLocationFromUI()
                }
                .presentationDetents([.fraction(0.36), .medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTemplatePanel) {
                QuickTemplatePanel(workdayTemplateName: $workdayTemplateName)
                    .presentationDetents([.fraction(0.34), .medium])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showRecentCapturePreview) {
                if let recentCapturedImage {
                    CapturedPhotoPreview(
                        image: recentCapturedImage,
                        isPresented: $showRecentCapturePreview
                    )
                }
            }
            .task {
                migrateWorkdayPrefixIfNeeded()
                guard !isUITesting else { return }
                cameraService.start()
                locationService.start()
            }
            .onDisappear {
                cameraService.stop()
                locationService.stop()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard !isUITesting else { return }

                switch newPhase {
                case .active:
                    cameraService.start()
                    locationService.start()
                case .inactive, .background:
                    cameraService.stop()
                    locationService.stop()
                @unknown default:
                    break
                }
            }
            .onChange(of: showSettings) { _, isPresented in
                guard !isPresented else { return }
                locationService.refreshAuthorizationStatus()
            }
            .alert("提示", isPresented: Binding(
                get: { bannerMessage != nil },
                set: { if !$0 { bannerMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {
                    bannerMessage = nil
                }
            } message: {
                Text(bannerMessage ?? "")
            }
            .onChange(of: cameraService.errorMessage) { _, newValue in
                guard let newValue else { return }
                bannerMessage = newValue
            }
            .onChange(of: locationService.errorMessage) { _, newValue in
                guard let newValue else { return }
                bannerMessage = newValue
            }
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.08, blue: 0.12),
                Color(red: 0.13, green: 0.18, blue: 0.24),
                Color(red: 0.30, green: 0.19, blue: 0.13)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var cameraSurface: some View {
        ZStack {
            Group {
                if cameraService.authorizationStatus == .authorized && cameraService.isConfigured {
                    CameraPreviewView(session: cameraService.session)
                } else {
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color(red: 0.12, green: 0.15, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: 130, y: 280)

            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: -140, y: -260)

            if showGrid {
                gridOverlay
            }
        }
        .ignoresSafeArea()
    }

    private var topControls: some View {
        HStack(spacing: 14) {
            topToolButton(icon: "gearshape", accessibilityIdentifier: "camera.settingsButton") {
                showSettings = true
            }

            Spacer(minLength: 0)

            topToolButton(icon: showGrid ? "square.grid.3x3.fill" : "square.grid.3x3") {
                showGrid.toggle()
            }

            topToolButton(
                icon: flashIconName,
                isHighlighted: flashMode != .off,
                isEnabled: cameraService.isFlashAvailable
            ) {
                cycleFlashMode()
            }

            topToolButton(icon: timerMode.iconName, isHighlighted: timerMode != .off) {
                cycleTimerMode()
            }
        }
    }

    private var watermarkOverlay: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 7) {
                overlayRow(
                    title: "时间",
                    value: DateFormatter.workStampTimestamp.string(from: timeline.date),
                    symbol: "clock"
                )
                overlayRow(
                    title: "状态",
                    value: attendanceStatusValue(for: timeline.date),
                    symbol: "person.badge.clock"
                )
                overlayRow(
                    title: "地点",
                    value: locationService.snapshot.previewAddressText,
                    symbol: "mappin.and.ellipse"
                )
                overlayRow(
                    title: "经纬度",
                    value: coordinateValue(from: locationService.snapshot),
                    symbol: "globe"
                )
                overlayRow(
                    title: "海拔",
                    value: altitudeValue(from: locationService.snapshot),
                    symbol: "mountain.2"
                )
                overlayRow(
                    title: "备注",
                    value: workdayLabel(for: timeline.date),
                    symbol: "calendar"
                )
            }
        }
    }

    private func overlayRow(title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: max(12, watermarkFontSize - 1), weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18, alignment: .leading)

            Text(title)
                .font(.system(size: max(12, watermarkFontSize - 1), weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.system(size: max(13, watermarkFontSize), weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.55), radius: 8, y: 2)

            Spacer(minLength: 0)
        }
    }

    private var bottomControlPanel: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 30) {
                Button {
                    guard recentCapturedImage != nil else { return }
                    showRecentCapturePreview = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let recentCapturedImage {
                                Image(uiImage: recentCapturedImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.14))

                                Image(systemName: "photo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.45), in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(recentCapturedImage == nil)
                .opacity(recentCapturedImage == nil ? 0.7 : 1)

                Button {
                    Task {
                        await captureAndSave()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.orange,
                                        Color(red: 0.99, green: 0.48, blue: 0.27)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Circle()
                            .stroke(Color.white.opacity(0.82), lineWidth: 4)
                            .padding(7)

                        VStack(spacing: 4) {
                            Image(systemName: isSavingPhoto ? "arrow.down.circle.fill" : "camera.fill")
                                .font(.system(size: 26, weight: .bold))
                            Text(isSavingPhoto ? "保存中" : "拍照")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: 112, height: 112)
                    .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
                }
                .disabled(!canCapturePhoto)
                .opacity(canCapturePhoto ? 1 : 0.66)
                .accessibilityIdentifier("camera.captureButton")

                Button {
                    cameraService.switchCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(.regularMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!cameraService.canSwitchCamera)
                .opacity(cameraService.canSwitchCamera ? 1 : 0.65)
            }

            HStack(spacing: 12) {
                cameraModePill(
                    icon: "location",
                    title: "地点",
                    isHighlighted: locationService.snapshot.quality == .stable
                ) {
                    refreshLocationFromUI()
                    showLocationPanel = true
                }

                cameraModePill(
                    icon: isWatermarkEnabled ? "calendar.badge.clock" : "calendar.badge.minus",
                    title: "水印",
                    isHighlighted: isWatermarkEnabled
                ) {
                    showWatermarkPanel = true
                }

                cameraModePill(
                    icon: "square.grid.2x2",
                    title: "模板",
                    isHighlighted: true
                ) {
                    showTemplatePanel = true
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func topToolButton(
        icon: String,
        isHighlighted: Bool = false,
        isEnabled: Bool = true,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isHighlighted ? Color.yellow : .white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(isHighlighted ? 0.48 : 0.36), in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isHighlighted ? 0.28 : 0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }

    private func cameraModePill(
        icon: String,
        title: String,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isHighlighted ? Color.yellow : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(isHighlighted ? 0.14 : 0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isHighlighted ? 0.24 : 0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var previewStatusOverlay: some View {
        HStack {
            locationStatusChip
            Spacer(minLength: 0)
        }
    }

    private var locationStatusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(locationQualityTint)
                .frame(width: 7, height: 7)

            Text(canCapturePhoto ? locationQualityTitle : "准备中")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.28), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func workdayLabel(for date: Date) -> String {
        guard let startDate else {
            return "未设置\(workdayPhrase(dayNumber: 1))"
        }

        let options = WorkdayCalculationOptions(
            excludeWeekends: excludeWeekends,
            excludeChinaHolidays: excludeChinaHolidays
        )

        guard let dayNumber = WorkdayCalculator.workdayNumber(
            from: startDate,
            to: date,
            options: options,
            holidayProvider: holidayProvider
        ) else {
            return "\(workdayTemplateDisplayName)天数计算不可用"
        }

        return workdayPhrase(dayNumber: dayNumber)
    }

    private var workdayTemplateDisplayName: String {
        WorkdayPrefixFormatter.displayPrefix(from: workdayTemplateName)
    }

    private func workdayPhrase(dayNumber: Int) -> String {
        WorkdayPrefixFormatter.phrase(prefix: workdayTemplateName, dayNumber: dayNumber)
    }

    private func migrateWorkdayPrefixIfNeeded() {
        guard workdayPrefixMigrationVersion < WorkdayPrefixFormatter.currentMigrationVersion else {
            return
        }

        workdayTemplateName = WorkdayPrefixFormatter.migratedPrefix(from: workdayTemplateName)
        workdayPrefixMigrationVersion = WorkdayPrefixFormatter.currentMigrationVersion
    }

    private func attendanceStatusText(for date: Date) -> String {
        "状态：\(attendanceStatusValue(for: date))"
    }

    private func attendanceStatusValue(for date: Date) -> String {
        let status = AttendanceStatusResolver.resolve(
            for: date,
            onDutyMinutes: onDutyMinutes,
            offDutyMinutes: offDutyMinutes
        )

        return status.displayName
    }

    private var canCapturePhoto: Bool {
        cameraService.authorizationStatus == .authorized &&
        cameraService.isConfigured &&
        !cameraService.isCapturing &&
        !isSavingPhoto &&
        countdownValue == nil
    }

    private var flashIconName: String {
        switch flashMode {
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.a.fill"
        case .off:
            return "bolt.slash"
        @unknown default:
            return "bolt.slash"
        }
    }

    private var locationQualityTitle: String {
        switch locationService.snapshot.quality {
        case .stable:
            return "定位稳定"
        case .approximate:
            return "定位一般"
        case .searching:
            return "定位中"
        }
    }

    private var locationQualityTint: Color {
        switch locationService.snapshot.quality {
        case .stable:
            return .green
        case .approximate:
            return .orange
        case .searching:
            return .white.opacity(0.8)
        }
    }

    private func countdownOverlay(value: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: 92, height: 92)

            Text("\(value)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func cycleFlashMode() {
        guard cameraService.isFlashAvailable else {
            bannerMessage = "当前镜头不支持闪光灯。"
            return
        }

        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
    }

    private func cycleTimerMode() {
        timerMode = timerMode.next
    }

    private var gridOverlay: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height

                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
            }
            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }

    private func coordinateText(from snapshot: LocationSnapshot) -> String {
        "经纬度：\(coordinateValue(from: snapshot))"
    }

    private func coordinateValue(from snapshot: LocationSnapshot) -> String {
        guard let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return "定位中或不可用"
        }

        return "\(latitude.workStampCoordinateString), \(longitude.workStampCoordinateString)"
    }

    private func altitudeText(from snapshot: LocationSnapshot) -> String {
        "海拔：\(altitudeValue(from: snapshot))"
    }

    private func altitudeValue(from snapshot: LocationSnapshot) -> String {
        guard let altitude = snapshot.altitude else {
            return "不可用"
        }

        return "\(altitude.workStampAltitudeString)m"
    }

    @MainActor
    private func captureAndSave() async {
        guard canCapturePhoto else {
            bannerMessage = "相机尚未准备好，请稍后重试。"
            return
        }

        if timerMode.delaySeconds > 0 {
            for value in stride(from: timerMode.delaySeconds, through: 1, by: -1) {
                guard !Task.isCancelled else {
                    countdownValue = nil
                    return
                }

                countdownValue = value
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    countdownValue = nil
                    return
                }
            }
            countdownValue = nil
        }

        isSavingPhoto = true
        let captureDate = Date()
        let cachedSnapshot = locationService.snapshot
        let locationTask = Task { @MainActor in
            await locationService.refreshOneShotForCapture()
        }

        defer {
            locationTask.cancel()
            countdownValue = nil
            isSavingPhoto = false
        }

        do {
            let originalImage = try await captureImage()
            let locationResult = await locationTask.value
            let snapshot = CaptureLocationResolver.resolve(
                result: locationResult,
                cachedSnapshot: cachedSnapshot,
                referenceDate: captureDate
            )

            let captureContext = CaptureContext(
                captureDate: captureDate,
                locationSnapshot: snapshot
            )

            if workStartTimestamp == 0 {
                workStartTimestamp = captureDate.timeIntervalSince1970
            }

            let imageToSave: UIImage

            if isWatermarkEnabled {
                imageToSave = WatermarkRenderer.render(
                    image: originalImage,
                    payload: WatermarkRenderPayload(
                        timestamp: captureContext.captureDate,
                        snapshot: captureContext.locationSnapshot,
                        attendanceStatus: attendanceStatusText(for: captureDate),
                        workdayLabel: workdayLabel(for: captureDate),
                        fontSize: watermarkFontSize,
                        position: watermarkPosition
                    )
                )
            } else {
                imageToSave = originalImage
            }

            try await saveToPhotoLibrary(
                imageToSave,
                context: captureContext
            )
            try Task.checkCancellation()
            recentCapturedImage = imageToSave
            bannerMessage = "带水印照片已保存到相册。"
        } catch {
            if !Task.isCancelled {
                bannerMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func captureImage() async throws -> UIImage {
        let cameraService = cameraService
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                cameraService.capturePhoto(flashMode: flashMode) { result in
                    continuation.resume(with: result)
                }
            }
        }, onCancel: {
            Task { @MainActor in
                cameraService.cancelCapture()
            }
        })
    }

    private func saveToPhotoLibrary(
        _ image: UIImage,
        context: CaptureContext
    ) async throws {
        try await PhotoLibrarySaver.save(
            image,
            captureDate: context.captureDate,
            location: context.photoAssetLocation
        )
    }

    private func refreshLocationFromUI() {
        Task { @MainActor in
            let result = await locationService.refreshOneShot()
            guard case let .failure(error) = result,
                  error != .timedOut,
                  error != .cancelled else {
                return
            }
            bannerMessage = error.errorDescription
        }
    }
}

private enum CaptureTimerMode: Int, CaseIterable {
    case off
    case threeSeconds
    case fiveSeconds

    var delaySeconds: Int {
        switch self {
        case .off:
            return 0
        case .threeSeconds:
            return 3
        case .fiveSeconds:
            return 5
        }
    }

    var iconName: String {
        switch self {
        case .off:
            return "timer"
        case .threeSeconds:
            return "3.circle"
        case .fiveSeconds:
            return "5.circle"
        }
    }

    var next: CaptureTimerMode {
        switch self {
        case .off:
            return .threeSeconds
        case .threeSeconds:
            return .fiveSeconds
        case .fiveSeconds:
            return .off
        }
    }
}

private struct QuickLocationPanel: View {
    let snapshot: LocationSnapshot
    let qualityTitle: String
    let qualityTint: Color
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("地点")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(qualityTint)
                            .frame(width: 8, height: 8)

                        Text(qualityTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                }

                locationRow(title: "地址", value: snapshot.detailAddressText)
                locationRow(title: "经纬度", value: coordinateValue)
                locationRow(title: "海拔", value: altitudeValue)
                locationRow(title: "精度", value: accuracyValue)

                Button {
                    onRefresh()
                } label: {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .tint(.orange)
                        } else {
                            Image(systemName: "location.fill")
                        }

                        Text(isRefreshing ? "定位刷新中" : "重新定位")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)

                Text("点这里的意义，是在拍照前快速确认当前位置和定位精度，不用等拍完再去照片详情页里查。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
        }
    }

    private func locationRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    private var coordinateValue: String {
        guard let latitude = snapshot.latitude,
              let longitude = snapshot.longitude else {
            return "定位中或不可用"
        }

        return "\(latitude.workStampCoordinateString), \(longitude.workStampCoordinateString)"
    }

    private var altitudeValue: String {
        guard let altitude = snapshot.altitude else {
            return "不可用"
        }

        return "\(altitude.workStampAltitudeString)m"
    }

    private var accuracyValue: String {
        guard let accuracy = snapshot.horizontalAccuracy else {
            return "不可用"
        }

        return "约 ±\(Int(accuracy.rounded()))m"
    }
}

private struct QuickWatermarkPanel: View {
    @Binding var isWatermarkEnabled: Bool
    @Binding var watermarkPositionRawValue: String
    @Binding var watermarkFontSize: Double

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("水印")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Toggle("启用水印", isOn: $isWatermarkEnabled)

                VStack(alignment: .leading, spacing: 12) {
                    Text("水印位置")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    WatermarkPositionGrid(selection: $watermarkPositionRawValue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("字号")
                        Spacer()
                        Text("\(Int(watermarkFontSize))")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $watermarkFontSize, in: 12...28, step: 1)
                        .tint(.orange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("字号实时预览")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    ZStack(alignment: (WatermarkPosition(rawValue: watermarkPositionRawValue) ?? .bottomLeft).overlayAlignment) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 132)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("2026-07-02 15:53:12")
                                .font(.system(size: watermarkFontSize, weight: .bold, design: .rounded))
                            Text(WorkdayPrefixFormatter.phrase(prefix: "坐班Bench", dayNumber: 12))
                                .font(.system(size: max(12, watermarkFontSize - 1), weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
        }
    }
}

private struct QuickTemplatePanel: View {
    @Binding var workdayTemplateName: String

    private var templateDisplayName: String {
        WorkdayPrefixFormatter.displayPrefix(from: workdayTemplateName)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("模板")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                VStack(alignment: .leading, spacing: 10) {
                    Text("工作天数前缀")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    TextField("例如 坐班Bench、巡检、实习", text: $workdayTemplateName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("预览效果")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(templateDisplayName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Text(WorkdayPrefixFormatter.phrase(prefix: workdayTemplateName, dayNumber: 12))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Text("现在会把“第 X 天”前面的整段文案都放开，你可以直接改成自己的现场描述。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
        }
    }
}

private struct CapturedPhotoPreview: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }
}

#Preview {
    ContentView()
}
