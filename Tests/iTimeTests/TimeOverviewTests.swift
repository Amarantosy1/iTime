import Testing
@testable import iTime

@Test func overviewComputesTotalDurationFromBuckets() {
    let overview = TimeOverview(
        range: .today,
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 3600, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1800, eventCount: 1),
        ]
    )

    #expect(overview.totalDuration == 5400)
    #expect(overview.buckets[0].share == 2.0 / 3.0)
    #expect(overview.buckets[1].share == 1.0 / 3.0)
}
