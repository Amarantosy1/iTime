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

@Test func customPresetRestoresAsDormantSelectionGroundwork() {
    let suite = "iTime.tests.custom-range-selection-restore"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.selectedRange = .custom

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.selectedRange == .custom)
}

@Test func defaultAIPreferencesUseDisabledOpenAICompatibleScaffold() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.aiAnalysisEnabled == false)
    #expect(preferences.aiBaseURL == "https://api.openai.com/v1")
    #expect(preferences.aiModel.isEmpty)
}

@Test func aiPreferencesPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.ai-preferences"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.aiAnalysisEnabled = true
    first.aiBaseURL = "https://example.com/v1"
    first.aiModel = "gpt-5-mini"

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.aiAnalysisEnabled == true)
    #expect(second.aiBaseURL == "https://example.com/v1")
    #expect(second.aiModel == "gpt-5-mini")
}

@Test func defaultAIProviderUsesOpenAI() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.defaultAIProvider == .openAI)
}
