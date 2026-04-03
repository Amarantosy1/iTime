import Foundation

public enum AIProviderKind: String, CaseIterable, Codable, Sendable {
    case openAI
    case anthropic
    case gemini
    case deepSeek

    public var title: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .gemini:
            "Gemini"
        case .deepSeek:
            "DeepSeek"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openAI:
            "https://api.openai.com/v1"
        case .anthropic:
            "https://api.anthropic.com/v1"
        case .gemini:
            "https://generativelanguage.googleapis.com/v1beta"
        case .deepSeek:
            "https://api.deepseek.com/v1"
        }
    }

    public var builtInMountID: UUID {
        switch self {
        case .openAI:
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        case .anthropic:
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        case .gemini:
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        case .deepSeek:
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        }
    }
}

public struct AIProviderConfiguration: Equatable, Codable, Sendable {
    public let provider: AIProviderKind
    public let baseURL: String
    public let model: String
    public let isEnabled: Bool

    public init(
        provider: AIProviderKind,
        baseURL: String,
        model: String,
        isEnabled: Bool
    ) {
        self.provider = provider
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
    }
}

public struct ResolvedAIProviderConfiguration: Equatable, Sendable {
    public let provider: AIProviderKind
    public let baseURL: String
    public let model: String
    public let apiKey: String
    public let isEnabled: Bool

    public init(
        provider: AIProviderKind,
        baseURL: String,
        model: String,
        apiKey: String,
        isEnabled: Bool
    ) {
        self.provider = provider
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
    }

    public var isComplete: Bool {
        isEnabled && !baseURL.isEmpty && !model.isEmpty && !apiKey.isEmpty
    }

    public var openAICompatibleChatCompletionsURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalizedPath + "/chat/completions"
        return components.url
    }

    public var anthropicMessagesURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalizedPath + "/messages"
        return components.url
    }

    public var geminiGenerateContentURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalizedPath + "/models/\(model):generateContent"
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "key", value: apiKey),
        ]
        return components.url
    }
}
