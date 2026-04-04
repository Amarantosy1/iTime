import Foundation
import Testing
@testable import iTime

private final class ConversationRecordingAIHTTPSender: @unchecked Sendable, AIAnalysisHTTPSending {
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

@Test func openAICompatibleConversationServiceBuildsQuestionRequestUsingEventsAndMemory() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"question\\":\\"周二下午的需求评审主要产出了什么？\\"}"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let context = AIConversationContext(
        range: .week,
        rangeTitle: "本周",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: "本周",
            totalDurationText: "12h",
            totalEventCount: 6,
            topCalendarNames: ["工作", "学习"]
        ),
        events: [
            AIEventContext(
                id: "1",
                title: "深度工作",
                calendarID: "work",
                calendarName: "工作",
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                endDate: Date(timeIntervalSince1970: 1_700_003_600),
                durationText: "1小时"
            ),
            AIEventContext(
                id: "2",
                title: "需求评审",
                calendarID: "work",
                calendarName: "工作",
                startDate: Date(timeIntervalSince1970: 1_700_007_200),
                endDate: Date(timeIntervalSince1970: 1_700_010_800),
                durationText: "1小时"
            ),
        ],
        latestMemorySummary: "最近几轮复盘都提到会议偏多。"
    )

    let reply = try await service.askQuestion(
        context: context,
        history: [],
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI,
            baseURL: "https://example.com/v1",
            model: "gpt-5-mini",
            apiKey: "secret-key",
            isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    let bodyData = try #require(request.httpBody)
    let body = try #require(String(data: bodyData, encoding: .utf8))
    #expect(body.contains("深度工作"))
    #expect(body.contains("需求评审"))
    #expect(body.contains("最近几轮复盘都提到会议偏多。"))
    #expect(body.contains("结合具体的数据或用户谈及的情况"))
    #expect(body.contains("只输出 JSON"))
    #expect(reply.role == .assistant)
    #expect(reply.content == "周二下午的需求评审主要产出了什么？")
}

@Test func openAICompatibleConversationServiceSummarizesConversationIntoStructuredDraft() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"headline\\":\\"本周工作会议偏多\\",\\"summary\\":\\"你本周大量时间花在评审和同步上，深度工作时间不足。\\",\\"findings\\":[\\"会议集中在周二和周三\\"],\\"suggestions\\":[\\"给深度工作预留不可打断时段\\"]}"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let context = AIConversationContext(
        range: .week,
        rangeTitle: "本周",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: "本周",
            totalDurationText: "12h",
            totalEventCount: 6,
            topCalendarNames: ["工作", "学习"]
        ),
        events: [
            AIEventContext(
                id: "2",
                title: "需求评审",
                calendarID: "work",
                calendarName: "工作",
                startDate: Date(timeIntervalSince1970: 1_700_007_200),
                endDate: Date(timeIntervalSince1970: 1_700_010_800),
                durationText: "1小时"
            ),
        ],
        latestMemorySummary: nil
    )

    let draft = try await service.summarizeConversation(
        context: context,
        history: [
            AIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "这次需求评审主要在做什么？",
                createdAt: Date(timeIntervalSince1970: 1_700_010_000)
            ),
            AIConversationMessage(
                id: UUID(),
                role: .user,
                content: "主要在对齐需求变更和下周排期。",
                createdAt: Date(timeIntervalSince1970: 1_700_010_100)
            ),
        ],
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI,
            baseURL: "https://example.com/v1",
            model: "gpt-5-mini",
            apiKey: "secret-key",
            isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    let bodyData = try #require(request.httpBody)
    let body = try #require(String(data: bodyData, encoding: .utf8))
    #expect(body.contains("关于时间使用规律或问题"))
    #expect(body.contains("具体建议，说清楚做什么"))

    #expect(draft.headline == "本周工作会议偏多")
    #expect(draft.summary == "你本周大量时间花在评审和同步上，深度工作时间不足。")
    #expect(draft.findings == ["会议集中在周二和周三"])
    #expect(draft.suggestions == ["给深度工作预留不可打断时段"])
}

@Test func openAICompatibleConversationServiceBuildsLongFormRequestUsingConversationMessages() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"title\\":\\"本周复盘：沟通任务挤压深度工作\\",\\"content\\":\\"这是一篇正式长文复盘。\\"}"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let session = AIConversationSession(
        id: UUID(),
        serviceID: AIProviderKind.openAI.builtInServiceID,
        serviceDisplayName: "OpenAI",
        provider: .openAI,
        model: "gpt-5-mini",
        range: .week,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        completedAt: Date(timeIntervalSince1970: 1_700_086_400),
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(
            rangeTitle: "本周",
            totalDurationText: "12h",
            totalEventCount: 6,
            topCalendarNames: ["工作", "学习"]
        ),
        messages: [
            AIConversationMessage(
                id: UUID(),
                role: .assistant,
                content: "周二下午的需求评审主要产出了什么？",
                createdAt: Date(timeIntervalSince1970: 1_700_010_000)
            ),
            AIConversationMessage(
                id: UUID(),
                role: .user,
                content: "主要在对齐需求变更和下周排期。",
                createdAt: Date(timeIntervalSince1970: 1_700_010_100)
            ),
        ]
    )
    let summary = AIConversationSummary(
        id: UUID(),
        sessionID: session.id,
        serviceID: session.serviceID,
        serviceDisplayName: session.serviceDisplayName,
        provider: session.provider,
        model: session.model,
        range: session.range,
        startDate: session.startDate,
        endDate: session.endDate,
        createdAt: session.endDate,
        headline: "本周工作会议偏多",
        summary: "这段文字不该成为长文的主输入。",
        findings: ["会议密度偏高"],
        suggestions: ["预留深度工作时间"],
        overviewSnapshot: session.overviewSnapshot
    )

    let draft = try await service.generateLongFormReport(
        session: session,
        summary: summary,
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI,
            baseURL: "https://example.com/v1",
            model: "gpt-5-mini",
            apiKey: "secret-key",
            isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    let bodyData = try #require(request.httpBody)
    let body = try #require(String(data: bodyData, encoding: .utf8))
    #expect(body.contains("周二下午的需求评审主要产出了什么？"))
    #expect(body.contains("主要在对齐需求变更和下周排期。"))
    #expect(body.contains("这段文字不该成为长文的主输入。") == false)
    #expect(body.contains("必须总结对话中的所有核心内容"))
    #expect(body.contains("事实与接纳"))
    #expect(body.contains("\"type\":\"json_object\"") || body.contains("\"type\" : \"json_object\""))
    #expect(draft.title == "本周复盘：沟通任务挤压深度工作")
    #expect(draft.content == "这是一篇正式长文复盘。")
}

@Test func openAICompatibleConversationServiceStripsMarkdownFencedJSONResponse() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "```json\\n{\\"title\\":\\"本周复盘\\",\\"content\\":\\"这是一篇文章。\\"}\\n```"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let session = AIConversationSession(
        id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
        model: "gpt-5-mini", range: .week,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        startedAt: Date(timeIntervalSince1970: 1_700_000_000), completedAt: nil,
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(rangeTitle: "本周", totalDurationText: "12h", totalEventCount: 3, topCalendarNames: []),
        messages: []
    )
    let summary = AIConversationSummary(
        id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "OpenAI",
        provider: .openAI, model: "gpt-5-mini", range: .week,
        startDate: session.startDate, endDate: session.endDate,
        createdAt: session.endDate, headline: "标题",
        summary: "摘要", findings: [], suggestions: [],
        overviewSnapshot: session.overviewSnapshot
    )

    let draft = try await service.generateLongFormReport(
        session: session, summary: summary,
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI, baseURL: "https://example.com/v1",
            model: "gpt-5-mini", apiKey: "key", isEnabled: true
        )
    )

    #expect(draft.title == "本周复盘")
    #expect(draft.content == "这是一篇文章。")
}

@Test func anthropicConversationServiceUsesHigherMaxTokensForLongFormReport() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "content": [
                { "type": "text", "text": "{\\"title\\":\\"复盘\\",\\"content\\":\\"内容。\\"}" }
              ]
            }
            """.utf8
        )
    )
    let service = AnthropicConversationService(httpSender: sender)
    let session = AIConversationSession(
        id: UUID(), serviceID: nil, serviceDisplayName: "Anthropic", provider: .anthropic,
        model: "claude-opus-4-6", range: .week,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        startedAt: Date(timeIntervalSince1970: 1_700_000_000), completedAt: nil,
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(rangeTitle: "本周", totalDurationText: "8h", totalEventCount: 4, topCalendarNames: []),
        messages: []
    )
    let summary = AIConversationSummary(
        id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "Anthropic",
        provider: .anthropic, model: "claude-opus-4-6", range: .week,
        startDate: session.startDate, endDate: session.endDate,
        createdAt: session.endDate, headline: "标题",
        summary: "摘要", findings: [], suggestions: [],
        overviewSnapshot: session.overviewSnapshot
    )

    _ = try await service.generateLongFormReport(
        session: session, summary: summary,
        configuration: ResolvedAIProviderConfiguration(
            provider: .anthropic, baseURL: "https://api.anthropic.com",
            model: "claude-opus-4-6", apiKey: "key", isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    let bodyData = try #require(request.httpBody)
    let body = try #require(String(data: bodyData, encoding: .utf8))
    #expect(body.contains("4096"))
}

@Test func geminiConversationServiceIncludesJsonMimeTypeInRequest() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      { "text": "{\\"question\\":\\"这周你最想改变什么？\\"}" }
                    ]
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = GeminiConversationService(httpSender: sender)
    let context = AIConversationContext(
        range: .week, rangeTitle: "本周",
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        endDate: Date(timeIntervalSince1970: 1_700_086_400),
        overviewSnapshot: AIOverviewSnapshot(rangeTitle: "本周", totalDurationText: "8h", totalEventCount: 2, topCalendarNames: []),
        events: [], latestMemorySummary: nil
    )

    _ = try await service.askQuestion(
        context: context, history: [],
        configuration: ResolvedAIProviderConfiguration(
            provider: .gemini, baseURL: "https://generativelanguage.googleapis.com",
            model: "gemini-2.0-flash", apiKey: "key", isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    let bodyData = try #require(request.httpBody)
    let body = try #require(String(data: bodyData, encoding: .utf8))
    #expect(body.contains("response_mime_type"))
}
