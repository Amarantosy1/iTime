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
        stackedBucketResolution: .day,
        stackedBuckets: [
            OverviewStackedBucket(
                id: "1970-01-01",
                label: "1日",
                interval: DateInterval(start: start, end: start.addingTimeInterval(86_400)),
                totalDuration: 5_400,
                segments: [
                    OverviewStackedSegment(
                        calendarID: "work",
                        calendarName: "Work",
                        calendarColorHex: "#4A90E2",
                        duration: 3_600
                    ),
                    OverviewStackedSegment(
                        calendarID: "life",
                        calendarName: "Life",
                        calendarColorHex: "#50E3C2",
                        duration: 1_800
                    ),
                ]
            ),
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
        stackedBucketResolution: .day,
        stackedBuckets: [
            OverviewStackedBucket(
                id: "1970-01-01",
                label: "1日",
                interval: DateInterval(start: start, end: start.addingTimeInterval(86_400)),
                totalDuration: 3_600,
                segments: [
                    OverviewStackedSegment(
                        calendarID: "work",
                        calendarName: "Work",
                        calendarColorHex: "#4A90E2",
                        duration: 3_600
                    ),
                ]
            ),
            OverviewStackedBucket(
                id: "1970-01-02",
                label: "2日",
                interval: DateInterval(
                    start: start.addingTimeInterval(86_400),
                    end: start.addingTimeInterval(172_800)
                ),
                totalDuration: 1_800,
                segments: [
                    OverviewStackedSegment(
                        calendarID: "life",
                        calendarName: "Life",
                        calendarColorHex: "#50E3C2",
                        duration: 1_800
                    ),
                ]
            ),
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

@Test func overviewCarriesStackedBucketsAndResolution() {
    let start = Date(timeIntervalSince1970: 0)
    let overview = TimeOverview(
        range: .week,
        interval: DateInterval(start: start, end: start.addingTimeInterval(7 * 86_400)),
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 7_200),
        ],
        stackedBucketResolution: .day,
        stackedBuckets: [
            OverviewStackedBucket(
                id: "1970-01-01",
                label: "1日",
                interval: DateInterval(start: start, end: start.addingTimeInterval(86_400)),
                totalDuration: 7_200,
                segments: [
                    OverviewStackedSegment(
                        calendarID: "work",
                        calendarName: "Work",
                        calendarColorHex: "#4A90E2",
                        duration: 5_400
                    ),
                    OverviewStackedSegment(
                        calendarID: "life",
                        calendarName: "Life",
                        calendarColorHex: "#50E3C2",
                        duration: 1_800
                    ),
                ]
            ),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 5_400, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1_800, eventCount: 1),
        ]
    )

    #expect(overview.stackedBucketResolution == .day)
    #expect(overview.stackedBuckets.count == 1)
    #expect(overview.stackedBuckets[0].segments.count == 2)
    #expect(overview.stackedBuckets[0].segments[0].calendarName == "Work")
}

@Test func stackedBucketSummaryUsesRangeDayCountForAverage() {
    let start = Date(timeIntervalSince1970: 0)
    let overview = TimeOverview(
        range: .custom,
        interval: DateInterval(start: start, end: start.addingTimeInterval(3 * 86_400)),
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 3_600),
            DailyDurationSummary(date: start.addingTimeInterval(86_400), totalDuration: 0),
            DailyDurationSummary(date: start.addingTimeInterval(2 * 86_400), totalDuration: 1_800),
        ],
        stackedBucketResolution: .day,
        stackedBuckets: [],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 5_400, eventCount: 3),
        ]
    )

    #expect(overview.totalDuration == 5_400)
    #expect(overview.averageDailyDuration == 1_800)
}
