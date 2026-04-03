import Foundation
import Testing
@testable import iTime

private func makeUTCGregorianCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

@Test func aggregateGroupsDurationByCalendar() {
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true),
        ]
    )

    let overview = aggregator.makeOverview(
        range: .today,
        interval: DateInterval(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 86_400)
        ),
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

@Test func aggregateBuildsDailySeriesAndSortsBuckets() {
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true),
        ]
        ,
        calendar: makeUTCGregorianCalendar()
    )
    let interval = DateInterval(
        start: Date(timeIntervalSince1970: 0),
        end: Date(timeIntervalSince1970: 259_200)
    )

    let overview = aggregator.makeOverview(
        range: .custom,
        interval: interval,
        events: [
            CalendarEventRecord(
                id: "1",
                title: "Focus",
                calendarID: "work",
                startDate: interval.start,
                endDate: interval.start.addingTimeInterval(3_600),
                isAllDay: false
            ),
            CalendarEventRecord(
                id: "2",
                title: "Dinner",
                calendarID: "life",
                startDate: interval.start.addingTimeInterval(180_000),
                endDate: interval.start.addingTimeInterval(181_800),
                isAllDay: false
            ),
        ]
    )

    #expect(overview.totalEventCount == 2)
    #expect(overview.longestDayDuration == 3_600)
    #expect(overview.dailyDurations.count == 3)
    #expect(overview.dailyDurations[0].totalDuration == 3_600)
    #expect(overview.dailyDurations[1].totalDuration == 0)
    #expect(overview.dailyDurations[2].totalDuration == 1_800)
    #expect(overview.buckets.map(\.name) == ["Work", "Life"])
}
