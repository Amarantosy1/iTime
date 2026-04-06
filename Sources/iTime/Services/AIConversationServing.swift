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

    func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft

    func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String
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

public struct AIConversationLongFormReportDraft: Equatable, Sendable {
    public let title: String
    public let content: String
    public let flowchart: AIConversationFlowchart?

    public init(title: String, content: String, flowchart: AIConversationFlowchart? = nil) {
        self.title = title
        self.content = content
        self.flowchart = flowchart
    }
}
