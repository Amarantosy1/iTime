import Foundation

public struct TimeOverview: Equatable, Sendable {
    public let range: TimeRangePreset
    public let totalDuration: TimeInterval
    public let buckets: [TimeBucketSummary]

    public init(range: TimeRangePreset, buckets: [TimeBucketSummary]) {
        let total = buckets.reduce(0) { $0 + $1.totalDuration }
        self.range = range
        self.totalDuration = total
        self.buckets = buckets.map { bucket in
            var updatedBucket = bucket
            updatedBucket.share = total == 0 ? 0 : bucket.totalDuration / total
            return updatedBucket
        }
    }
}
