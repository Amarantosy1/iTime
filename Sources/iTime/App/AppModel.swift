import Foundation
import Observation

@MainActor
@Observable
public final class AppModel {
    public private(set) var authorizationState: CalendarAuthorizationState
    public private(set) var availableCalendars: [CalendarSource]
    public private(set) var overview: TimeOverview?

    public var preferences: UserPreferences

    private let service: CalendarAccessServing

    public init(service: CalendarAccessServing, preferences: UserPreferences) {
        self.service = service
        self.preferences = preferences
        self.authorizationState = service.authorizationState()
        self.availableCalendars = []
    }

    private func normalizedRuntimeRange(_ range: TimeRangePreset) -> TimeRangePreset {
        range.isRuntimeSelectable ? range : .today
    }

    public var liveSelectedRange: TimeRangePreset {
        normalizedRuntimeRange(preferences.selectedRange)
    }

    public func refresh() async {
        authorizationState = service.authorizationState()

        guard authorizationState == .authorized else {
            availableCalendars = []
            overview = nil
            return
        }

        var fetchedCalendars = service.fetchCalendars()
        let selectedIDs = preferences.selectedCalendarIDs

        if selectedIDs.isEmpty {
            fetchedCalendars = fetchedCalendars.map {
                CalendarSource(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: true)
            }
            preferences.replaceSelectedCalendars(with: fetchedCalendars.map(\.id))
        } else {
            fetchedCalendars = fetchedCalendars.map {
                CalendarSource(
                    id: $0.id,
                    name: $0.name,
                    colorHex: $0.colorHex,
                    isSelected: selectedIDs.contains($0.id)
                )
            }
        }

        availableCalendars = fetchedCalendars

        let range = normalizedRuntimeRange(preferences.selectedRange)
        let selectedCalendarIDs = fetchedCalendars.filter(\.isSelected).map(\.id)
        let events = service.fetchEvents(
            in: range,
            selectedCalendarIDs: selectedCalendarIDs
        )
        let aggregator = CalendarStatisticsAggregator(
            calendarLookup: Dictionary(uniqueKeysWithValues: fetchedCalendars.map { ($0.id, $0) })
        )
        overview = aggregator.makeOverview(range: range, events: events)
    }

    public func requestAccessIfNeeded() async {
        if authorizationState == .notDetermined {
            authorizationState = await service.requestAccess()
        }
        await refresh()
    }

    public func setRange(_ range: TimeRangePreset) async {
        preferences.selectedRange = range
        await refresh()
    }

    public func toggleCalendarSelection(id: String) async {
        var updated = Set(preferences.selectedCalendarIDs)
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        preferences.replaceSelectedCalendars(with: Array(updated))
        await refresh()
    }
}
