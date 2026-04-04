import Foundation

public protocol AIAnalysisHTTPSending: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionAIAnalysisHTTPSender: AIAnalysisHTTPSending {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        self.session = session ?? URLSession(configuration: Self.defaultConfiguration())
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return (data, httpResponse)
    }

    static func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        return configuration
    }
}

public struct OpenAICompatibleAIAnalysisService: AIAnalysisServing, Sendable {
    private let httpSender: AIAnalysisHTTPSending

    public init(httpSender: AIAnalysisHTTPSending = URLSessionAIAnalysisHTTPSender()) {
        self.httpSender = httpSender
    }

    public func analyze(
        request: AIAnalysisRequest,
        configuration: AIAnalysisConfiguration
    ) async throws -> AIAnalysisResult {
        guard configuration.isComplete, let url = configuration.chatCompletionsURL else {
            throw AIAnalysisServiceError.invalidConfiguration
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(
            ChatCompletionsRequest(
                model: configuration.model,
                messages: [
                    .init(role: "system", content: Self.systemPrompt),
                    .init(role: "user", content: Self.userPrompt(for: request)),
                ]
            )
        )

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await httpSender.send(urlRequest)
        } catch let error as AIAnalysisServiceError {
            throw error
        } catch {
            throw AIAnalysisServiceError.transportError(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            throw AIAnalysisServiceError.unexpectedStatus(response.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.data(using: .utf8) else {
            throw AIAnalysisServiceError.invalidResponse
        }

        do {
            let payload = try JSONDecoder().decode(AnalysisPayload.self, from: content)
            guard !payload.summary.isEmpty else {
                throw AIAnalysisServiceError.invalidResponse
            }
            return AIAnalysisResult(
                summary: payload.summary,
                findings: Array(payload.findings.prefix(3)),
                suggestions: Array(payload.suggestions.prefix(3)),
                generatedAt: Date()
            )
        } catch let error as AIAnalysisServiceError {
            throw error
        } catch {
            throw AIAnalysisServiceError.invalidResponse
        }
    }

    private static let systemPrompt = """
    你是用户的一位熟悉时间管理的老朋友，看了他的日历数据，说说你真实的判断——简短、具体、有用，不废话。
    只返回 JSON，不要输出 Markdown：
    {"summary":"...", "findings":["..."], "suggestions":["..."]}
    findings 和 suggestions 各 2 到 3 条。
    """

    private static func userPrompt(for request: AIAnalysisRequest) -> String {
        let bucketLines = request.topBuckets.map {
            "- \($0.name)：\($0.durationText)，占比 \($0.shareText)，事件数 \($0.eventCount)"
        }.joined(separator: "\n")

        let busiestSummary = request.busiestPeriodSummary ?? "无明显最忙时段。"

        return """
        请基于以下时间统计生成评估：
        范围：\(request.rangeTitle)
        总时长：\(request.totalDurationText)
        事件数：\(request.totalEventCount)
        日均时长：\(request.averageDailyDurationText)
        最长单日：\(request.longestDayDurationText)
        最忙时段：\(busiestSummary)
        按日历分布：
        \(bucketLines.isEmpty ? "- 无数据" : bucketLines)
        """
    }
}

private struct ChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct AnalysisPayload: Decodable {
    let summary: String
    let findings: [String]
    let suggestions: [String]
}
