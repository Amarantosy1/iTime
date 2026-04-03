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

private final class RecordingCalendarAccessService: CalendarAccessServing {
    let state: CalendarAuthorizationState
    let calendars: [CalendarSource]
    let events: [CalendarEventRecord]
    private(set) var fetchedRanges: [TimeRangePreset] = []

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

    func fetchEvents(in range: TimeRangePreset, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        fetchedRanges.append(range)
        return events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
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
@Test func customRangeIsNormalizedOutOfRuntimeSelection() async {
    let service = RecordingCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        events: []
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.setRange(.custom)

    #expect(preferences.selectedRange == .today)
    #expect(service.fetchedRanges == [.today])
    #expect(model.overview?.range == .today)
}
