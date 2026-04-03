import Foundation
import Testing
@testable import iTime

private final class InMemoryScopedAIKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    private var values: [UUID: String] = [:]

    func loadAPIKey(for serviceID: UUID) throws -> String {
        values[serviceID] ?? ""
    }

    func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws {
        values[serviceID] = apiKey
    }
}

@Test func aiServicesMigrateFromLegacyProviderPreferences() {
    let suite = "iTime.tests.ai-services"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    first.defaultAIProvider = .anthropic
    first.setAIProviderEnabled(true, for: .openAI)
    first.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    first.setAIProviderModel("gpt-5", for: .openAI)
    first.setAIProviderEnabled(true, for: .anthropic)
    first.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    first.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    let services = second.aiServiceEndpoints
    #expect(services.count == 4)
    #expect(services.first(where: { $0.providerKind == .openAI })?.defaultModel == "gpt-5")
    #expect(services.first(where: { $0.providerKind == .anthropic })?.isEnabled == true)
    #expect(second.defaultAIService?.providerKind == .anthropic)
}

@Test func aiServicesAllowAddingAndDeletingCustomServices() {
    let preferences = UserPreferences(storage: .inMemory)
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "OpenAI Proxy",
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-5", "gpt-5-mini"],
        defaultModel: "gpt-5-mini"
    )

    preferences.saveAIService(service)
    #expect(preferences.aiServiceEndpoints.contains(where: { $0.id == service.id }))

    preferences.setDefaultAIServiceID(service.id)
    #expect(preferences.defaultAIServiceID == service.id)

    preferences.deleteAIService(id: service.id)
    #expect(preferences.aiServiceEndpoints.contains(where: { $0.id == service.id }) == false)
}

@Test func deletingDefaultCustomServiceFallsBackToFirstAvailableService() {
    let preferences = UserPreferences(storage: .inMemory)
    let service = AIServiceEndpoint.customOpenAICompatible(
        displayName: "Proxy",
        baseURL: "https://proxy.example.com/v1"
    )

    preferences.saveAIService(service)
    preferences.setDefaultAIServiceID(service.id)
    preferences.deleteAIService(id: service.id)

    #expect(preferences.defaultAIService != nil)
    #expect(preferences.defaultAIServiceID != service.id)
}

@Test func aiAPIKeyStoreReadsAndWritesKeysPerService() throws {
    let store = InMemoryScopedAIKeyStore()
    let openAIServiceID = UUID()
    let anthropicServiceID = UUID()

    try store.saveAPIKey("openai-key", for: openAIServiceID)
    try store.saveAPIKey("anthropic-key", for: anthropicServiceID)

    #expect(try store.loadAPIKey(for: openAIServiceID) == "openai-key")
    #expect(try store.loadAPIKey(for: anthropicServiceID) == "anthropic-key")
    #expect(try store.loadAPIKey(for: UUID()).isEmpty)
}
