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
                        deviceNoteCard
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
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bench 水印规则")
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
            title: "工作日规则",
            subtitle: "第一天固定记为坐班 Bench 第1天，之后再按规则累计。"
        ) {
            VStack(spacing: 14) {
                DatePicker(
                    "坐班Bench第1天",
                    selection: workStartBinding,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)

                Button("重置为今天") {
                    workStartTimestamp = Date().timeIntervalSince1970
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle("排除周末", isOn: $excludeWeekends)
                Toggle("排除中国节假日", isOn: $excludeChinaHolidays)

                Text("规则说明：首次坐班 Bench 拍照日固定记为第1天，之后再按你的设置决定是否跳过周末和节假日。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if excludeChinaHolidays && !holidayProvider.supportsHolidayExclusion {
                    Text("当前版本尚未内置节假日表，后续接入后该开关才会真正影响计算结果。")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var attendanceCard: some View {
        settingsCard(
            title: "上下班状态",
            subtitle: "默认 09:00 前按上班，18:00 起按下班。"
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

                Text("当前规则：下班时间之前统一按“上班”处理，到达或晚于下班时间按“下班”处理。")
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
                Picker("水印位置", selection: $watermarkPositionRawValue) {
                    ForEach(WatermarkPosition.allCases) { position in
                        Text(position.displayName).tag(position.rawValue)
                    }
                }
                .pickerStyle(.segmented)

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

                HStack(spacing: 10) {
                    smallStatChip(title: "位置", value: WatermarkPosition(rawValue: watermarkPositionRawValue)?.displayName ?? "左下")
                    smallStatChip(title: "字号", value: "\(Int(watermarkFontSize))")
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
}

#Preview {
    SettingsView()
}
