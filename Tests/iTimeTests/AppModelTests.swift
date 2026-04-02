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
    func fetchEvents(in range: TimeRangePreset, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
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
