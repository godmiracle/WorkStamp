//
//  SettingsView.swift
//  WorkStamp
//
//  Created by Codex on 2026/7/1.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettingKeys.workStartTimestamp) private var workStartTimestamp = 0.0
    @AppStorage(AppSettingKeys.excludeWeekends) private var excludeWeekends = true
    @AppStorage(AppSettingKeys.excludeChinaHolidays) private var excludeChinaHolidays = false
    @AppStorage(AppSettingKeys.watermarkPosition) private var watermarkPositionRawValue = WatermarkPosition.bottomLeft.rawValue
    @AppStorage(AppSettingKeys.watermarkFontSize) private var watermarkFontSize = 16.0
    @AppStorage(AppSettingKeys.onDutyMinutes) private var onDutyMinutes = AttendanceStatusResolver.defaultOnDutyMinutes
    @AppStorage(AppSettingKeys.offDutyMinutes) private var offDutyMinutes = AttendanceStatusResolver.defaultOffDutyMinutes
    @AppStorage(AppSettingKeys.workdayTemplateName) private var workdayTemplateName = "Bench"
    @AppStorage(AppSettingKeys.workdayPrefixMigrationVersion) private var workdayPrefixMigrationVersion = 0
    @State private var showResetConfirmation = false

    private let holidayProvider = ChinaHolidayProvider()

    private var workStartBinding: Binding<Date> {
        Binding {
            if workStartTimestamp > 0 {
                Date(timeIntervalSince1970: workStartTimestamp)
            } else {
                Date()
            }
        } set: { newValue in
            workStartTimestamp = newValue.timeIntervalSince1970
        }
    }

    private var onDutyBinding: Binding<Date> {
        Binding {
            AttendanceStatusResolver.timeDate(from: onDutyMinutes)
        } set: { newValue in
            onDutyMinutes = AttendanceStatusResolver.minutes(from: newValue)
        }
    }

    private var offDutyBinding: Binding<Date> {
        Binding {
            AttendanceStatusResolver.timeDate(from: offDutyMinutes)
        } set: { newValue in
            offDutyMinutes = AttendanceStatusResolver.minutes(from: newValue)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        headerCard
                        workdayCard
                        attendanceCard
                        watermarkCard
                        holidayNoteCard
#if DEBUG
                        deviceNoteCard
#endif
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                migrateWorkdayPrefixIfNeeded()
            }
            .alert("确认重置", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("重置为今天", role: .destructive) {
                    workStartTimestamp = Date().timeIntervalSince1970
                }
            } message: {
                Text("会把工作第一天重置为今天，之后的工作天数将从今天重新开始计算。")
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工作天数设置")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text("这里控制工作天数、上下班判断和水印排版。首页只负责快速拍照，细节统一收在这里。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
    }

    private var workdayCard: some View {
        settingsCard(
            title: "记录规则",
            subtitle: "第一天固定记为\(workdayPhrase(dayNumber: 1))，之后再按规则累计。"
        ) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("工作天数前缀")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    TextField("例如 坐班Bench、巡检、实习", text: $workdayTemplateName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    settingPreviewCard(
                        title: "实时预览",
                        lines: [
                            ("calendar", workdayPhrase(dayNumber: 12))
                        ]
                    )
                }

                DatePicker(
                    "\(workdayPhrase(dayNumber: 1))",
                    selection: workStartBinding,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                Button("重置为今天") {
                    showResetConfirmation = true
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle("排除周末", isOn: $excludeWeekends)
                Toggle("排除中国法定节假日", isOn: $excludeChinaHolidays)

                Text("规则说明：首次拍照日固定记为\(workdayPhrase(dayNumber: 1))，之后再按你的设置决定是否跳过周末和节假日。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workdayTemplateDisplayName: String {
        WorkdayPrefixFormatter.displayPrefix(from: workdayTemplateName)
    }

    private func workdayPhrase(dayNumber: Int) -> String {
        WorkdayPrefixFormatter.phrase(prefix: workdayTemplateName, dayNumber: dayNumber)
    }

    private var attendanceCard: some View {
        settingsCard(
            title: "上下班状态",
            subtitle: "默认 09:00 前为上班前，09:00 起上班，18:00 起下班。"
        ) {
            VStack(spacing: 14) {
                DatePicker(
                    "上班时间",
                    selection: onDutyBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                DatePicker(
                    "下班时间",
                    selection: offDutyBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)

                HStack(spacing: 10) {
                    smallStatChip(title: "上班", value: DateFormatter.workStampTimeOnly.string(from: onDutyBinding.wrappedValue))
                    smallStatChip(title: "下班", value: DateFormatter.workStampTimeOnly.string(from: offDutyBinding.wrappedValue))
                }

                Text("当前规则：上班时间之前为“上班前”，到达上班时间后且早于下班时间为“上班”，到达或晚于下班时间为“下班”。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var watermarkCard: some View {
        settingsCard(
            title: "水印样式",
            subtitle: "控制预览和最终照片里文字块的位置与尺寸。"
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("水印位置")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    WatermarkPositionGrid(selection: $watermarkPositionRawValue)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("水印字号")
                        Spacer()
                        Text("\(Int(watermarkFontSize))")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $watermarkFontSize, in: 12...28, step: 1)
                        .tint(.orange)
                }

                settingPreviewCard(
                    title: "字号实时预览",
                    fontSize: watermarkFontSize,
                    alignment: WatermarkPosition(rawValue: watermarkPositionRawValue) ?? .bottomLeft,
                    lines: [
                        ("clock", "2026-07-02 15:53:12"),
                        ("calendar", workdayPhrase(dayNumber: 12))
                    ]
                )

                HStack(spacing: 10) {
                    smallStatChip(title: "位置", value: WatermarkPosition(rawValue: watermarkPositionRawValue)?.displayName ?? "左下")
                    smallStatChip(title: "字号", value: "\(Int(watermarkFontSize))")
                }
            }
        }
    }

    private var holidayNoteCard: some View {
        settingsCard(
            title: "节假日说明",
            subtitle: "当前版本内置 2026 年中国法定节假日与调休规则。"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                noteRow(text: "工作第一天始终固定记为第 1 天，不会被周末或节假日过滤掉。")

                if holidayProvider.supportsHolidayExclusion {
                    noteRow(text: "当前版本已写死 2026 年中国法定节假日放假日。")
                    noteRow(text: "同时已加入 2026 年调休上班日，避免把需要上班的周末误排除。")
                    noteRow(text: "后续年份需要跟随官方安排继续补本地规则。")
                } else {
                    noteRow(text: "“排除中国节假日”开关目前仅保留设置入口，正式节假日表后续接入后才会实际影响计算结果。")
                }
            }
        }
    }

    private var deviceNoteCard: some View {
        settingsCard(
            title: "真机测试提示",
            subtitle: "当前阶段以 iPhone 真机测试为准。"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                noteRow(text: "相机、定位、海拔和相册保存不以模拟器结果作为验收标准。")
                noteRow(text: "需要重点验证权限授权、地址反查速度、海拔可用性，以及照片详情页的位置地图。")
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private func smallStatChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func noteRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func migrateWorkdayPrefixIfNeeded() {
        guard workdayPrefixMigrationVersion < WorkdayPrefixFormatter.currentMigrationVersion else {
            return
        }

        workdayTemplateName = WorkdayPrefixFormatter.migratedPrefix(from: workdayTemplateName)
        workdayPrefixMigrationVersion = WorkdayPrefixFormatter.currentMigrationVersion
    }

    private func settingPreviewCard(
        title: String,
        fontSize: Double = 16,
        alignment: WatermarkPosition = .bottomLeft,
        lines: [(String, String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ZStack(alignment: alignment.overlayAlignment) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.13, blue: 0.18),
                                Color(red: 0.23, green: 0.27, blue: 0.33)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 156)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: line.0)
                                .font(.system(size: max(11, fontSize - 2), weight: .semibold))
                            Text(line.1)
                                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        }
    }
}

#Preview {
    SettingsView()
}
