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
        configuration: AIAnalysisConfiguration(
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
        configuration: AIAnalysisConfiguration(
            baseURL: "https://example.com/v1",
            model: "gpt-5-mini",
            apiKey: "secret-key",
            isEnabled: true
        )
    )

    #expect(draft.headline == "本周工作会议偏多")
    #expect(draft.summary == "你本周大量时间花在评审和同步上，深度工作时间不足。")
    #expect(draft.findings == ["会议集中在周二和周三"])
    #expect(draft.suggestions == ["给深度工作预留不可打断时段"])
}
