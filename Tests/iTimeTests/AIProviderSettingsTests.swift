import Foundation
import Testing
@testable import iTime

private final class InMemoryScopedAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    private var values: [UUID: String] = [:]

    func loadAPIKey(for mountID: UUID) throws -> String {
        values[mountID] ?? ""
    }

    func saveAPIKey(_ apiKey: String, for mountID: UUID) throws {
        values[mountID] = apiKey
    }
}

@Test func aiProviderMountsMigrateFromLegacyProviderPreferences() {
    let suite = "iTime.tests.ai-provider-mounts"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    first.defaultAIProvider = .anthropic
    first.setAIProviderEnabled(true, for: .openAI)
    first.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    first.setAIProviderModel("gpt-5", for: .openAI)
    first.setAIProviderEnabled(true, for: .anthropic)
    first.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    first.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    let mounts = second.aiProviderMounts
    #expect(mounts.count == 4)
    #expect(mounts.first(where: { $0.providerType == .openAI })?.defaultModel == "gpt-5")
    #expect(mounts.first(where: { $0.providerType == .anthropic })?.isEnabled == true)
    #expect(second.defaultAIMount?.providerType == .anthropic)
}

@Test func aiProviderMountsAllowAddingAndDeletingCustomMounts() {
    let preferences = UserPreferences(storage: .inMemory)
    let mount = AIProviderMount.custom(
        displayName: "OpenAI Proxy",
        providerType: .openAI,
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-5", "gpt-5-mini"],
        defaultModel: "gpt-5-mini"
    )

    preferences.saveAIMount(mount)
    #expect(preferences.aiProviderMounts.contains(where: { $0.id == mount.id }))

    preferences.setDefaultAIMountID(mount.id)
    #expect(preferences.defaultAIMountID == mount.id)

    preferences.deleteAIMount(id: mount.id)
    #expect(preferences.aiProviderMounts.contains(where: { $0.id == mount.id }) == false)
}

@Test func deletingDefaultCustomMountFallsBackToFirstAvailableMount() {
    let preferences = UserPreferences(storage: .inMemory)
    let mount = AIProviderMount.custom(
        displayName: "Proxy",
        providerType: .openAI,
        baseURL: "https://proxy.example.com/v1"
    )

    preferences.saveAIMount(mount)
    preferences.setDefaultAIMountID(mount.id)
    preferences.deleteAIMount(id: mount.id)

    #expect(preferences.defaultAIMount != nil)
    #expect(preferences.defaultAIMountID != mount.id)
}

@Test func aiAPIKeyStoreReadsAndWritesKeysPerMount() throws {
    let store = InMemoryScopedAIKeyStore()
    let openAIMountID = UUID()
    let anthropicMountID = UUID()

    try store.saveAPIKey("openai-key", for: openAIMountID)
    try store.saveAPIKey("anthropic-key", for: anthropicMountID)

    #expect(try store.loadAPIKey(for: openAIMountID) == "openai-key")
    #expect(try store.loadAPIKey(for: anthropicMountID) == "anthropic-key")
    #expect(try store.loadAPIKey(for: UUID()).isEmpty)
}
