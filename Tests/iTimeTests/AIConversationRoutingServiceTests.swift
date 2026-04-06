import Foundation
import Testing
@testable import iTime

private final class RecordingProviderConversationService: @unchecked Sendable, AIConversationServing {
    private(set) var askCount = 0
    private(set) var lastConfiguration: ResolvedAIProviderConfiguration?

    func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        lastConfiguration = configuration
    }

    func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        askCount += 1
        lastConfiguration = configuration
        return AIConversationMessage(
            id: UUID(),
            role: .assistant,
            content: "question",
            createdAt: .init(timeIntervalSince1970: 0)
        )
    }

    func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft {
        lastConfiguration = configuration
        return AIConversationSummaryDraft(
            headline: "headline",
            summary: "summary",
            findings: [],
            suggestions: []
        )
    }

    func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft {
        lastConfiguration = configuration
        return AIConversationLongFormReportDraft(
            title: "流水账标题",
            content: "流水账内容"
        )
    }

    func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        lastConfiguration = configuration
        return "• 会议偏多"
    }
}

@Test func conversationRouterUsesSelectedProvider() async throws {
    let openAI = RecordingProviderConversationService()
    let gemini = RecordingProviderConversationService()
    let router = AIConversationRoutingService(
        services: [
            .openAI: openAI,
            .gemini: gemini,
        ]
    )

    _ = try await router.askQuestion(
        context: .fixture(),
        history: [],
        configuration: .fixture(provider: .gemini)
    )

    #expect(openAI.askCount == 0)
    #expect(gemini.askCount == 1)
    #expect(gemini.lastConfiguration?.provider == .gemini)
}

private extension AIConversationContext {
    static func fixture() -> AIConversationContext {
        AIConversationContext(
            range: .week,
            rangeTitle: "本周",
            startDate: .init(timeIntervalSince1970: 0),
            endDate: .init(timeIntervalSince1970: 86_400),
            overviewSnapshot: AIOverviewSnapshot(
                rangeTitle: "本周",
                totalDurationText: "8h",
                totalEventCount: 4,
                topCalendarNames: ["工作"]
            ),
            events: [
                AIEventContext(
                    id: "1",
                    title: "需求评审",
                    calendarID: "work",
                    calendarName: "工作",
                    startDate: .init(timeIntervalSince1970: 0),
                    endDate: .init(timeIntervalSince1970: 3_600),
                    durationText: "1小时"
                ),
            ],
            latestMemorySummary: "最近会议偏多。"
        )
    }
}

private extension ResolvedAIProviderConfiguration {
    static func fixture(
        provider: AIProviderKind,
        baseURL: String? = nil,
        model: String = "gpt-5"
    ) -> ResolvedAIProviderConfiguration {
        ResolvedAIProviderConfiguration(
            provider: provider,
            baseURL: baseURL ?? provider.defaultBaseURL,
            model: model,
            apiKey: "secret-key",
            isEnabled: true
        )
    }
}
