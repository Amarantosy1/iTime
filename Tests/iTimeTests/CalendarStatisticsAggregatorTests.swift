import Foundation
import Testing
@testable import iTime

@Test func aggregateGroupsDurationByCalendar() {
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true),
        ]
    )

    let overview = aggregator.makeOverview(
        range: .today,
        events: [
            CalendarEventRecord(
                id: "1",
                title: "Focus",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3600),
                isAllDay: false
            ),
            CalendarEventRecord(
                id: "2",
                title: "Dinner",
                calendarID: "life",
                startDate: .init(timeIntervalSince1970: 7200),
                endDate: .init(timeIntervalSince1970: 9000),
                isAllDay: false
            ),
        ]
    )

    #expect(overview.totalDuration == 5400)
    #expect(overview.buckets.count == 2)
    #expect(overview.buckets.first?.name == "Work")
}
