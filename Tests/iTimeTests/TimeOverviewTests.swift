import Foundation
import Testing
@testable import iTime

@Test func overviewComputesTotalDurationFromBuckets() {
    let start = Date(timeIntervalSince1970: 0)
    let overview = TimeOverview(
        range: .today,
        interval: DateInterval(start: start, end: start.addingTimeInterval(86_400)),
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 5_400),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 3600, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1800, eventCount: 1),
        ]
    )

    #expect(overview.totalDuration == 5400)
    #expect(overview.buckets[0].share == 2.0 / 3.0)
    #expect(overview.buckets[1].share == 1.0 / 3.0)
}

@Test func overviewComputesDashboardMetrics() {
    let start = Date(timeIntervalSince1970: 0)
    let interval = DateInterval(start: start, end: start.addingTimeInterval(172_800))

    let overview = TimeOverview(
        range: .custom,
        interval: interval,
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 3_600),
            DailyDurationSummary(date: start.addingTimeInterval(86_400), totalDuration: 1_800),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 3_600, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1_800, eventCount: 1),
        ]
    )

    #expect(overview.totalDuration == 5_400)
    #expect(overview.totalEventCount == 3)
    #expect(overview.averageDailyDuration == 2_700)
    #expect(overview.longestDayDuration == 3_600)
}
