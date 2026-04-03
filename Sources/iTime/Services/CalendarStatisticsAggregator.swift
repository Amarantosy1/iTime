import Foundation

public struct CalendarStatisticsAggregator: StatisticsAggregating, Sendable {
    private let weeklyBucketThreshold = 45
    private let calendarLookup: [String: CalendarSource]
    private let calendar: Calendar

    public init(calendarLookup: [String: CalendarSource], calendar: Calendar = .current) {
        self.calendarLookup = calendarLookup
        self.calendar = calendar
    }

    public func makeOverview(range: TimeRangePreset, interval: DateInterval, events: [CalendarEventRecord]) -> TimeOverview {
        let grouped = Dictionary(grouping: events, by: \.calendarID)

        let buckets = grouped.compactMap { calendarID, records -> TimeBucketSummary? in
            guard let source = calendarLookup[calendarID] else { return nil }
            let duration = records.reduce(0) { partial, record in
                partial + max(0, record.endDate.timeIntervalSince(record.startDate))
            }

            return TimeBucketSummary(
                id: source.id,
                name: source.name,
                colorHex: source.colorHex,
                totalDuration: duration,
                eventCount: records.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalDuration == rhs.totalDuration {
                return lhs.name < rhs.name
            }
            return lhs.totalDuration > rhs.totalDuration
        }

        let resolution = makeBucketResolution(for: range, interval: interval)

        return TimeOverview(
            range: range,
            interval: interval,
            dailyDurations: makeDailyDurations(in: interval, events: events),
            stackedBucketResolution: resolution,
            stackedBuckets: makeStackedBuckets(
                in: interval,
                events: events,
                orderedBuckets: buckets,
                resolution: resolution
            ),
            buckets: buckets
        )
    }

    private func makeDailyDurations(in interval: DateInterval, events: [CalendarEventRecord]) -> [DailyDurationSummary] {
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.startDate) }
        var summaries: [DailyDurationSummary] = []
        var currentDay = calendar.startOfDay(for: interval.start)
        let endDay = calendar.startOfDay(for: interval.end.addingTimeInterval(-1))

        while currentDay <= endDay {
            let totalDuration = grouped[currentDay, default: []].reduce(0) { partial, record in
                partial + max(0, record.endDate.timeIntervalSince(record.startDate))
            }
            summaries.append(DailyDurationSummary(date: currentDay, totalDuration: totalDuration))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                break
            }
            currentDay = nextDay
        }

        return summaries
    }

    private func makeBucketResolution(
        for range: TimeRangePreset,
        interval: DateInterval
    ) -> OverviewStackedBucketResolution {
        if range == .today {
            return .hour
        }

        let dayCount = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: interval.start),
            to: calendar.startOfDay(for: interval.end)
        ).day ?? 0

        return dayCount > weeklyBucketThreshold ? .week : .day
    }

    private func makeStackedBuckets(
        in interval: DateInterval,
        events: [CalendarEventRecord],
        orderedBuckets: [TimeBucketSummary],
        resolution: OverviewStackedBucketResolution
    ) -> [OverviewStackedBucket] {
        let bucketIntervals = makeBucketIntervals(in: interval, resolution: resolution)

        return bucketIntervals.map { bucketInterval in
            let segments = orderedBuckets.compactMap { bucket -> OverviewStackedSegment? in
                let duration = events.reduce(0) { partial, record in
                    guard record.calendarID == bucket.id else { return partial }
                    return partial + overlappingDuration(of: record, within: bucketInterval)
                }

                guard duration > 0 else { return nil }

                return OverviewStackedSegment(
                    calendarID: bucket.id,
                    calendarName: bucket.name,
                    calendarColorHex: bucket.colorHex,
                    duration: duration
                )
            }

            return OverviewStackedBucket(
                id: bucketIdentifier(for: bucketInterval, resolution: resolution),
                label: bucketLabel(for: bucketInterval, resolution: resolution),
                interval: bucketInterval,
                totalDuration: segments.reduce(0) { $0 + $1.duration },
                segments: segments
            )
        }
    }

    private func makeBucketIntervals(
        in interval: DateInterval,
        resolution: OverviewStackedBucketResolution
    ) -> [DateInterval] {
        var intervals: [DateInterval] = []
        var cursor = resolution == .hour ? interval.start : calendar.startOfDay(for: interval.start)

        while cursor < interval.end {
            let nextCursor = bucketEnd(after: cursor, resolution: resolution)
            intervals.append(DateInterval(start: cursor, end: min(nextCursor, interval.end)))
            cursor = nextCursor
        }

        return intervals
    }

    private func bucketEnd(
        after start: Date,
        resolution: OverviewStackedBucketResolution
    ) -> Date {
        switch resolution {
        case .hour:
            return calendar.date(byAdding: .hour, value: 1, to: start) ?? start
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: start) ?? start
        case .week:
            return calendar.date(byAdding: .day, value: 7, to: start) ?? start
        }
    }

    private func bucketIdentifier(
        for interval: DateInterval,
        resolution: OverviewStackedBucketResolution
    ) -> String {
        switch resolution {
        case .hour:
            return interval.start.ISO8601Format(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        case .day:
            return interval.start.ISO8601Format(.iso8601.year().month().day())
        case .week:
            return interval.start.ISO8601Format(.iso8601.year().month().day()) + "-week"
        }
    }

    private func bucketLabel(
        for interval: DateInterval,
        resolution: OverviewStackedBucketResolution
    ) -> String {
        switch resolution {
        case .hour:
            let hour = calendar.component(.hour, from: interval.start)
            return "\(hour)时"
        case .day:
            let day = calendar.component(.day, from: interval.start)
            return "\(day)日"
        case .week:
            let startDay = calendar.component(.day, from: interval.start)
            let endDay = calendar.component(.day, from: interval.end.addingTimeInterval(-1))
            return "\(startDay)-\(endDay)日"
        }
    }

    private func overlappingDuration(
        of record: CalendarEventRecord,
        within interval: DateInterval
    ) -> TimeInterval {
        let overlapStart = max(record.startDate, interval.start)
        let overlapEnd = min(record.endDate, interval.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}
