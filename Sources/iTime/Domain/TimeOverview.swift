import Foundation

public struct TimeOverview: Equatable, Sendable {
    public let range: TimeRangePreset
    public let interval: DateInterval
    public let totalDuration: TimeInterval
    public let totalEventCount: Int
    public let averageDailyDuration: TimeInterval
    public let longestDayDuration: TimeInterval
    public let dailyDurations: [DailyDurationSummary]
    public let stackedBucketResolution: OverviewStackedBucketResolution
    public let stackedBuckets: [OverviewStackedBucket]
    public let buckets: [TimeBucketSummary]

    public init(
        range: TimeRangePreset,
        interval: DateInterval,
        dailyDurations: [DailyDurationSummary],
        stackedBucketResolution: OverviewStackedBucketResolution = .day,
        stackedBuckets: [OverviewStackedBucket] = [],
        buckets: [TimeBucketSummary]
    ) {
        let total = buckets.reduce(0) { $0 + $1.totalDuration }
        let totalEventCount = buckets.reduce(0) { $0 + $1.eventCount }

        self.range = range
        self.interval = interval
        self.totalDuration = total
        self.totalEventCount = totalEventCount
        self.averageDailyDuration = dailyDurations.isEmpty ? 0 : total / Double(dailyDurations.count)
        self.longestDayDuration = dailyDurations.map(\.totalDuration).max() ?? 0
        self.dailyDurations = dailyDurations
        self.stackedBucketResolution = stackedBucketResolution
        self.stackedBuckets = stackedBuckets
        self.buckets = buckets.map { bucket in
            var updatedBucket = bucket
            updatedBucket.share = total == 0 ? 0 : bucket.totalDuration / total
            return updatedBucket
        }
    }
}
