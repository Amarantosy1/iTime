import Charts
import SwiftUI
import UIKit

struct iOSOverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                rangeSection

                if model.authorizationState == .authorized {
                    if let overview = model.overview, !overview.buckets.isEmpty {
                        metricsSection(overview)
                        trendSection(overview)
                        distributionSection(overview)
                    } else {
                        Section {
                            Text("当前时间范围内没有可统计的日程。")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        Text(authorizationHint)
                            .foregroundStyle(.secondary)
                        Button("请求权限") {
                            Task { await model.requestAccessIfNeeded() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("统计")
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
        }
    }

    private var rangeSection: some View {
        Section("统计范围") {
            Picker(
                "统计周期",
                selection: Binding(
                    get: { model.liveSelectedRange },
                    set: { newValue in
                        Task { await model.setRange(newValue) }
                    }
                )
            ) {
                ForEach(TimeRangePreset.overviewCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            
            if model.liveSelectedRange == .custom {
                customDateRangeControls
            }
        }
    }

    @ViewBuilder
    private var customDateRangeControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CustomDateRangePreset.allCases, id: \.self) { preset in
                    Button(preset.title) {
                        Task { await model.setCustomDateRange(preset: preset) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

        DatePicker(
            "开始日期",
            selection: Binding(
                get: { model.preferences.customStartDate },
                set: { newValue in
                    Task {
                        await model.setCustomDateRange(
                            start: newValue,
                            end: model.preferences.customEndDate
                        )
                    }
                }
            ),
            displayedComponents: .date
        )

        DatePicker(
            "结束日期",
            selection: Binding(
                get: { model.preferences.customEndDate },
                set: { newValue in
                    Task {
                        await model.setCustomDateRange(
                            start: model.preferences.customStartDate,
                            end: newValue
                        )
                    }
                }
            ),
            displayedComponents: .date
        )
    }

    private func metricsSection(_ overview: TimeOverview) -> some View {
        Section("关键指标") {
            LabeledContent("总时长", value: overview.totalDuration.formattedDuration)
            LabeledContent("事件数", value: "\(overview.totalEventCount)")
            LabeledContent("日均时长", value: overview.averageDailyDuration.formattedDuration)
            LabeledContent("最长单日", value: overview.longestDayDuration.formattedDuration)
        }
    }

    private func trendSection(_ overview: TimeOverview) -> some View {
        Section(trendTitle(for: overview.stackedBucketResolution)) {
            Chart(trendPoints(from: overview)) { point in
                BarMark(
                    x: .value("时间", point.bucketLabel),
                    y: .value("时长", point.hours)
                )
                .foregroundStyle(color(from: point.colorHex))
            }
            .frame(height: 240)

            if let summary = trendSummary(for: overview) {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distributionSection(_ overview: TimeOverview) -> some View {
        Section("分类分布") {
            Chart(overview.buckets) { bucket in
                SectorMark(
                    angle: .value("时长", bucket.totalDuration),
                    innerRadius: .ratio(0.58),
                    angularInset: 2
                )
                .foregroundStyle(color(from: bucket.colorHex))
            }
            .frame(height: 260)

            ForEach(overview.buckets) { bucket in
                HStack(spacing: 8) {
                    Circle()
                        .fill(color(from: bucket.colorHex))
                        .frame(width: 8, height: 8)
                    Text(bucket.name)
                    Spacer()
                    Text(bucket.shareText)
                        .foregroundStyle(.secondary)
                    Text(bucket.totalDuration.formattedDuration)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trendTitle(for resolution: OverviewStackedBucketResolution) -> String {
        switch resolution {
        case .hour: return "今日分布"
        case .day: return "每日分布"
        case .week: return "每周分布"
        }
    }

    private func trendSummary(for overview: TimeOverview) -> String? {
        guard
            let bucket = overview.stackedBuckets.max(by: { $0.totalDuration < $1.totalDuration }),
            bucket.totalDuration > 0,
            let dominantSegment = bucket.segments.max(by: { $0.duration < $1.duration })
        else {
            return nil
        }

        return "最忙时段：\(bucket.label)，共 \(bucket.totalDuration.formattedDuration)，其中\(dominantSegment.calendarName) \(dominantSegment.duration.formattedDuration)。"
    }

    private var authorizationHint: String {
        switch model.authorizationState {
        case .notDetermined:
            return "请先授予日历权限"
        case .denied:
            return "日历权限已被拒绝，请到系统设置中开启后再试"
        case .restricted:
            return "当前设备限制了日历访问权限。"
        case .authorized:
            return ""
        }
    }

    private func trendPoints(from overview: TimeOverview) -> [TrendPoint] {
        overview.stackedBuckets.flatMap { bucket in
            bucket.segments.map { segment in
                TrendPoint(
                    id: "\(bucket.id)-\(segment.calendarID)",
                    bucketLabel: bucket.label,
                    hours: segment.duration / 3600,
                    colorHex: segment.calendarColorHex
                )
            }
        }
    }

    private func color(from hex: String) -> Color {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        guard let value = Int(sanitized, radix: 16) else { return .accentColor }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: 1))
    }
}

private struct TrendPoint: Identifiable {
    let id: String
    let bucketLabel: String
    let hours: Double
    let colorHex: String
}
