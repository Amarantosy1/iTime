import Foundation
import Testing
@testable import iTime

@Test func defaultPreferencesUseTodayPresetAndNoSelectedCalendars() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.selectedRange == .today)
    #expect(preferences.selectedCalendarIDs.isEmpty)
    #expect(preferences.reviewExcludedCalendarIDs.isEmpty)
}

@Test func defaultInterfaceThemeIsFlowing() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.interfaceTheme == .flowing)
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

@Test func reviewExcludedCalendarsPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.review-excluded-calendars"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.replaceReviewExcludedCalendars(with: ["private"])

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.reviewExcludedCalendarIDs == ["private"])
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

@Test func builtInAIServicesExistByDefault() {
    let preferences = UserPreferences(storage: .inMemory)

    let services = preferences.aiServiceEndpoints
    #expect(services.count == 3)
    #expect(services.map(\.providerKind) == [.openAI, .gemini, .deepSeek])
    #expect(services.allSatisfy { $0.isBuiltIn })
    #expect(preferences.defaultAIService?.providerKind == .openAI)
}

@Test func builtInAIServiceDefaultsContainRecommendedModel() {
    let preferences = UserPreferences(storage: .inMemory)

    let openAI = preferences.aiServiceEndpoints.first(where: { $0.providerKind == .openAI })
    let gemini = preferences.aiServiceEndpoints.first(where: { $0.providerKind == .gemini })
    let deepSeek = preferences.aiServiceEndpoints.first(where: { $0.providerKind == .deepSeek })

    #expect(openAI?.defaultModel == "gpt-5-mini")
    #expect(openAI?.models.contains("gpt-5-mini") == true)
    #expect(gemini?.defaultModel == "gemini-2.0-flash")
    #expect(gemini?.models.contains("gemini-2.0-flash") == true)
    #expect(deepSeek?.defaultModel == "deepseek-chat")
    #expect(deepSeek?.models.contains("deepseek-chat") == true)
}

@Test func defaultReviewReminderPreferencesAreDisabledWithNightDefaultTime() {
    let preferences = UserPreferences(storage: .inMemory)
    let components = Calendar.current.dateComponents([.hour, .minute], from: preferences.reviewReminderTime)

    #expect(preferences.reviewReminderEnabled == false)
    #expect(components.hour == 21)
    #expect(components.minute == 0)
}

@Test func reviewReminderPreferencesPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.review-reminder-preferences"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.reviewReminderEnabled = true
    first.reviewReminderTime = Date(timeIntervalSince1970: 86_400)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.reviewReminderEnabled == true)
    #expect(second.reviewReminderTime == Date(timeIntervalSince1970: 86_400))
}

@Test func interfaceThemePersistsAcrossPreferenceInstances() {
    let suite = "iTime.tests.interface-theme"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.interfaceTheme = .pure

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.interfaceTheme == .pure)
}

@Test func customThemeImageAndCropPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.custom-theme-image-crop"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.interfaceTheme = .custom
    first.customThemeImageName = "custom-theme-demo.jpg"
    first.customThemeScale = 1.8
    first.customThemeOffsetX = 0.22
    first.customThemeOffsetY = -0.31

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.interfaceTheme == .custom)
    #expect(second.customThemeImageName == "custom-theme-demo.jpg")
    #expect(second.customThemeScale == 1.8)
    #expect(second.customThemeOffsetX == 0.22)
    #expect(second.customThemeOffsetY == -0.31)
}

@Test func customThemePresetsPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.custom-theme-presets"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    _ = first.saveCustomThemePreset(
        displayName: "晨光",
        imageName: "preset-a.jpg",
        scale: 1.3,
        offsetX: 0.1,
        offsetY: -0.2
    )
    let secondPresetID = first.saveCustomThemePreset(
        displayName: "夜色",
        imageName: "preset-b.jpg",
        scale: 1.7,
        offsetX: -0.25,
        offsetY: 0.3
    )

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.customThemePresets.count == 2)
    #expect(second.selectedCustomThemePresetID == secondPresetID)
    #expect(second.customThemeImageName == "preset-b.jpg")
    #expect(second.customThemeScale == 1.7)
    #expect(second.customThemeOffsetX == -0.25)
    #expect(second.customThemeOffsetY == 0.3)
}

@Test func applyingCustomThemePresetUpdatesActiveCropFields() {
    let preferences = UserPreferences(storage: .inMemory)
    let firstPresetID = preferences.saveCustomThemePreset(
        displayName: "主题 A",
        imageName: "theme-a.jpg",
        scale: 1.2,
        offsetX: 0.2,
        offsetY: -0.1
    )
    _ = preferences.saveCustomThemePreset(
        displayName: "主题 B",
        imageName: "theme-b.jpg",
        scale: 1.8,
        offsetX: -0.3,
        offsetY: 0.4
    )

    preferences.applyCustomThemePreset(id: firstPresetID)

    #expect(preferences.selectedCustomThemePresetID == firstPresetID)
    #expect(preferences.interfaceTheme == .custom)
    #expect(preferences.customThemeImageName == "theme-a.jpg")
    #expect(preferences.customThemeScale == 1.2)
    #expect(preferences.customThemeOffsetX == 0.2)
    #expect(preferences.customThemeOffsetY == -0.1)
}
