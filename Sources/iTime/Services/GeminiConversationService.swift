import Foundation

public struct GeminiConversationService: AIConversationServing, Sendable {
    private let httpSender: AIAnalysisHTTPSending

    public init(httpSender: AIAnalysisHTTPSending = URLSessionAIAnalysisHTTPSender()) {
        self.httpSender = httpSender
    }

    public func validateConnection(configuration: ResolvedAIProviderConfiguration) async throws {
        _ = try await sendRequest(
            userPrompt: "回复 pong。",
            systemPrompt: "你是一个连接测试助手，只返回纯文本 pong。",
            configuration: configuration
        )
    }

    public func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.questionUserPrompt(for: context, history: history),
            systemPrompt: OpenAICompatibleAIConversationService.questionSystemPrompt,
            configuration: configuration
        )
        let payload = try decodePayload(GeminiQuestionPayload.self, from: content)
        guard !payload.question.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationMessage(id: UUID(), role: .assistant, content: payload.question, createdAt: Date())
    }

    public func summarizeConversation(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationSummaryDraft {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.summaryUserPrompt(for: context, history: history),
            systemPrompt: OpenAICompatibleAIConversationService.summarySystemPrompt,
            configuration: configuration
        )
        let payload = try decodePayload(GeminiSummaryPayload.self, from: content)
        let dateHeadline = OpenAICompatibleAIConversationService.formattedSummaryHeadline(
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

    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.compactMemoryUserPrompt(
                recentSummaries: recentSummaries,
                existingMemory: existingMemory
            ),
            systemPrompt: OpenAICompatibleAIConversationService.compactMemorySystemPrompt,
            configuration: configuration,
            responseMimeType: "text/plain"
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func generateLongFormReport(
        session: AIConversationSession,
        summary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationLongFormReportDraft {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.longFormUserPrompt(for: session, summary: summary),
            systemPrompt: OpenAICompatibleAIConversationService.longFormSystemPrompt,
            configuration: configuration
        )
        let payload = try decodePayload(GeminiLongFormPayload.self, from: content)
        guard !payload.title.isEmpty, !payload.content.isEmpty else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return AIConversationLongFormReportDraft(title: payload.title, content: payload.content, flowchart: payload.flowchart)
    }

    private func sendRequest(
        userPrompt: String,
        systemPrompt: String,
        configuration: ResolvedAIProviderConfiguration,
        responseMimeType: String = "application/json"
    ) async throws -> String {
        guard configuration.isComplete, let url = configuration.geminiGenerateContentURL else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GeminiGenerateContentRequest(
                systemInstruction: .init(parts: [.init(text: systemPrompt)]),
                contents: [.init(role: "user", parts: [.init(text: userPrompt)])],
                generationConfig: .init(responseMimeType: responseMimeType)
            )
        )
        let (data, response) = try await perform(request)
        guard (200..<300).contains(response.statusCode) else {
            throw AIAnalysisServiceError.unexpectedStatus(response.statusCode)
        }
        let decoded = try JSONDecoder().decode(GeminiGenerateContentResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else {
            throw AIAnalysisServiceError.invalidResponse
        }
        return text
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await httpSender.send(request)
        } catch let error as AIAnalysisServiceError {
            throw error
        } catch {
            throw AIAnalysisServiceError.transportError(error.localizedDescription)
        }
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
}

private struct GeminiGenerateContentRequest: Encodable {
    struct Part: Encodable {
        let text: String
    }

    struct Content: Encodable {
        let role: String
        let parts: [Part]
    }

    struct SystemInstruction: Encodable {
        let parts: [Part]
    }

    struct GenerationConfig: Encodable {
        let responseMimeType: String
        enum CodingKeys: String, CodingKey {
            case responseMimeType = "response_mime_type"
        }
    }

    let systemInstruction: SystemInstruction
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GeminiGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content
    }

    let candidates: [Candidate]
}

private struct GeminiQuestionPayload: Decodable {
    let question: String
}

private struct GeminiSummaryPayload: Decodable {
    let summary: String
    let findings: [String]
    let suggestions: [String]
}

private struct GeminiLongFormPayload: Decodable {
    let title: String
    let content: String
    let flowchart: AIConversationFlowchart?
}
