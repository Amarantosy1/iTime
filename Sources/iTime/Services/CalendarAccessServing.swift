import Foundation

public enum CalendarAuthorizationState: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

@MainActor
public protocol CalendarAccessServing {
    func authorizationState() -> CalendarAuthorizationState
    func requestAccess() async -> CalendarAuthorizationState
    func fetchCalendars() -> [CalendarSource]
    func fetchEvents(in range: TimeRangePreset, selectedCalendarIDs: [String]) -> [CalendarEventRecord]
}
