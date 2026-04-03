import Foundation

public protocol AIConversationServing: Sendable {
    func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws

    func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage

    func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft
}

public struct AIConversationSummaryDraft: Equatable, Sendable {
    public let headline: String
    public let summary: String
    public let findings: [String]
    public let suggestions: [String]

    public init(
        headline: String,
        summary: String,
        findings: [String],
        suggestions: [String]
    ) {
        self.headline = headline
        self.summary = summary
        self.findings = findings
        self.suggestions = suggestions
    }
}
