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
        let dateHeadline = Self.formattedSummaryHeadline(
            startDate: context.startDate,
            endDate: context.endDate
        )
        guard !payload.summary.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationSummaryDraft(
            headline: dateHeadline,
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
        let shouldIncludeFlowchart = Self.shouldIncludeLongFormFlowchart(for: session)
        let content = try await sendRequest(
            systemPrompt: Self.longFormSystemPrompt(includeFlowchart: shouldIncludeFlowchart),
            userPrompt: Self.longFormUserPrompt(for: session, summary: summary, includeFlowchart: shouldIncludeFlowchart),
            configuration: configuration
        )
        let payload = try decodePayload(LongFormPayload.self, from: content)
        guard !payload.title.isEmpty, !payload.content.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationLongFormReportDraft(
            title: payload.title,
            content: payload.content,
            flowchart: shouldIncludeFlowchart ? payload.flowchart : nil
        )
    }

    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        let content = try await sendRequest(
            systemPrompt: Self.compactMemorySystemPrompt,
            userPrompt: Self.compactMemoryUserPrompt(
                recentSummaries: recentSummaries,
                existingMemory: existingMemory
            ),
            configuration: configuration,
            responseFormatType: "text"
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: ResolvedAIProviderConfiguration,
        responseFormatType: String = "json_object"
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
                responseFormat: .init(type: responseFormatType)
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
    - 注意如果近期的memory里有相似的东西可以引用
    - 如果发现该段时间复盘的事件与近期memory有很大不同，可以问为什么

    在内部完成推理，不输出推理过程。
    只返回严格 JSON：{"question":"..."}
    """

    static let summarySystemPrompt = """
    你是用户的一位博学老朋友，这次围绕时间管理和任务安排的复盘聊天快结束了。

    写法：
    - summary：必须分两段话。第一段为“客观总结”：不加评价地总结用户的日程安排和执行完成情况事实；第二段为“主观评价”：像你对朋友说"我觉得你这段时间的时间分配……"，带有你作为老朋友的诊断评估、建议或见解
    - findings：你注意到的关于时间使用规律或问题，结合具体聊天例子，说清楚为什么这值得关注。注意应用最近一段时间的非本次复盘的记录，发现近期的状态/变化。
    - suggestions：针对时间分配和任务安排给出的具体建议，说清楚做什么、为什么值得做
    - Markdown 约定（非常重要）：
        1) 所有“时间点/时间段”都用行内代码包裹，如 `09:30`、`09:30-11:00`
        2) 所有“具体事件名/任务名”都必须使用 Markdown 加粗语法 `**事件名**`，例如 `**需求评审**`
        3) 若需要给出时间线或步骤，允许使用 fenced code block（```text ... ```）
        4) 不要使用 HTML 标签（例如 `<mark>`）
        5) 不要写“高亮”这两个字来描述样式，必须直接输出 Markdown 语法

    只返回严格 JSON：
    {"summary":"...","findings":["..."],"suggestions":["..."]}
    findings 和 suggestions 各 1 到 3 条。
    """

    static func longFormSystemPrompt(includeFlowchart: Bool) -> String {
        let basePrompt = """
        你是用户的一位朋友，帮他/她写一篇流水账复盘，使用平实的语言，不要渲染感情，不要升华，不要堆砌辞藻，不要洞察内心，只需要用平实的语言记录好这一天，不要虚构内容。
        - Markdown 约定（非常重要）：
        1) 所有“时间点/时间段”都用行内代码包裹，如 `09:30`、`09:30-11:00`
        2) 所有“具体事件名/任务名”都必须使用 Markdown 加粗语法 `**事件名**`
        3) 若需要给出时间线或步骤，允许使用 fenced code block（```text ... ```）
        4) 不要使用 HTML 标签（例如 `<mark>`）
        5) 不要写“高亮”这两个字来描述样式，必须直接输出 Markdown 语法
        """

        guard includeFlowchart else {
            return basePrompt
        }

        return """
        \(basePrompt)
        同时输出一份当天的节点式流程图。把时间相近、性质相同的事件合并为节点，允许并行分支。每个节点有唯一 id（如 "n1"）、时间段（timeRange，格式 "HH:mm-HH:mm"）、标题（title）、主要日历名（calendarName，若无则为 null）。edges 描述节点间的流转关系，每条 edge 有 from 和 to（均为 node id）。
        """
    }

    static let compactMemorySystemPrompt = """
    你在帮助整理一位用户的时间记忆档案。根据提供的历史复盘摘要，提炼出这位用户最典型的时间习惯、重复模式和近期值得关注的变化。
    要求：不超过 400 字，2-4 条要点，每条以 • 开头，聚焦于时间管理与任务执行的规律性观察，只输出纯文本，不要输出 JSON。
    """

    static func compactMemoryUserPrompt(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?
    ) -> String {
        let dailyCount = recentSummaries.filter { $0.range == .today }.count
        let weeklyCount = recentSummaries.filter { $0.range == .week }.count

        var hierarchicalNote = ""
        if dailyCount >= 7 {
            hierarchicalNote = "\n注意：以上摘要已覆盖本周完整的工作日复盘，请在要点末尾额外加一条 • 本周总体记忆：…（一句话概括本周整体状态）"
        } else if weeklyCount >= 3 {
            hierarchicalNote = "\n注意：以上摘要已覆盖本月完整的周复盘，请在要点末尾额外加一条 • 本月总体记忆：…（一句话概括本月整体趋势）"
        }

        let summaryLines = recentSummaries
            .sorted { $0.createdAt > $1.createdAt }
            .map { "- \($0.displayPeriodText)【\($0.range.title)】：\($0.headline)。\($0.summary)" }
            .joined(separator: "\n")

        return """
        历史记忆（如有）：\(existingMemory ?? "无")

        近期复盘摘要：
        \(summaryLines.isEmpty ? "（无）" : summaryLines)
        \(hierarchicalNote)
        请提炼这位用户的时间使用规律。
        """
    }

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
        summary: AIConversationSummary,
        includeFlowchart: Bool
    ) -> String {
        let outputSchema: String
        if includeFlowchart {
            outputSchema = "{" +
                "\"title\":\"...\"," +
                "\"content\":\"...\"," +
                "\"flowchart\":{" +
                "\"nodes\":[{" +
                "\"id\":\"n1\"," +
                "\"timeRange\":\"09:00-10:00\"," +
                "\"title\":\"示例节点\"," +
                "\"calendarName\":\"工作\"}]," +
                "\"edges\":[{" +
                "\"from\":\"n1\"," +
                "\"to\":\"n2\"}]}}"
        } else {
            outputSchema = "{\"title\":\"...\",\"content\":\"...\"}"
        }

        return """
        复盘范围：\(session.displayPeriodText)
        统计摘要：\(session.overviewSnapshot.totalDurationText)，共 \(session.overviewSnapshot.totalEventCount) 个事件。
        主要日历：\(session.overviewSnapshot.topCalendarNames.joined(separator: "、"))
        当前短总结标题（仅作索引，不可作为主输入）：\(summary.headline)
        对话记录：
        \(historyLines(for: session.messages))
        基于这些对话和统计，帮我写一篇真实的复盘——不是汇报，是反思。
        不要逐条转写聊天，抽象整理出真正值得思考的东西，每个章节有具体依据。
        只输出 JSON：\(outputSchema)
        """
    }

    static func shouldIncludeLongFormFlowchart(
        for session: AIConversationSession,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        if session.range == .today {
            return true
        }

        return AIConversationPeriodFormatter.isSingleDay(
            startDate: session.startDate,
            endDate: session.endDate,
            calendar: calendar
        )
    }

    static func formattedSummaryHeadline(
        startDate: Date,
        endDate: Date,
        timeZone: TimeZone = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let normalizedStart = formatter.string(from: startDate)
        let inclusiveEnd = endDate > startDate ? endDate.addingTimeInterval(-1) : startDate
        let normalizedEnd = formatter.string(from: inclusiveEnd)
        let candidate = normalizedStart == normalizedEnd
            ? normalizedStart
            : "\(normalizedStart) ~ \(normalizedEnd)"

        return normalizeSummaryHeadlineRange(candidate)
    }

    static func normalizeSummaryHeadlineRange(_ candidate: String) -> String {
        let compacted = candidate
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "至", with: "~")

        if compacted.range(of: #"^\\d{4}-\\d{2}-\\d{2}$"#, options: .regularExpression) != nil {
            return compacted
        }

        if compacted.range(of: #"^\\d{4}-\\d{2}-\\d{2}~\\d{4}-\\d{2}-\\d{2}$"#, options: .regularExpression) != nil {
            return compacted
        }

        return compacted
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
    let summary: String
    let findings: [String]
    let suggestions: [String]
}

private struct LongFormPayload: Decodable {
    let title: String
    let content: String
    let flowchart: AIConversationFlowchart?
}
