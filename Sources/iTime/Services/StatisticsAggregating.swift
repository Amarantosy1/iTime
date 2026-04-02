import Foundation

public protocol StatisticsAggregating {
    func makeOverview(range: TimeRangePreset, events: [CalendarEventRecord]) -> TimeOverview
}
