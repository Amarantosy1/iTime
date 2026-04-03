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

    private func sendRequest(
        userPrompt: String,
        systemPrompt: String,
        configuration: ResolvedAIProviderConfiguration
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
                contents: [.init(role: "user", parts: [.init(text: userPrompt)])]
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
        guard let data = content.data(using: .utf8) else {
            throw AIAnalysisServiceError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AIAnalysisServiceError.invalidResponse
        }
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

    let systemInstruction: SystemInstruction
    let contents: [Content]
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
    let headline: String
    let summary: String
    let findings: [String]
    let suggestions: [String]
}
