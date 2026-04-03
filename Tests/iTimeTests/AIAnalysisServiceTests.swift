import Foundation
import Testing
@testable import iTime

private final class RecordingAIHTTPSender: @unchecked Sendable, AIAnalysisHTTPSending {
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

@Test func openAICompatibleServiceBuildsChatCompletionRequestAndParsesJSON() async throws {
    let sender = RecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"summary\\":\\"整体较平衡\\",\\"findings\\":[\\"工作投入偏高\\"],\\"suggestions\\":[\\"给本周留出固定缓冲时间\\"]}"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIAnalysisService(httpSender: sender)

    let result = try await service.analyze(
        request: AIAnalysisRequest(
            rangeTitle: "本周",
            totalDurationText: "18h",
            totalEventCount: 12,
            averageDailyDurationText: "3h",
            longestDayDurationText: "5h",
            topBuckets: [
                AIAnalysisBucket(id: "work", name: "工作", shareText: "60%", durationText: "10h", eventCount: 6),
                AIAnalysisBucket(id: "life", name: "生活", shareText: "25%", durationText: "4h", eventCount: 3),
            ],
            busiestPeriodSummary: "最忙时段：周三，共 5h。"
        ),
        configuration: AIAnalysisConfiguration(
            baseURL: "https://example.com/v1",
            model: "gpt-5-mini",
            apiKey: "secret-key",
            isEnabled: true
        )
    )

    let request = try #require(sender.lastRequest)
    #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

    let bodyData = try #require(request.httpBody)
    let body = try #require(bodyData.utf8String)
    #expect(body.contains("\"model\":\"gpt-5-mini\""))
    #expect(body.contains("工作"))
    #expect(result.summary == "整体较平衡")
    #expect(result.findings == ["工作投入偏高"])
    #expect(result.suggestions == ["给本周留出固定缓冲时间"])
}

@Test func openAICompatibleServiceRejectsResponsesWithoutValidJSONContent() async {
    let sender = RecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "not-json"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIAnalysisService(httpSender: sender)

    do {
        _ = try await service.analyze(
            request: AIAnalysisRequest(
                rangeTitle: "今天",
                totalDurationText: "8h",
                totalEventCount: 5,
                averageDailyDurationText: "8h",
                longestDayDurationText: "8h",
                topBuckets: [],
                busiestPeriodSummary: nil
            ),
            configuration: AIAnalysisConfiguration(
                baseURL: "https://example.com/v1",
                model: "gpt-5-mini",
                apiKey: "secret-key",
                isEnabled: true
            )
        )
        Issue.record("Expected invalid response error")
    } catch let error as AIAnalysisServiceError {
        #expect(error == .invalidResponse)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

private extension Data {
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}
