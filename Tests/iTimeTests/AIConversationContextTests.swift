import Foundation
import Testing
@testable import iTime

@Test func conversationContextIncludesEventTitlesAndLatestMemory() {
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let overview = TimeOverview(
        range: .week,
        interval: DateInterval(start: startDate, duration: 86_400 * 7),
        dailyDurations: [
            DailyDurationSummary(date: startDate, totalDuration: 7_200),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "工作", colorHex: "#4A90E2", totalDuration: 7_200, eventCount: 2),
        ]
    )
    let context = overview.makeAIConversationContext(
        events: [
            CalendarEventRecord(
                id: "later",
                title: "需求评审",
                calendarID: "work",
                startDate: startDate.addingTimeInterval(7_200),
                endDate: startDate.addingTimeInterval(10_800),
                isAllDay: false
            ),
            CalendarEventRecord(
                id: "all-day",
                title: "全天假期",
                calendarID: "life",
                startDate: startDate,
                endDate: startDate.addingTimeInterval(86_400),
                isAllDay: true
            ),
            CalendarEventRecord(
                id: "early",
                title: "深度工作",
                calendarID: "work",
                startDate: startDate.addingTimeInterval(3_600),
                endDate: startDate.addingTimeInterval(5_400),
                isAllDay: false
            ),
        ],
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "生活", colorHex: "#50E3C2", isSelected: true),
        ],
        latestMemorySummary: "最近几轮复盘都提到会议偏多。"
    )

    #expect(context.rangeTitle == "本周")
    #expect(context.latestMemorySummary == "最近几轮复盘都提到会议偏多。")
    #expect(context.events.map(\.title) == ["深度工作", "需求评审"])
    #expect(context.events.map(\.calendarName) == ["工作", "工作"])
    #expect(context.events.map(\.durationText) == ["30分钟", "1小时"])
    #expect(context.overviewSnapshot.totalEventCount == 2)
}

@Test func conversationContextFallsBackToUnknownCalendarName() {
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let overview = TimeOverview(
        range: .today,
        interval: DateInterval(start: startDate, duration: 86_400),
        dailyDurations: [
            DailyDurationSummary(date: startDate, totalDuration: 3_600),
        ],
        buckets: [
            TimeBucketSummary(id: "unknown", name: "未知", colorHex: "#999999", totalDuration: 3_600, eventCount: 1),
        ]
    )

    let context = overview.makeAIConversationContext(
        events: [
            CalendarEventRecord(
                id: "1",
                title: "临时事项",
                calendarID: "missing",
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3_600),
                isAllDay: false
            ),
        ],
        calendarLookup: [:],
        latestMemorySummary: nil
    )

    #expect(context.events.first?.calendarName == "未分类日历")
    #expect(context.latestMemorySummary == nil)
}
