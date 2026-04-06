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
    #expect(body.contains("\"headline\"") == false)
    #expect(body.contains("关于时间使用规律或问题"))
    #expect(body.contains("具体建议，说清楚做什么"))
    #expect(body.contains("行内代码包裹"))
    #expect(body.contains("Markdown 加粗语法"))
    #expect(body.contains("fenced code block"))

    #expect(draft.headline == OpenAICompatibleAIConversationService.formattedSummaryHeadline(
        startDate: context.startDate,
        endDate: context.endDate
    ))
    #expect(draft.summary == "你本周大量时间花在评审和同步上，深度工作时间不足。")
    #expect(draft.findings == ["会议集中在周二和周三"])
    #expect(draft.suggestions == ["给深度工作预留不可打断时段"])
}

@Test func formattedSummaryHeadlineUsesYYYYMMDDFormat() {
    let calendar = Calendar(identifier: .gregorian)
    let timezone = TimeZone(secondsFromGMT: 0)!
    var components = DateComponents()
    components.calendar = calendar
    components.timeZone = timezone
    components.year = 2026
    components.month = 4
    components.day = 5
    let date = components.date!

    let headline = OpenAICompatibleAIConversationService.formattedSummaryHeadline(
        startDate: date,
        endDate: date.addingTimeInterval(86_400),
        timeZone: timezone,
        calendar: calendar
    )

    #expect(headline == "2026-04-05")
}

@Test func formattedSummaryHeadlineUsesDateRangeWhenSpansMultipleDays() {
    let calendar = Calendar(identifier: .gregorian)
    let timezone = TimeZone(secondsFromGMT: 0)!
    var startComponents = DateComponents()
    startComponents.calendar = calendar
    startComponents.timeZone = timezone
    startComponents.year = 2026
    startComponents.month = 4
    startComponents.day = 1
    let start = startComponents.date!

    var endComponents = DateComponents()
    endComponents.calendar = calendar
    endComponents.timeZone = timezone
    endComponents.year = 2026
    endComponents.month = 4
    endComponents.day = 4
    let end = endComponents.date!

    let headline = OpenAICompatibleAIConversationService.formattedSummaryHeadline(
        startDate: start,
        endDate: end,
        timeZone: timezone,
        calendar: calendar
    )

    #expect(headline == "2026-04-01~2026-04-03")
}

@Test func openAICompatibleConversationServiceBuildsLongFormRequestUsingConversationMessages() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"title\\":\\"本周复盘：沟通任务挤压深度工作\\",\\"content\\":\\"这是一篇正式流水账复盘。\\"}"
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
        summary: "这段文字不该成为流水账的主输入。",
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
    #expect(body.contains("这段文字不该成为流水账的主输入。") == false)
    #expect(body.contains("流水账复盘"))
    #expect(body.contains("不要渲染感情"))
    #expect(body.contains("节点式流程图") == false)
    #expect(body.contains("\"flowchart\"") == false)
    #expect(body.contains("\"type\":\"json_object\"") || body.contains("\"type\" : \"json_object\""))
    #expect(draft.title == "本周复盘：沟通任务挤压深度工作")
    #expect(draft.content == "这是一篇正式流水账复盘。")
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

@Test func openAICompatibleLongFormReportIncludesFlowchartWhenPresentInResponse() async throws {
        let responseJSON = """
        {
            "choices": [{
                "message": {
                    "content": "{\\\"title\\\":\\\"当日复盘\\\",\\\"content\\\":\\\"流水账正文。\\\",\\\"flowchart\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"n1\\\",\\\"timeRange\\\":\\\"09:00-09:30\\\",\\\"title\\\":\\\"早会\\\",\\\"calendarName\\\":\\\"工作\\\"},{\\\"id\\\":\\\"n2\\\",\\\"timeRange\\\":\\\"09:30-11:00\\\",\\\"title\\\":\\\"写代码\\\",\\\"calendarName\\\":null}],\\\"edges\\\":[{\\\"from\\\":\\\"n1\\\",\\\"to\\\":\\\"n2\\\"}]}}"
                }
            }]
        }
        """
        let sender = ConversationRecordingAIHTTPSender(responseData: Data(responseJSON.utf8))
        let service = OpenAICompatibleAIConversationService(httpSender: sender)
        let session = AIConversationSession(
                id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
                model: "gpt-5-mini", range: .today,
                startDate: Date(timeIntervalSince1970: 0),
                endDate: Date(timeIntervalSince1970: 86_400),
                startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
                status: .completed,
                overviewSnapshot: AIOverviewSnapshot(rangeTitle: "今天", totalDurationText: "3h", totalEventCount: 2, topCalendarNames: ["工作"]),
                messages: []
        )
        let summary = AIConversationSummary(
                id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "OpenAI",
                provider: .openAI, model: "gpt-5-mini", range: .today,
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
        #expect(draft.flowchart?.nodes.count == 2)
        #expect(draft.flowchart?.nodes.first?.id == "n1")
        #expect(draft.flowchart?.nodes.first?.title == "早会")
        #expect(draft.flowchart?.edges.count == 1)
        #expect(draft.flowchart?.edges.first?.from == "n1")
        #expect(draft.flowchart?.edges.first?.to == "n2")
}

@Test func openAICompatibleLongFormReportFlowchartIsNilWhenAbsentFromResponse() async throws {
        let responseJSON = """
        {
            "choices": [{
                "message": {
                    "content": "{\\\"title\\\":\\\"当日复盘\\\",\\\"content\\\":\\\"流水账正文。\\\"}"
                }
            }]
        }
        """
        let sender = ConversationRecordingAIHTTPSender(responseData: Data(responseJSON.utf8))
        let service = OpenAICompatibleAIConversationService(httpSender: sender)
        let session = AIConversationSession(
                id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
                model: "gpt-5-mini", range: .today,
                startDate: Date(timeIntervalSince1970: 0),
                endDate: Date(timeIntervalSince1970: 86_400),
                startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
                status: .completed,
                overviewSnapshot: AIOverviewSnapshot(rangeTitle: "今天", totalDurationText: "3h", totalEventCount: 2, topCalendarNames: ["工作"]),
                messages: []
        )
        let summary = AIConversationSummary(
                id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "OpenAI",
                provider: .openAI, model: "gpt-5-mini", range: .today,
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
        #expect(draft.flowchart == nil)
}

    @Test func openAICompatibleLongFormReportDropsFlowchartForNonDailyRange() async throws {
        let responseJSON = """
        {
            "choices": [{
            "message": {
                "content": "{\\\"title\\\":\\\"本周复盘\\\",\\\"content\\\":\\\"流水账正文。\\\",\\\"flowchart\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"n1\\\",\\\"timeRange\\\":\\\"09:00-09:30\\\",\\\"title\\\":\\\"早会\\\",\\\"calendarName\\\":\\\"工作\\\"}],\\\"edges\\\":[{\\\"from\\\":\\\"n1\\\",\\\"to\\\":\\\"n2\\\"}]}}"
            }
            }]
        }
        """
        let sender = ConversationRecordingAIHTTPSender(responseData: Data(responseJSON.utf8))
        let service = OpenAICompatibleAIConversationService(httpSender: sender)
        let session = AIConversationSession(
            id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
            model: "gpt-5-mini", range: .week,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86_400 * 7),
            startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
            status: .completed,
            overviewSnapshot: AIOverviewSnapshot(rangeTitle: "本周", totalDurationText: "12h", totalEventCount: 8, topCalendarNames: ["工作"]),
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
        #expect(draft.flowchart == nil)
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

@Test func geminiLongFormReportDropsFlowchartForNonDailyRange() async throws {
        let sender = ConversationRecordingAIHTTPSender(
                responseData: Data(
                        """
                        {
                            "candidates": [
                                {
                                    "content": {
                                        "parts": [
                                            {
                                                "text": "{\\\"title\\\":\\\"本周复盘\\\",\\\"content\\\":\\\"流水账正文。\\\",\\\"flowchart\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"n1\\\",\\\"timeRange\\\":\\\"09:00-09:30\\\",\\\"title\\\":\\\"早会\\\",\\\"calendarName\\\":\\\"工作\\\"}],\\\"edges\\\":[{\\\"from\\\":\\\"n1\\\",\\\"to\\\":\\\"n2\\\"}]}}"
                                            }
                                        ]
                                    }
                                }
                            ]
                        }
                        """.utf8
                )
        )
        let service = GeminiConversationService(httpSender: sender)
        let session = AIConversationSession(
                id: UUID(), serviceID: nil, serviceDisplayName: "Gemini", provider: .gemini,
                model: "gemini-2.0-flash", range: .week,
                startDate: Date(timeIntervalSince1970: 0),
                endDate: Date(timeIntervalSince1970: 86_400 * 7),
                startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
                status: .completed,
                overviewSnapshot: AIOverviewSnapshot(rangeTitle: "本周", totalDurationText: "12h", totalEventCount: 8, topCalendarNames: ["工作"]),
                messages: []
        )
        let summary = AIConversationSummary(
                id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "Gemini",
                provider: .gemini, model: "gemini-2.0-flash", range: .week,
                startDate: session.startDate, endDate: session.endDate,
                createdAt: session.endDate, headline: "标题",
                summary: "摘要", findings: [], suggestions: [],
                overviewSnapshot: session.overviewSnapshot
        )

        let draft = try await service.generateLongFormReport(
                session: session,
                summary: summary,
                configuration: ResolvedAIProviderConfiguration(
                        provider: .gemini,
                        baseURL: "https://generativelanguage.googleapis.com",
                        model: "gemini-2.0-flash",
                        apiKey: "key",
                        isEnabled: true
                )
        )

        #expect(draft.flowchart == nil)
}

@Test func openAICompatibleConversationServiceCompactsMemoryAndReturnsPlainText() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "• 会议占用大量时间\\n• 用户有意识地保护早晨深度工作"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let summaries = [
        AIConversationSummary(
            id: UUID(),
            sessionID: UUID(),
            serviceID: nil,
            serviceDisplayName: "OpenAI",
            provider: .openAI,
            model: "gpt-5-mini",
            range: .today,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86_400),
            createdAt: Date(timeIntervalSince1970: 7_200),
            headline: "今天以沟通为主",
            summary: "今天大部分时间花在需求同步上。",
            findings: [],
            suggestions: [],
            overviewSnapshot: AIOverviewSnapshot(
                rangeTitle: "今天",
                totalDurationText: "1小时",
                totalEventCount: 1,
                topCalendarNames: ["工作"]
            )
        )
    ]
    let configuration = ResolvedAIProviderConfiguration(
        provider: .openAI,
        baseURL: "https://example.com/v1",
        model: "gpt-5-mini",
        apiKey: "test-key",
        isEnabled: true
    )

    let result = try await service.compactMemory(
        recentSummaries: summaries,
        existingMemory: "过去几轮都显示会议偏多。",
        configuration: configuration
    )

    #expect(result == "• 会议占用大量时间\n• 用户有意识地保护早晨深度工作")

    let body = try #require(sender.lastRequest?.httpBody)
    let decoded = try JSONDecoder().decode(CompactMemoryRequestBody.self, from: body)
    #expect(decoded.messages.contains { $0.role == "system" && $0.content.contains("时间记忆") })
    #expect(decoded.messages.contains { $0.role == "user" && $0.content.contains("过去几轮都显示会议偏多") })
    #expect(decoded.messages.contains { $0.role == "user" && $0.content.contains("今天以沟通为主") })
    #expect(decoded.responseFormat.type == "text")
}

fileprivate struct CompactMemoryRequestBody: Decodable {
    struct Message: Decodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Decodable {
        let type: String
    }
    let messages: [Message]
    let responseFormat: ResponseFormat
    enum CodingKeys: String, CodingKey {
        case messages
        case responseFormat = "response_format"
    }
}
