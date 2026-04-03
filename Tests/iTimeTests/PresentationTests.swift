import Foundation
import SwiftUI
import Testing
@testable import iTime

@Test func allRangesAreVisibleInOrder() {
    #expect(TimeRangePreset.allCases == [.today, .week, .month, .custom])
}

@Test func menuAndOverviewRangeOptionsAreSeparated() {
    #expect(TimeRangePreset.menuCases == [.today, .week, .month])
    #expect(TimeRangePreset.overviewCases == [.today, .week, .month, .custom])
}

@Test func rangeTitlesUseChineseStrings() {
    #expect(TimeRangePreset.today.title == "今天")
    #expect(TimeRangePreset.week.title == "本周")
    #expect(TimeRangePreset.month.title == "本月")
    #expect(TimeRangePreset.custom.title == "自定义")
}

@Test func overviewMetricTitlesUseChineseStrings() {
    #expect(OverviewMetricKind.totalDuration.title == "总时长")
    #expect(OverviewMetricKind.eventCount.title == "事件数")
    #expect(OverviewMetricKind.averageDailyDuration.title == "日均时长")
    #expect(OverviewMetricKind.longestDay.title == "最长单日")
}

@Test func durationFormattingRendersHoursAndMinutes() {
    #expect(TimeInterval(5400).formattedDuration == "1h 30m")
}

@Test func bucketFormattingUsesPercentageStrings() {
    let bucket = TimeBucketSummary(
        id: "work",
        name: "Work",
        colorHex: "#4A90E2",
        totalDuration: 3600,
        eventCount: 1,
        share: 0.25
    )

    #expect(bucket.shareText == "25%")
}

@Test func overviewBackgroundPaletteChangesWithColorScheme() {
    let lightPalette = AppTheme.overviewBackgroundPalette(for: .light)
    let darkPalette = AppTheme.overviewBackgroundPalette(for: .dark)

    #expect(lightPalette.startHex == "#F2F7FF")
    #expect(lightPalette.endHex == "#E6F0FA")
    #expect(darkPalette.startHex == "#111827")
    #expect(darkPalette.endHex == "#1F2937")
}

@Test func overviewBackgroundGradientUsesPaletteColors() {
    let darkGradient = AppTheme.overviewBackgroundGradient(for: .dark)
    let lightGradient = AppTheme.overviewBackgroundGradient(for: .light)

    #expect(darkGradient.palette == AppTheme.BackgroundPalette(startHex: "#111827", endHex: "#1F2937"))
    #expect(lightGradient.palette == AppTheme.BackgroundPalette(startHex: "#F2F7FF", endHex: "#E6F0FA"))
}

@Test func overviewLegendStyleUsesSemanticTextRoles() {
    let legendStyle = AppTheme.overviewLegendStyle(for: "#4A90E2")

    #expect(legendStyle.swatchHex == "#4A90E2")
    #expect(legendStyle.titleRole == .primary)
    #expect(legendStyle.shareRole == .primary)
    #expect(legendStyle.durationRole == .secondary)
}

@Test func stackedTrendSectionUsesChineseStrings() {
    #expect(OverviewTrendChartCopy.title(for: .hour) == "今日分布")
    #expect(OverviewTrendChartCopy.title(for: .day) == "每日分布")
    #expect(OverviewTrendChartCopy.title(for: .week) == "每周分布")
    #expect(OverviewTrendChartCopy.summaryPrefix == "最忙时段")
}

@Test func stackedTrendSummaryHighlightsLargestCalendar() {
    let bucket = OverviewStackedBucket(
        id: "1970-01-01",
        label: "1日",
        interval: DateInterval(
            start: .init(timeIntervalSince1970: 0),
            end: .init(timeIntervalSince1970: 86_400)
        ),
        totalDuration: 7_200,
        segments: [
            OverviewStackedSegment(
                calendarID: "work",
                calendarName: "工作",
                calendarColorHex: "#4A90E2",
                duration: 5_400
            ),
            OverviewStackedSegment(
                calendarID: "life",
                calendarName: "生活",
                calendarColorHex: "#50E3C2",
                duration: 1_800
            ),
        ]
    )

    let summary = OverviewTrendChartCopy.summary(for: bucket)

    #expect(summary?.contains("工作") == true)
    #expect(summary?.contains("2h") == true)
}
