import Foundation

public enum AIProviderKind: String, CaseIterable, Codable, Sendable {
    case openAI
    case gemini
    case deepSeek
    case openAICompatible

    public var title: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .gemini:
            "Gemini"
        case .deepSeek:
            "DeepSeek"
        case .openAICompatible:
            "OpenAI Compatible"
        }
    }

    public var defaultBaseURL: String {
        switch self {
        case .openAI:
            "https://api.openai.com/v1"
        case .gemini:
            "https://generativelanguage.googleapis.com/v1beta"
        case .deepSeek:
            "https://api.deepseek.com/v1"
        case .openAICompatible:
            ""
        }
    }

    public var builtInServiceID: UUID {
        switch self {
        case .openAI:
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        case .gemini:
            UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        case .deepSeek:
            UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        case .openAICompatible:
            UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .openAICompatible
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct AIProviderCatalogItem: Equatable, Identifiable, Sendable {
    public let kind: AIProviderKind
    public let title: String
    public let defaultBaseURL: String
    public let supportsCustomEndpoints: Bool
    public let isBuiltIn: Bool

    public var id: AIProviderKind { kind }

    public init(
        kind: AIProviderKind,
        title: String,
        defaultBaseURL: String,
        supportsCustomEndpoints: Bool,
        isBuiltIn: Bool
    ) {
        self.kind = kind
        self.title = title
        self.defaultBaseURL = defaultBaseURL
        self.supportsCustomEndpoints = supportsCustomEndpoints
        self.isBuiltIn = isBuiltIn
    }
}

public enum AIProviderCatalog {
    public static let builtInItems: [AIProviderCatalogItem] = [
        AIProviderCatalogItem(
            kind: .openAI,
            title: AIProviderKind.openAI.title,
            defaultBaseURL: AIProviderKind.openAI.defaultBaseURL,
            supportsCustomEndpoints: false,
            isBuiltIn: true
        ),
        AIProviderCatalogItem(
            kind: .gemini,
            title: AIProviderKind.gemini.title,
            defaultBaseURL: AIProviderKind.gemini.defaultBaseURL,
            supportsCustomEndpoints: false,
            isBuiltIn: true
        ),
        AIProviderCatalogItem(
            kind: .deepSeek,
            title: AIProviderKind.deepSeek.title,
            defaultBaseURL: AIProviderKind.deepSeek.defaultBaseURL,
            supportsCustomEndpoints: false,
            isBuiltIn: true
        ),
    ]

    public static let customItem = AIProviderCatalogItem(
        kind: .openAICompatible,
        title: "OpenAI Compatible",
        defaultBaseURL: "",
        supportsCustomEndpoints: true,
        isBuiltIn: false
    )
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
        !baseURL.isEmpty && !model.isEmpty && !apiKey.isEmpty
    }

    public var openAICompatibleChatCompletionsURL: URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        let normalizedPath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = normalizedPath + "/chat/completions"
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
