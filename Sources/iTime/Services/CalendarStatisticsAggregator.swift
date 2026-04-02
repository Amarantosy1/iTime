import Foundation

public struct CalendarStatisticsAggregator: StatisticsAggregating, Sendable {
    private let calendarLookup: [String: CalendarSource]

    public init(calendarLookup: [String: CalendarSource]) {
        self.calendarLookup = calendarLookup
    }

    public func makeOverview(range: TimeRangePreset, events: [CalendarEventRecord]) -> TimeOverview {
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

        return TimeOverview(range: range, buckets: buckets)
    }
}
