import Foundation

public protocol StatisticsAggregating {
    func makeOverview(range: TimeRangePreset, interval: DateInterval, events: [CalendarEventRecord]) -> TimeOverview
}
