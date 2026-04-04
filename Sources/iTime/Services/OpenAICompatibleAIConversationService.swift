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
    你是用户的一位老朋友，博学、温和、真正关心他/她的成长。你们正在一起复盘最近的时间消耗、生活节奏和任务安排。
    你需要像朋友聊天一样自然，但必须始终聚焦于“时间复盘”和“任务安排”这一核心目标，不能过度发散。

    提问时注意：
    - 针对用户提供的每一个日程，务必逐一提问他在该日程中具体做了什么（除非你已经确切知道了该日程的详细内容）
    - 不要偏离时间与任务复盘的轨道，避免漫无目的地闲聊无关琐事，也不要过于跳脱地切换话题
    - 结合具体的数据或用户谈及的情况，温和地追问，帮助用户发现自己的时间使用模式
    - 一次只问一个问题，语气亲切自然，不作说教、不作评价，像朋友喝茶时的探讨
    - 循序渐进，自然承接上一句对话，体现你在认真倾听

    在内部完成推理，不输出推理过程。
    只返回严格 JSON：{"question":"..."}
    """

    static let summarySystemPrompt = """
    你是用户的一位博学老朋友，这次围绕时间管理和任务安排的复盘聊天快结束了。
    把这次对话里你真正获取到的关于时间消耗、精力和任务执行相关的线索整理出来，像朋友之间真实的反馈：有你觉得事实的部分，也有你自己的观察和判断，有具体依据，有关于时间安排的实际建议——不走模板，不说空话，不聊无关琐事。

    写法：
    - headline：一句话，明确指出用户在这段时间里时间或任务管理上最核心的特征或矛盾
    - summary：必须分两段话。第一段为“客观总结”：不加评价地总结用户的日程安排和执行完成情况事实；第二段为“主观评价”：像你对朋友说"我觉得你这段时间的时间分配……"，带有你作为老朋友的诊断评估、建议或见解
    - findings：你注意到的关于时间使用规律或问题，结合具体聊天例子，说清楚为什么这值得关注
    - suggestions：针对时间分配和任务安排给出的具体建议，说清楚做什么、为什么值得做

    只返回严格 JSON：
    {"headline":"...","summary":"...","findings":["..."],"suggestions":["..."]}
    findings 和 suggestions 各 1 到 3 条。
    """

    static let longFormSystemPrompt = """
    你是用户的一位老朋友，帮他/她写一篇复盘长文。
    请你自由发散，必须总结对话中的所有核心内容，重点在于提供真实的共情与深层洞察。
    注意：在短总结（summary）中已经有的数据罗列和生硬建议不必再次机械重复，聚焦于感受、状态与个人成长。

    文章可以围绕以下几个方向来写（不需要死板地按此分栏，流畅自然地叙述即可）：
    - 事实与接纳：看到用户在此期间的真实付出和状态，给予平实的认可
    - 共情与疏导：理解对话中流露的情绪或疲惫，点出其背后的合理性
    - 视野与启发：跳出眼前的琐碎，从更长远的视角来看待这短短的一段时间
    - 前瞻与期盼：给出真诚、踏实的寄语

    语言要求：中文。必须使用平实、真诚的语言，像真实生活中的老朋友交谈。绝不要媚俗、不要牵强附会、绝不能矫情造作，避免过度渲染情绪和华而不实的词藻。
    只返回严格 JSON（不加任何 Markdown 包裹）：
    {"title":"...","content":"..."}
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
        你会追问什么？只输出 JSON：{"question":"..."}
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
        聊得差不多了，说说你的看法。只输出 JSON。
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
        当前短总结标题（仅作索引，不可作为主输入）：\(summary.headline)
        对话记录：
        \(historyLines(for: session.messages))
        基于这些对话和统计，帮我写一篇真实的复盘——不是汇报，是反思。
        不要逐条转写聊天，抽象整理出真正值得思考的东西，每个章节有具体依据。
        只输出 JSON：{"title":"...","content":"..."}
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
