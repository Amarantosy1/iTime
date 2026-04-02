import Foundation
import Testing
@testable import iTime

@Test func defaultPreferencesUseTodayPresetAndNoSelectedCalendars() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.selectedRange == .today)
    #expect(preferences.selectedCalendarIDs.isEmpty)
}

@Test func defaultPreferencesSeedCustomDatesAroundToday() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.selectedRange == .today)
    #expect(preferences.customStartDate <= preferences.customEndDate)
}

@Test func customDatesPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.persisted-custom-range"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.customStartDate = Date(timeIntervalSince1970: 86_400)
    first.customEndDate = Date(timeIntervalSince1970: 172_800)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.customStartDate == Date(timeIntervalSince1970: 86_400))
    #expect(second.customEndDate == Date(timeIntervalSince1970: 172_800))
}
