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
            title: "长文标题",
            content: "长文内容"
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

private final class RecordingProviderHTTPSender: @unchecked Sendable, AIAnalysisHTTPSending {
    let responseData: Data
    let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(responseData: Data, statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: try #require(request.url),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}

@Test func conversationRouterUsesSelectedProvider() async throws {
    let openAI = RecordingProviderConversationService()
    let anthropic = RecordingProviderConversationService()
    let router = AIConversationRoutingService(
        services: [
            .openAI: openAI,
            .anthropic: anthropic,
        ]
    )

    _ = try await router.askQuestion(
        context: .fixture(),
        history: [],
        configuration: .fixture(provider: .anthropic)
    )

    #expect(openAI.askCount == 0)
    #expect(anthropic.askCount == 1)
    #expect(anthropic.lastConfiguration?.provider == .anthropic)
}

@Test func anthropicConversationServiceBuildsMessagesRequestAndParsesQuestion() async throws {
    let sender = RecordingProviderHTTPSender(
        responseData: Data(
            """
            {
              "content": [
                {
                  "type": "text",
                  "text": "{\\"question\\":\\"周二的需求评审主要做了什么？\\"}"
                }
              ]
            }
            """.utf8
        )
    )
    let service = AnthropicConversationService(httpSender: sender)

    let message = try await service.askQuestion(
        context: .fixture(),
        history: [],
        configuration: .fixture(
            provider: .anthropic,
            baseURL: "https://api.anthropic.com/v1",
            model: "claude-sonnet-4-5"
        )
    )

    let request = try #require(sender.lastRequest)
    let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })

    #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(request.value(forHTTPHeaderField: "x-api-key") == "secret-key")
    #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
    #expect(body.contains("\"model\":\"claude-sonnet-4-5\""))
    #expect(body.contains("需求评审"))
    #expect(message.content == "周二的需求评审主要做了什么？")
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
