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
