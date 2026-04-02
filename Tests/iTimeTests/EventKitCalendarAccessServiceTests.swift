import Foundation
import Testing
@testable import iTime

@MainActor
@Test func dateIntervalForWeekCoversCurrentWeek() {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = Date(timeIntervalSince1970: 1_742_070_400)

    let interval = EventKitCalendarAccessService.dateInterval(
        for: .week,
        referenceDate: referenceDate,
        calendar: calendar
    )

    #expect(interval.duration == 7 * 24 * 3600)
    #expect(interval.start <= referenceDate)
    #expect(interval.end >= referenceDate)
}
