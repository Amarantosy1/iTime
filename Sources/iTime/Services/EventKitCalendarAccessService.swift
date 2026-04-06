import EventKit
import Foundation

@MainActor
public final class EventKitCalendarAccessService: CalendarAccessServing {
    private var store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func authorizationState() -> CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .notDetermined
        @unknown default:
            .restricted
        }
    }

    public func requestAccess() async -> CalendarAuthorizationState {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            return await settleAuthorizationState()
        }

        let state = await settleAuthorizationState()
        if state == .authorized {
            // Recreate the event store after TCC permission transitions to avoid stale reads.
            store = EKEventStore()
        }
        return state
    }

    private func settleAuthorizationState() async -> CalendarAuthorizationState {
        let maxAttempts = 5
        for attempt in 0..<maxAttempts {
            let state = authorizationState()
            if state != .notDetermined {
                return state
            }
            if attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        return authorizationState()
    }

    public func fetchCalendars() -> [CalendarSource] {
        store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map { calendar in
                CalendarSource(
                    id: calendar.calendarIdentifier,
                    name: calendar.title,
                    colorHex: calendar.cgColor.hexString,
                    isSelected: false
                )
            }
    }

    public func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        let visibleCalendars = store.calendars(for: .event).filter {
            selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarIdentifier)
        }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: visibleCalendars)
        return store.events(matching: predicate).map { event in
            CalendarEventRecord(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title,
                calendarID: event.calendar.calendarIdentifier,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }
    }

    public static func dateInterval(for range: TimeRangePreset, referenceDate: Date, calendar: Calendar) -> DateInterval {
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
            preconditionFailure("Custom interval resolution requires explicit dates and is handled in AppModel")
        }
    }
}
