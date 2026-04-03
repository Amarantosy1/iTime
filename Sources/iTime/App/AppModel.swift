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
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        service: CalendarAccessServing,
        preferences: UserPreferences,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.calendar = calendar
        self.now = now
        self.preferences = preferences
        self.authorizationState = service.authorizationState()
        self.availableCalendars = []
    }

    public var liveSelectedRange: TimeRangePreset {
        preferences.selectedRange.isRuntimeSelectable ? preferences.selectedRange : .today
    }

    private var activeRange: TimeRangePreset {
        preferences.selectedRange
    }

    private var activeInterval: DateInterval {
        resolveInterval(for: activeRange)
    }

    private func resolveInterval(for range: TimeRangePreset) -> DateInterval {
        let referenceDate = now()

        switch range {
        case .today:
            return calendar.dateInterval(of: .day, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 86_400)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 604_800)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
                ?? DateInterval(start: referenceDate, duration: 2_592_000)
        case .custom:
            let start = calendar.startOfDay(for: preferences.customStartDate)
            let endStart = calendar.startOfDay(for: preferences.customEndDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endStart) ?? endStart.addingTimeInterval(86_400)
            return DateInterval(start: start, end: end)
        }
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

        let range = activeRange
        let selectedCalendarIDs = fetchedCalendars.filter(\.isSelected).map(\.id)
        let events = service.fetchEvents(
            in: activeInterval,
            selectedCalendarIDs: selectedCalendarIDs
        )
        let aggregator = CalendarStatisticsAggregator(
            calendarLookup: Dictionary(uniqueKeysWithValues: fetchedCalendars.map { ($0.id, $0) }),
            calendar: calendar
        )
        overview = aggregator.makeOverview(range: range, interval: activeInterval, events: events)
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

    public func setCustomDateRange(start: Date, end: Date) async {
        let range = StatisticsDateRange(startDate: start, endDate: end)
        preferences.customStartDate = range.startDate
        preferences.customEndDate = range.endDate
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
