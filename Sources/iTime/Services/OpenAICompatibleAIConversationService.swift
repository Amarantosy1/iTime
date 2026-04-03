import Foundation

public struct OpenAICompatibleAIConversationService: AIConversationServing, Sendable {
    private let httpSender: AIAnalysisHTTPSending

    public init(httpSender: AIAnalysisHTTPSending = URLSessionAIAnalysisHTTPSender()) {
        self.httpSender = httpSender
    }

    public func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        _ = try await sendRequest(
            systemPrompt: "你是一个连接测试助手，只返回纯文本 pong。",
            userPrompt: "回复 pong。",
            configuration: configuration
        )
    }

    public func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        let content = try await sendRequest(
            systemPrompt: Self.questionSystemPrompt,
            userPrompt: Self.questionUserPrompt(for: context, history: history),
            configuration: configuration
        )
        let payload = try decodePayload(QuestionPayload.self, from: content)
        guard !payload.question.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationMessage(
            id: UUID(),
            role: .assistant,
            content: payload.question,
            createdAt: Date()
        )
    }

    public func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft {
        let content = try await sendRequest(
            systemPrompt: Self.summarySystemPrompt,
            userPrompt: Self.summaryUserPrompt(for: context, history: history),
            configuration: configuration
        )
        let payload = try decodePayload(SummaryPayload.self, from: content)
        guard !payload.headline.isEmpty, !payload.summary.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationSummaryDraft(
            headline: payload.headline,
            summary: payload.summary,
            findings: Array(payload.findings.prefix(3)),
            suggestions: Array(payload.suggestions.prefix(3))
        )
    }

    public func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft {
        let content = try await sendRequest(
            systemPrompt: Self.longFormSystemPrompt,
            userPrompt: Self.longFormUserPrompt(for: session, summary: summary),
            configuration: configuration
        )
        let payload = try decodePayload(LongFormPayload.self, from: content)
        guard !payload.title.isEmpty, !payload.content.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationLongFormReportDraft(
            title: payload.title,
            content: payload.content
        )
    }

    private func sendRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        guard configuration.isComplete, let url = configuration.openAICompatibleChatCompletionsURL else {
            throw AIAnalysisServiceError.invalidConfiguration
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(
            ConversationChatCompletionsRequest(
                model: configuration.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userPrompt),
                ],
                responseFormat: .init(type: "json_object")
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

        let decoded = try JSONDecoder().decode(ConversationChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return content
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from content: String) throws -> T {
        let json = Self.extractJSON(from: content)
        guard let data = json.data(using: .utf8) else {
            throw AIAnalysisServiceError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AIAnalysisServiceError.invalidResponse
        }
    }

    static func extractJSON(from content: String) -> String {
        var s = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        if let newline = s.range(of: "\n") {
            s = String(s[newline.upperBound...])
        }
        if let fence = s.range(of: "```", options: .backwards) {
            s = String(s[..<fence.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let questionSystemPrompt = """
    你是一个中文时间复盘助手。你会先阅读统计摘要、具体日程标题和历史 memory，然后提出一个最值得继续追问的问题。
    问题必须具体，尽量引用某个日程标题或一段明显值得澄清的安排。
    你必须只返回 JSON，不要输出 Markdown 或额外解释。
    返回格式固定为：{"question":"..."}
    """

    static let summarySystemPrompt = """
    你是一个中文时间复盘助手。你会基于统计摘要、具体日程、对话记录和历史 memory 生成一份结构化总结。
    你必须只返回 JSON，不要输出 Markdown 或额外解释。
    返回格式固定为：
    {"headline":"...","summary":"...","findings":["..."],"suggestions":["..."]}
    findings 和 suggestions 各返回 1 到 3 条。
    """

    static let longFormSystemPrompt = """
    你是一个中文时间复盘助手。你会基于原始多轮对话、统计快照和时间范围，生成一篇正式的长文复盘。
    文章必须做抽象整理，不要把聊天记录逐条改写成流水账，只允许少量提及关键日程标题。
    你必须只返回 JSON，不要输出 Markdown 包裹或额外解释。
    返回格式固定为：
    {"title":"...","content":"..."}
    content 必须是一篇结构完整的中文复盘文章，包含：复盘范围、时间投入与关注重点、关键模式与主要问题、深层原因分析、改进行动建议、下一阶段关注点。
    """

    static func questionUserPrompt(
        for context: AIConversationContext,
        history: [AIConversationMessage]
    ) -> String {
        """
        当前复盘范围：\(context.rangeTitle)
        统计摘要：\(context.overviewSnapshot.totalDurationText)，共 \(context.overviewSnapshot.totalEventCount) 个事件。
        主要日历：\(context.overviewSnapshot.topCalendarNames.joined(separator: "、"))
        历史 memory：\(context.latestMemorySummary ?? "无")
        具体日程：
        \(eventLines(for: context.events))
        已有对话：
        \(historyLines(for: history))
        请提出一个最值得继续追问的问题。
        """
    }

    static func summaryUserPrompt(
        for context: AIConversationContext,
        history: [AIConversationMessage]
    ) -> String {
        """
        当前复盘范围：\(context.rangeTitle)
        统计摘要：\(context.overviewSnapshot.totalDurationText)，共 \(context.overviewSnapshot.totalEventCount) 个事件。
        主要日历：\(context.overviewSnapshot.topCalendarNames.joined(separator: "、"))
        历史 memory：\(context.latestMemorySummary ?? "无")
        具体日程：
        \(eventLines(for: context.events))
        对话记录：
        \(historyLines(for: history))
        请给出结构化总结。
        """
    }

    static func longFormUserPrompt(
        for session: AIConversationSession,
        summary: AIConversationSummary
    ) -> String {
        """
        复盘范围：\(session.displayPeriodText)
        统计摘要：\(session.overviewSnapshot.totalDurationText)，共 \(session.overviewSnapshot.totalEventCount) 个事件。
        主要日历：\(session.overviewSnapshot.topCalendarNames.joined(separator: "、"))
        当前短总结标题：\(summary.headline)
        对话记录：
        \(historyLines(for: session.messages))
        请基于这些原始对话内容和统计快照，输出一篇正式复盘文章。
        注意：默认做抽象整理，不要把短总结当成主输入来源，不要逐条转写聊天。
        """
    }

    static func eventLines(for events: [AIEventContext]) -> String {
        guard !events.isEmpty else { return "- 无事件" }
        return events.map {
            "- [\($0.calendarName)] \($0.title)，时长 \($0.durationText)"
        }.joined(separator: "\n")
    }

    static func historyLines(for history: [AIConversationMessage]) -> String {
        guard !history.isEmpty else { return "- 无" }
        return history.map {
            let role = $0.role == .assistant ? "AI" : "用户"
            return "- \(role)：\($0.content)"
        }.joined(separator: "\n")
    }
}

private struct ConversationChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct ConversationChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct QuestionPayload: Decodable {
    let question: String
}

private struct SummaryPayload: Decodable {
    let headline: String
    let summary: String
    let findings: [String]
    let suggestions: [String]
}

private struct LongFormPayload: Decodable {
    let title: String
    let content: String
}
