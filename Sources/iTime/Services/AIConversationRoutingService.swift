import Foundation

public struct AIConversationRoutingService: AIConversationServing, Sendable {
    private let services: [AIProviderKind: any AIConversationServing]

    public init(services: [AIProviderKind: any AIConversationServing]) {
        self.services = services
    }

    public func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        try await service.validateConnection(configuration: configuration)
    }

    public func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        return try await service.askQuestion(
            context: context,
            history: history,
            configuration: configuration
        )
    }

    public func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        return try await service.summarizeConversation(
            context: context,
            history: history,
            configuration: configuration
        )
    }

    public func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        return try await service.generateLongFormReport(
            session: session,
            summary: summary,
            configuration: configuration
        )
    }
}
