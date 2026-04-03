import Foundation

public struct DeepSeekConversationService: AIConversationServing, Sendable {
    private let implementation: OpenAICompatibleAIConversationService

    public init(httpSender: AIAnalysisHTTPSending = URLSessionAIAnalysisHTTPSender()) {
        self.implementation = OpenAICompatibleAIConversationService(httpSender: httpSender)
    }

    public func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        try await implementation.validateConnection(configuration: configuration)
    }

    public func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        try await implementation.askQuestion(
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
        try await implementation.summarizeConversation(
            context: context,
            history: history,
            configuration: configuration
        )
    }
}
