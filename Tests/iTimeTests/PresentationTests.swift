import AppKit
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

@Test func customRangePresetTitlesUseChineseStrings() {
    #expect(CustomDateRangePreset.lastWeek.title == "上周")
    #expect(CustomDateRangePreset.lastMonth.title == "上月")
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

    #expect(lightPalette.startHex == "#F2F2F7")
    #expect(lightPalette.endHex == "#E5E5EA")
    #expect(lightPalette.accentHex == "#007AFF")
    #expect(darkPalette.startHex == "#1C1C1E")
    #expect(darkPalette.endHex == "#0A0A0B")
    #expect(darkPalette.accentHex == "#5E5CE6")
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

@Test func stackedTrendChartDomainPreservesEmptyHourlyBuckets() {
    var buckets: [OverviewStackedBucket] = []
    for hour in 0..<24 {
        let start = Date(timeIntervalSince1970: Double(hour * 3_600))
        let end = Date(timeIntervalSince1970: Double((hour + 1) * 3_600))
        let segments: [OverviewStackedSegment]
        if hour == 9 {
            segments = [
                OverviewStackedSegment(
                    calendarID: "work",
                    calendarName: "工作",
                    calendarColorHex: "#4A90E2",
                    duration: 1_800
                ),
            ]
        } else {
            segments = []
        }

        buckets.append(
            OverviewStackedBucket(
                id: "\(hour)",
                label: "\(hour)时",
                interval: DateInterval(start: start, end: end),
                totalDuration: hour == 9 ? 1_800 : 0,
                segments: segments
            )
        )
    }

    #expect(OverviewTrendChartCopy.xDomainLabels(for: buckets).count == 24)
    #expect(OverviewTrendChartCopy.xDomainLabels(for: buckets).first == "0时")
    #expect(OverviewTrendChartCopy.xDomainLabels(for: buckets).last == "23时")
}

@Test func menuBarChartRowsKeepTopBucketsInOrder() {
    let rows = MenuBarBucketChartRow.makeRows(
        from: [
            TimeBucketSummary(
                id: "work",
                name: "工作",
                colorHex: "#4A90E2",
                totalDuration: 7_200,
                eventCount: 2,
                share: 0.5
            ),
            TimeBucketSummary(
                id: "study",
                name: "学习",
                colorHex: "#50E3C2",
                totalDuration: 3_600,
                eventCount: 1,
                share: 0.25
            ),
            TimeBucketSummary(
                id: "life",
                name: "生活",
                colorHex: "#F5A623",
                totalDuration: 1_800,
                eventCount: 1,
                share: 0.125
            ),
            TimeBucketSummary(
                id: "fitness",
                name: "健身",
                colorHex: "#D0021B",
                totalDuration: 900,
                eventCount: 1,
                share: 0.0625
            ),
            TimeBucketSummary(
                id: "misc",
                name: "其他",
                colorHex: "#9013FE",
                totalDuration: 450,
                eventCount: 1,
                share: 0.03125
            ),
        ]
    )

    #expect(rows.count == 4)
    #expect(rows.map(\.name) == ["工作", "学习", "生活", "健身"])
    #expect(rows[0].shareText == "50%")
    #expect(rows[0].fillRatio == 0.5)
    #expect(rows[1].durationText == "1h")
}

@Test func menuBarChartUsesChineseSectionTitle() {
    #expect(MenuBarBucketChartCopy.sectionTitle == "按日历分布")
}

@Test func aiAnalysisCopyUsesChineseStrings() {
    #expect(AIAnalysisCopy.sectionTitle == "AI 时间评估")
    #expect(AIAnalysisCopy.openConversationWindowAction == "打开 AI 复盘")
    #expect(AIAnalysisCopy.historyAction == "查看历史总结")
    #expect(AIAnalysisCopy.latestSummaryTitle == "最近一次总结")
    #expect(AIConversationWindowCopy.title == "AI 复盘")
    #expect(AIConversationWindowCopy.newConversationAction == "开始新复盘")
    #expect(AIConversationWindowCopy.historyAction == "历史总结")
    #expect(AIConversationWindowCopy.sendReplyAction == "发送")
    #expect(AIConversationWindowCopy.finishConversationAction == "结束复盘")
    #expect(AIConversationWindowCopy.saveEditsAction == "保存修改")
    #expect(AIConversationWindowCopy.editSummaryAction == "编辑总结")
    #expect(AIConversationWindowCopy.discardConversationAccessibilityLabel == "退出本轮复盘")
    #expect(AIConversationWindowCopy.discardConfirmationTitle == "放弃这轮复盘？")
    #expect(AIConversationWindowCopy.longFormTitle == "长文复盘")
    #expect(AIConversationWindowCopy.generateLongFormAction == "生成长文复盘")
    #expect(AIConversationWindowCopy.regenerateLongFormAction == "重新生成长文")
    #expect(AIConversationWindowCopy.longFormSaveAction == "保存长文")
    #expect(AISettingsCopy.sectionTitle == "AI 服务")
    #expect(AISettingsCopy.addCustomServiceAction == "新增自定义服务")
    #expect(AISettingsCopy.testConnectionAction == "测试连接")
    #expect(AISettingsCopy.modelsTitle == "模型列表")
    #expect(AISettingsCopy.serviceListTitle == "服务列表")
    #expect(AISettingsCopy.selectedServiceTitle == "服务详情")
    #expect(ReviewReminderCopy.sectionTitle == "复盘提醒")
    #expect(ReviewReminderCopy.enabledTitle == "启用每日复盘提醒")
    #expect(ReviewReminderCopy.timeTitle == "提醒时间")
    #expect(ReviewReminderCopy.requestPermissionAction == "允许通知")
    #expect(AIAnalysisCopy.historyAction == "查看历史总结")
    #expect(AIAnalysisAvailability.notConfigured.message == "请先在设置中配置 AI 服务。")
    #expect(AIAnalysisAvailability.disabled.message == "请先在设置中启用一个 AI 服务。")
    #expect(AIConversationHistoryCopy.deleteAction == "删除总结")
    #expect(AIConversationHistoryCopy.longFormPlaceholder == "这条历史总结还没有生成长文复盘。")
}

@Test func settingsNavigationUsesClassicSidebarSections() {
    #expect(SettingsCopy.navigationTitle == "设置")
    #expect(SettingsCopy.calendarSectionTitle == "统计日历")
    #expect(SettingsCopy.aiServicesSectionTitle == "AI 服务")
    #expect(SettingsCopy.reviewReminderSectionTitle == "复盘提醒")
    #expect(SettingsSection.allCases == [.calendars, .aiServices, .reviewReminder])
}

@Test func settingsLayoutUsesNotesStyleSizingConstraints() {
    #expect(SettingsLayout.defaultWindowWidth == 980)
    #expect(SettingsLayout.defaultWindowHeight == 720)
    #expect(SettingsLayout.minimumWindowWidth == 760)
    #expect(SettingsLayout.minimumWindowHeight == 560)
    #expect(SettingsLayout.sidebarIdealWidth == 192)
    #expect(SettingsLayout.detailContentMaxWidth == 760)
}

@Test func settingsSectionsExposeNotesStyleDescriptions() {
    #expect(SettingsSection.calendars.description == "选择参与统计的日历。")
    #expect(SettingsSection.aiServices.description == "管理默认服务、自定义服务与连接凭据。")
    #expect(SettingsSection.reviewReminder.description == "安排每天的复盘提醒与通知权限。")
}

@Test func aiConversationSummaryUsesConcretePeriodText() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

    #expect(
        AIConversationPeriodFormatter.displayText(
            range: .today,
            startDate: .init(timeIntervalSince1970: 1_743_609_600),
            endDate: .init(timeIntervalSince1970: 1_743_696_000),
            calendar: calendar
        ) == "4月3日"
    )
    #expect(
        AIConversationPeriodFormatter.displayText(
            range: .month,
            startDate: .init(timeIntervalSince1970: 1_743_436_800),
            endDate: .init(timeIntervalSince1970: 1_746_028_800),
            calendar: calendar
        ) == "4月"
    )
    #expect(
        AIConversationPeriodFormatter.displayText(
            range: .custom,
            startDate: .init(timeIntervalSince1970: 1_743_609_600),
            endDate: .init(timeIntervalSince1970: 1_744_214_400),
            calendar: calendar
        ) == "4月3日 - 4月9日"
    )
}

@Test func aiConversationComposerReturnKeyBehaviorUsesEnterToSend() {
    #expect(AIConversationComposerKeyBehavior.shouldSendOnReturn(modifiers: []) == true)
    #expect(AIConversationComposerKeyBehavior.shouldSendOnReturn(modifiers: [.shift]) == false)
    #expect(AIConversationComposerKeyBehavior.shouldSendOnReturn(modifiers: [.option]) == false)
    #expect(AIConversationComposerKeyBehavior.shouldSendOnReturn(modifiers: [.command]) == false)
}
