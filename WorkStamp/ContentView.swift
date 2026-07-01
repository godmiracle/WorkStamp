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
    @AppStorage(AppSettingKeys.workStartTimestamp) private var workStartTimestamp = 0.0
    @AppStorage(AppSettingKeys.excludeWeekends) private var excludeWeekends = true
    @AppStorage(AppSettingKeys.excludeChinaHolidays) private var excludeChinaHolidays = false
    @AppStorage(AppSettingKeys.watermarkPosition) private var watermarkPositionRawValue = WatermarkPosition.bottomLeft.rawValue
    @AppStorage(AppSettingKeys.watermarkFontSize) private var watermarkFontSize = 16.0
    @AppStorage(AppSettingKeys.onDutyMinutes) private var onDutyMinutes = AttendanceStatusResolver.defaultOnDutyMinutes
    @AppStorage(AppSettingKeys.offDutyMinutes) private var offDutyMinutes = AttendanceStatusResolver.defaultOffDutyMinutes
    @StateObject private var cameraService = CameraService()
    @StateObject private var locationService = LocationService()
    @State private var isWatermarkEnabled = true
    @State private var showSettings = false
    @State private var showRecentCapturePreview = false
    @State private var bannerMessage: String?
    @State private var isSavingPhoto = false
    @State private var recentCapturedImage: UIImage?

    private let holidayProvider = ChinaHolidayProvider()

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
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    Spacer()

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
                        .padding(.bottom, 18)
                    }

                    bottomControlPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
            .background(appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
                cameraService.start()
                locationService.start()
            }
            .onDisappear {
                cameraService.stop()
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
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(canCapturePhoto ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(previewTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text(previewSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var watermarkOverlay: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 7) {
                Text(DateFormatter.workStampTimestamp.string(from: timeline.date))
                    .font(.system(size: watermarkFontSize + 6, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 8, y: 2)

                overlayRow(title: "状态", value: attendanceStatusValue(for: timeline.date))
                overlayRow(title: "经纬度", value: coordinateValue(from: locationService.snapshot))
                overlayRow(title: "地点", value: locationService.snapshot.address ?? "定位中或不可用")
                overlayRow(title: "海拔", value: altitudeValue(from: locationService.snapshot))
                overlayRow(title: "Bench", value: workdayLabel(for: timeline.date))
            }
        }
    }

    private func overlayRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: max(12, watermarkFontSize - 1), weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(.system(size: max(13, watermarkFontSize), weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.55), radius: 8, y: 2)

            Spacer(minLength: 0)
        }
    }

    private var bottomControlPanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                compactInfoChip(
                    icon: "mappin.and.ellipse",
                    title: "位置",
                    value: watermarkPosition.displayName
                )

                compactInfoChip(
                    icon: "textformat.size",
                    title: "字号",
                    value: "\(Int(watermarkFontSize))"
                )

                compactInfoChip(
                    icon: isWatermarkEnabled ? "checkmark.seal.fill" : "slash.circle",
                    title: "水印",
                    value: isWatermarkEnabled ? "开启" : "关闭"
                )
            }

            controlPills

            HStack(alignment: .center, spacing: 18) {
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

                Button {
                    cameraService.switchCamera()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: cameraService.activePosition == .back ? "camera.rotate.fill" : "camera.rotate")
                            .font(.system(size: 22, weight: .semibold))
                        Text(cameraService.activePosition == .back ? "前置" : "后置")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(.regularMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!cameraService.canSwitchCamera)
                .opacity(cameraService.canSwitchCamera ? 1 : 0.65)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var controlPills: some View {
        HStack(spacing: 10) {
            Button {
                isWatermarkEnabled.toggle()
            } label: {
                controlPill(
                    icon: isWatermarkEnabled ? "checkmark.seal.fill" : "slash.circle",
                    text: isWatermarkEnabled ? "水印已开" : "水印已关",
                    tint: isWatermarkEnabled ? .orange : .white
                )
            }
            .buttonStyle(.plain)

            controlPill(
                icon: "location.fill",
                text: locationService.snapshot.quality.displayName,
                tint: locationQualityTint
            )

            statusBadge

            Text(workdayLabel(for: Date()))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10), in: Capsule())

            if showHolidayWarning {
                controlPill(
                    icon: "exclamationmark.triangle.fill",
                    text: "节假日未生效",
                    tint: .orange
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBadge: some View {
        Text(attendanceStatusValue(for: Date()))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(attendanceTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(attendanceTint.opacity(0.14), in: Capsule())
    }

    private func controlPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var attendanceTint: Color {
        AttendanceStatusResolver.resolve(
            for: Date(),
            onDutyMinutes: onDutyMinutes,
            offDutyMinutes: offDutyMinutes
        ) == .onDuty ? Color.green : Color.orange
    }

    private var locationQualityTint: Color {
        switch locationService.snapshot.quality {
        case .stable:
            return .green
        case .approximate:
            return .orange
        case .searching:
            return .white
        }
    }

    private func compactInfoChip(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func workdayLabel(for date: Date) -> String {
        guard let startDate else {
            return "未设置坐班Bench第1天"
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
            return "Bench天数计算不可用"
        }

        return "坐班Bench第\(dayNumber)天"
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
        !isSavingPhoto
    }

    private var previewTitle: String {
        if cameraService.authorizationStatus != .authorized {
            return "等待相机权限"
        }

        if cameraService.isConfigured {
            return "WorkStamp 已就绪"
        }

        return "正在准备相机"
    }

    private var previewSubtitle: String {
        if cameraService.authorizationStatus != .authorized {
            return "请允许相机权限后再进行真机拍照。"
        }

        if cameraService.isConfigured {
            return "拍照后自动叠加水印，并写入照片时间与定位信息。"
        }

        return "正在建立相机会话，请稍候。"
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

        isSavingPhoto = true
        locationService.refreshOneShot()
        let captureDate = Date()
        let snapshot = locationService.currentSnapshot()

        do {
            let originalImage = try await captureImage()

            if workStartTimestamp == 0 {
                workStartTimestamp = captureDate.timeIntervalSince1970
            }

            let imageToSave: UIImage

            if isWatermarkEnabled {
                imageToSave = WatermarkRenderer.render(
                    image: originalImage,
                    payload: WatermarkRenderPayload(
                        timestamp: captureDate,
                        snapshot: snapshot,
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
                captureDate: captureDate,
                location: snapshot.photoAssetLocation
            )
            recentCapturedImage = imageToSave
            bannerMessage = "带水印照片已保存到相册。"
        } catch {
            bannerMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isSavingPhoto = false
    }

    private func captureImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            cameraService.capturePhoto { result in
                continuation.resume(with: result)
            }
        }
    }

    private func saveToPhotoLibrary(
        _ image: UIImage,
        captureDate: Date,
        location: CLLocation?
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PhotoLibrarySaver.save(
                image,
                captureDate: captureDate,
                location: location
            ) { result in
                continuation.resume(with: result)
            }
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
