import Charts
import SwiftUI
import UIKit

struct iOSOverviewView: View {
    @Bindable var model: AppModel
    private let cardSpacing: CGFloat = 16
    @State private var activeChartDetail: OverviewChartDetail?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: cardSpacing) {
                    rangeSection

                    if model.authorizationState == .authorized {
                        if let overview = model.overview, !overview.buckets.isEmpty {
                            metricsSection(overview)
                            trendSection(overview)
                            distributionSection(overview)
                        } else {
                            card(title: "暂无数据") {
                                Text("当前时间范围内没有可统计的日程。")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        card(title: "日历权限") {
                            Text(authorizationHint)
                                .foregroundStyle(.secondary)
                            Button("请求权限") {
                                Task { await model.requestAccessIfNeeded() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("统计")
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
            .fullScreenCover(item: $activeChartDetail) { detail in
                iOSOverviewChartDetailView(detail: detail)
            }
        }
    }

    private var rangeSection: some View {
        card(title: "统计范围") {
            VStack(alignment: .leading, spacing: 12) {
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
    }

    @ViewBuilder
    private var customDateRangeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CustomDateRangePreset.allCases, id: \.self) { preset in
                        Button(preset.title) {
                            Task { await model.setCustomDateRange(preset: preset) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

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
    }

    private func metricsSection(_ overview: TimeOverview) -> some View {
        card(title: "关键指标") {
            VStack(spacing: 10) {
                LabeledContent("总时长", value: overview.totalDuration.formattedDuration)
                LabeledContent("事件数", value: "\(overview.totalEventCount)")
                LabeledContent("日均时长", value: overview.averageDailyDuration.formattedDuration)
                LabeledContent("最长单日", value: overview.longestDayDuration.formattedDuration)
            }
        }
    }

    private func trendSection(_ overview: TimeOverview) -> some View {
        card(title: trendTitle(for: overview.stackedBucketResolution)) {
            HStack {
                Spacer()
                Button("查看详情") {
                    activeChartDetail = .trend(overview)
                }
                .font(.footnote.weight(.semibold))
            }

            GeometryReader { proxy in
                let labels = overview.stackedBuckets.map(\.label)
                let minBarWidth: CGFloat = 44
                let minimumChartWidth = max(proxy.size.width - 8, CGFloat(max(labels.count, 1)) * minBarWidth)

                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(trendPoints(from: overview)) { point in
                        BarMark(
                            x: .value("时间", point.bucketLabel),
                            y: .value("时长", point.hours)
                        )
                        .foregroundStyle(color(from: point.colorHex))
                    }
                    .chartXScale(domain: labels)
                    .chartXAxis {
                        AxisMarks(values: visibleXAxisLabels(from: overview.stackedBuckets)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let label = value.as(String.self) {
                                    Text(label)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(width: minimumChartWidth, height: 260)
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                }
            }
            .frame(height: 280)

            if let summary = trendSummary(for: overview) {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distributionSection(_ overview: TimeOverview) -> some View {
        card(title: "分类分布") {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button("查看详情") {
                        activeChartDetail = .distribution(overview)
                    }
                    .font(.footnote.weight(.semibold))
                }

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
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer()
                        Text(bucket.shareText)
                            .foregroundStyle(.secondary)
                        Text(bucket.totalDuration.formattedDuration)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
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

    private func visibleXAxisLabels(from buckets: [OverviewStackedBucket]) -> [String] {
        let labels = buckets.map(\.label)
        guard labels.count > 8 else { return labels }

        let maxVisibleLabels = 8
        let step = max(1, Int(ceil(Double(labels.count - 1) / Double(maxVisibleLabels - 1))))
        var visible = stride(from: 0, to: labels.count, by: step).map { labels[$0] }

        if let last = labels.last, visible.last != last {
            visible.append(last)
        }

        return visible
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

private enum OverviewChartDetail: Identifiable {
    case trend(TimeOverview)
    case distribution(TimeOverview)

    var id: String {
        switch self {
        case .trend(let overview):
            return "trend-\(overview.range.rawValue)-\(Int(overview.interval.start.timeIntervalSince1970))-\(Int(overview.interval.end.timeIntervalSince1970))-\(overview.stackedBuckets.count)"
        case .distribution(let overview):
            return "distribution-\(overview.range.rawValue)-\(Int(overview.interval.start.timeIntervalSince1970))-\(Int(overview.interval.end.timeIntervalSince1970))-\(overview.buckets.count)"
        }
    }
}

private struct iOSOverviewChartDetailView: View {
    let detail: OverviewChartDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch detail {
                case .trend(let overview):
                    trendDetail(overview)
                case .distribution(let overview):
                    distributionDetail(overview)
                }
            }
            .padding(16)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("退出") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var title: String {
        switch detail {
        case .trend:
            return "时长趋势详情"
        case .distribution:
            return "分类分布详情"
        }
    }

    @ViewBuilder
    private func trendDetail(_ overview: TimeOverview) -> some View {
        GeometryReader { proxy in
            let labels = overview.stackedBuckets.map(\.label)
            let minBarWidth: CGFloat = 52
            let minimumChartWidth = max(proxy.size.width - 12, CGFloat(max(labels.count, 1)) * minBarWidth)
            let chartHeight = max(320, proxy.size.height - 120)

            ScrollView(.horizontal, showsIndicators: true) {
                Chart(trendPoints(from: overview)) { point in
                    BarMark(
                        x: .value("时间", point.bucketLabel),
                        y: .value("时长", point.hours)
                    )
                    .foregroundStyle(color(from: point.colorHex))
                }
                .chartXScale(domain: labels)
                .chartXAxis {
                    AxisMarks(values: visibleXAxisLabels(from: overview.stackedBuckets)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(width: minimumChartWidth, height: chartHeight)
                .padding(.leading, 12)
            }
        }

        Text("横屏查看时可展示更多时间刻度。")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func distributionDetail(_ overview: TimeOverview) -> some View {
        GeometryReader { proxy in
            let chartHeight = max(320, proxy.size.height * 0.56)

            VStack(spacing: 16) {
                Chart(overview.buckets) { bucket in
                    SectorMark(
                        angle: .value("时长", bucket.totalDuration),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(color(from: bucket.colorHex))
                }
                .frame(height: chartHeight)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(overview.buckets) { bucket in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(from: bucket.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(bucket.name)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer()
                                Text(bucket.shareText)
                                    .foregroundStyle(.secondary)
                                Text(bucket.totalDuration.formattedDuration)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }

        Text("横屏查看时饼图和图例会有更宽阔的展示空间。")
            .font(.footnote)
            .foregroundStyle(.secondary)
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

    private func visibleXAxisLabels(from buckets: [OverviewStackedBucket]) -> [String] {
        let labels = buckets.map(\.label)
        guard labels.count > 8 else { return labels }

        let maxVisibleLabels = 8
        let step = max(1, Int(ceil(Double(labels.count - 1) / Double(maxVisibleLabels - 1))))
        var visible = stride(from: 0, to: labels.count, by: step).map { labels[$0] }

        if let last = labels.last, visible.last != last {
            visible.append(last)
        }

        return visible
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
