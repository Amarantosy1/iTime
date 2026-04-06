import Charts
import SwiftUI

struct iOSOverviewView: View {
    @Bindable var model: AppModel
    @State private var chartAppeared = false
    private let cardSpacing: CGFloat = 16
    private var currentTheme: AppDisplayTheme { model.preferences.interfaceTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                overviewBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: cardSpacing) {
                        rangeSection

                        if model.authorizationState == .authorized {
                            if let overview = model.overview, !overview.buckets.isEmpty {
                                metricsSection(overview)
                                trendSection(overview)
                                distributionSection(overview)
                            } else {
                                MagazineGlassCard(theme: currentTheme) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        sectionEyebrow("暂无数据")
                                        Text("当前时间范围内没有可统计的日程。")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            MagazineGlassCard(theme: currentTheme) {
                                VStack(alignment: .leading, spacing: 10) {
                                    sectionEyebrow("日历权限")
                                    Text(authorizationHint)
                                        .foregroundStyle(.secondary)
                                    Button("请求权限") {
                                        Task { await model.requestAccessIfNeeded() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("统计")
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
        }
    }

    private var rangeSection: some View {
        MagazineGlassCard(theme: currentTheme) {
            VStack(alignment: .leading, spacing: 12) {
                sectionEyebrow("统计范围")

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
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.secondary.opacity(0.35))
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
        MagazineGlassCard(theme: currentTheme) {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("关键指标")
                LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(OverviewMetricKind.allCases, id: \.self) { metric in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(metricValue(metric, overview: overview))
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .contentTransition(.numericText())

                            Text(metric.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: overview.totalDuration)
    }

    private func trendSection(_ overview: TimeOverview) -> some View {
        MagazineGlassCard(theme: currentTheme) {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow(trendTitle(for: overview.stackedBucketResolution))

                let labels = overview.stackedBuckets.map(\.label)

                Chart(trendPoints(from: overview)) { point in
                    BarMark(
                        x: .value("时间", point.bucketLabel),
                        y: .value("时长", chartAppeared ? point.hours : 0)
                    )
                    .foregroundStyle(Color(hex: point.colorHex))
                    .cornerRadius(4)
                }
                .chartXScale(domain: labels)
                .chartXAxis {
                    AxisMarks(values: visibleXAxisLabels(from: overview.stackedBuckets)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(anchor: .top) {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.caption2)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 210)

                if let summary = trendSummary(for: overview) {
                    VStack(alignment: .leading, spacing: 8) {
                        MagazineDivider()
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .onAppear {
            guard !chartAppeared else { return }
            withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                chartAppeared = true
            }
        }
    }

    private func distributionSection(_ overview: TimeOverview) -> some View {
        MagazineGlassCard(theme: currentTheme) {
            VStack(alignment: .leading, spacing: 14) {
                sectionEyebrow("分类分布")

                Chart(overview.buckets) { bucket in
                    SectorMark(
                        angle: .value("时长", bucket.totalDuration),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: bucket.colorHex))
                }
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(overview.buckets) { bucket in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: bucket.colorHex))
                                    .frame(width: 12, height: 12)

                                Text(bucket.name)
                                    .font(.body)
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                Text(bucket.shareText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(bucket.totalDuration.formattedDuration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(bucket.name)，\(bucket.shareText)，\(bucket.totalDuration.formattedDuration)")
                    }
                }
            }
        }
    }

    private var overviewBackground: some View {
        iOSThemeBackground(
            theme: currentTheme,
            accentColor: overviewAccentColor,
            customImageName: model.preferences.customThemeImageName,
            customScale: model.preferences.customThemeScale,
            customOffsetX: model.preferences.customThemeOffsetX,
            customOffsetY: model.preferences.customThemeOffsetY,
            starCount: 170,
            twinkleBoost: 1.7,
            meteorCount: 5
        )
        .animation(.easeInOut(duration: 0.8), value: model.overview?.buckets.first?.colorHex)
    }

    private var overviewAccentColor: Color {
        if let hex = model.overview?.buckets.first?.colorHex {
            return Color(hex: hex)
        }
        return .accentColor
    }

    private func sectionEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    private func metricValue(_ metric: OverviewMetricKind, overview: TimeOverview) -> String {
        switch metric {
        case .totalDuration:
            overview.totalDuration.formattedDuration
        case .eventCount:
            "\(overview.totalEventCount)"
        case .averageDailyDuration:
            overview.averageDailyDuration.formattedDuration
        case .longestDay:
            overview.longestDayDuration.formattedDuration
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

    private func visibleXAxisLabels(from buckets: [OverviewStackedBucket]) -> [String] {
        let labels = buckets.map(\.label)
        guard !labels.isEmpty else { return [] }

        let maxVisibleLabels = 5
        guard labels.count > maxVisibleLabels else { return labels }

        let step = max(1, Int(ceil(Double(labels.count) / Double(maxVisibleLabels))))

        var visible = stride(from: 0, to: labels.count, by: step).map { labels[$0] }

        if let last = labels.last, visible.last != last {
            if !visible.isEmpty {
                visible.removeLast()
            }
            visible.append(last)
        }

        return visible
    }
}

private enum OverviewMetricKind: CaseIterable {
    case totalDuration
    case eventCount
    case averageDailyDuration
    case longestDay

    var title: String {
        switch self {
        case .totalDuration:
            "总时长"
        case .eventCount:
            "事件数"
        case .averageDailyDuration:
            "日均时长"
        case .longestDay:
            "最长单日"
        }
    }

    var icon: String {
        switch self {
        case .totalDuration:
            "clock.fill"
        case .eventCount:
            "calendar.badge.clock"
        case .averageDailyDuration:
            "chart.line.uptrend.xyaxis"
        case .longestDay:
            "trophy.fill"
        }
    }
}

private struct TrendPoint: Identifiable {
    let id: String
    let bucketLabel: String
    let hours: Double
    let colorHex: String
}

