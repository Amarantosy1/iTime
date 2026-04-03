import Foundation
import Testing
@testable import iTime

private final class InMemoryScopedAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    private var values: [AIProviderKind: String] = [:]

    func loadAPIKey(for provider: AIProviderKind) throws -> String {
        values[provider] ?? ""
    }

    func saveAPIKey(_ apiKey: String, for provider: AIProviderKind) throws {
        values[provider] = apiKey
    }
}

@Test func aiProviderPreferencesPersistSeparately() {
    let suite = "iTime.tests.ai-provider-preferences"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    first.defaultAIProvider = .anthropic
    first.setAIProviderEnabled(true, for: .openAI)
    first.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    first.setAIProviderModel("gpt-5", for: .openAI)
    first.setAIProviderEnabled(true, for: .anthropic)
    first.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    first.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    #expect(second.defaultAIProvider == .anthropic)
    #expect(second.aiProviderConfiguration(for: .openAI).model == "gpt-5")
    #expect(second.aiProviderConfiguration(for: .anthropic).model == "claude-sonnet-4-5")
    #expect(second.aiProviderConfiguration(for: .gemini).isEnabled == false)
}

@Test func aiAPIKeyStoreReadsAndWritesKeysPerProvider() throws {
    let store = InMemoryScopedAIKeyStore()

    try store.saveAPIKey("openai-key", for: .openAI)
    try store.saveAPIKey("anthropic-key", for: .anthropic)

    #expect(try store.loadAPIKey(for: .openAI) == "openai-key")
    #expect(try store.loadAPIKey(for: .anthropic) == "anthropic-key")
    #expect(try store.loadAPIKey(for: .gemini).isEmpty)
}
