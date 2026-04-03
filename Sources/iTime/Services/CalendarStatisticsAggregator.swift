import Foundation

public struct CalendarStatisticsAggregator: StatisticsAggregating, Sendable {
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

        return TimeOverview(
            range: range,
            interval: interval,
            dailyDurations: makeDailyDurations(in: interval, events: events),
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
}
