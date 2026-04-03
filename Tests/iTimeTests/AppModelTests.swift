import Foundation
import Testing
@testable import iTime

private struct StubCalendarAccessService: CalendarAccessServing {
    let state: CalendarAuthorizationState
    let calendars: [CalendarSource]
    let events: [CalendarEventRecord]

    func authorizationState() -> CalendarAuthorizationState { state }
    func requestAccess() async -> CalendarAuthorizationState { state }
    func fetchCalendars() -> [CalendarSource] { calendars }
    func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
}

private final class RecordingCalendarAccessService: CalendarAccessServing {
    let state: CalendarAuthorizationState
    let calendars: [CalendarSource]
    let events: [CalendarEventRecord]
    private(set) var fetchedIntervals: [DateInterval] = []

    init(
        state: CalendarAuthorizationState,
        calendars: [CalendarSource],
        events: [CalendarEventRecord]
    ) {
        self.state = state
        self.calendars = calendars
        self.events = events
    }

    func authorizationState() -> CalendarAuthorizationState { state }
    func requestAccess() async -> CalendarAuthorizationState { state }
    func fetchCalendars() -> [CalendarSource] { calendars }

    func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        fetchedIntervals.append(interval)
        return events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
}

private func makeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.firstWeekday = 2
    return calendar
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.calendar = makeCalendar()
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date!
}

@MainActor
@Test func refreshLoadsCalendarsAndOverview() async {
    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "Focus",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3600),
                isAllDay: false
            ),
        ]
    )
    let model = AppModel(service: service, preferences: UserPreferences(storage: .inMemory))

    await model.refresh()

    #expect(model.authorizationState == .authorized)
    #expect(model.availableCalendars.count == 1)
    #expect(model.overview?.totalDuration == 3600)
}

@MainActor
@Test func refreshSelectsAllCalendarsByDefaultWhenNoStoredSelectionExists() async {
    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: false),
            CalendarSource(id: "life", name: "生活", colorHex: "#50E3C2", isSelected: false),
        ],
        events: []
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.refresh()

    #expect(Set(model.availableCalendars.map(\.id)) == ["work", "life"])
    #expect(Set(preferences.selectedCalendarIDs) == ["work", "life"])
    #expect(model.availableCalendars.allSatisfy { $0.isSelected })
}

@MainActor
@Test func togglingCalendarSelectionUpdatesStoredSelection() async {
    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: false),
            CalendarSource(id: "life", name: "生活", colorHex: "#50E3C2", isSelected: false),
        ],
        events: []
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.refresh()
    await model.toggleCalendarSelection(id: "life")

    #expect(model.availableCalendars.first(where: { $0.id == "life" })?.isSelected == false)
    #expect(Set(preferences.selectedCalendarIDs) == ["work"])
}

@MainActor
@Test func refreshUsesResolvedCustomInterval() async {
    let service = RecordingCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        events: []
    )
    let calendar = makeCalendar()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .custom
    preferences.customStartDate = makeDate(2026, 4, 3, hour: 18, minute: 45)
    preferences.customEndDate = makeDate(2026, 4, 5, hour: 9, minute: 15)
    let model = AppModel(
        service: service,
        preferences: preferences,
        calendar: calendar,
        now: { makeDate(2026, 4, 3, hour: 12) }
    )

    await model.refresh()

    #expect(preferences.selectedRange == .custom)
    #expect(service.fetchedIntervals == [
        DateInterval(start: makeDate(2026, 4, 3), end: makeDate(2026, 4, 6))
    ])
    #expect(model.overview?.range == .custom)
}

@MainActor
@Test func setCustomDateRangeClampsInvalidRange() async {
    let service = RecordingCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        events: []
    )
    let calendar = makeCalendar()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .custom
    let model = AppModel(
        service: service,
        preferences: preferences,
        calendar: calendar,
        now: { makeDate(2026, 4, 3, hour: 12) }
    )

    await model.setCustomDateRange(
        start: makeDate(2026, 4, 10, hour: 14),
        end: makeDate(2026, 4, 8, hour: 8)
    )

    #expect(preferences.customStartDate == makeDate(2026, 4, 8, hour: 8))
    #expect(preferences.customEndDate == makeDate(2026, 4, 10, hour: 14))
    #expect(service.fetchedIntervals.last == DateInterval(
        start: makeDate(2026, 4, 8),
        end: makeDate(2026, 4, 11)
    ))
}

@MainActor
@Test func presetRangesResolveToConcreteIntervals() async {
    let service = RecordingCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        events: []
    )
    let calendar = makeCalendar()
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(
        service: service,
        preferences: preferences,
        calendar: calendar,
        now: { makeDate(2026, 4, 3, hour: 15, minute: 30) }
    )

    await model.setRange(.today)
    await model.setRange(.week)
    await model.setRange(.month)

    #expect(service.fetchedIntervals == [
        DateInterval(start: makeDate(2026, 4, 3), end: makeDate(2026, 4, 4)),
        DateInterval(start: makeDate(2026, 3, 30), end: makeDate(2026, 4, 6)),
        DateInterval(start: makeDate(2026, 4, 1), end: makeDate(2026, 5, 1)),
    ])
    #expect(model.overview?.range == .month)
}
