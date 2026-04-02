import Testing
@testable import iTime

@Test func defaultPreferencesUseTodayPresetAndNoSelectedCalendars() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.selectedRange == .today)
    #expect(preferences.selectedCalendarIDs.isEmpty)
}
