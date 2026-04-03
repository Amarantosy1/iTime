import Foundation

public struct AIServiceEndpoint: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let providerKind: AIProviderKind
    public let baseURL: String
    public let models: [String]
    public let defaultModel: String
    public let isEnabled: Bool
    public let isBuiltIn: Bool

    public init(
        id: UUID,
        displayName: String,
        providerKind: AIProviderKind,
        baseURL: String,
        models: [String],
        defaultModel: String,
        isEnabled: Bool,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerKind = providerKind
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.models = models.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.defaultModel = defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case providerKind
        case providerType
        case baseURL
        case models
        case defaultModel
        case isEnabled
        case isBuiltIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        providerKind = try container.decodeIfPresent(AIProviderKind.self, forKey: .providerKind)
            ?? container.decode(AIProviderKind.self, forKey: .providerType)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        models = try container.decodeIfPresent([String].self, forKey: .models) ?? []
        defaultModel = try container.decodeIfPresent(String.self, forKey: .defaultModel) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(providerKind, forKey: .providerKind)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(models, forKey: .models)
        try container.encode(defaultModel, forKey: .defaultModel)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
    }

    public static func builtIn(
        providerKind: AIProviderKind,
        baseURL: String? = nil,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIServiceEndpoint {
        AIServiceEndpoint(
            id: providerKind.builtInServiceID,
            displayName: providerKind.title,
            providerKind: providerKind,
            baseURL: baseURL ?? providerKind.defaultBaseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: true
        )
    }

    public static func customOpenAICompatible(
        displayName: String,
        baseURL: String,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIServiceEndpoint {
        AIServiceEndpoint(
            id: UUID(),
            displayName: displayName,
            providerKind: .openAICompatible,
            baseURL: baseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: false
        )
    }

    public func updating(
        displayName: String? = nil,
        providerKind: AIProviderKind? = nil,
        baseURL: String? = nil,
        models: [String]? = nil,
        defaultModel: String? = nil,
        isEnabled: Bool? = nil
    ) -> AIServiceEndpoint {
        AIServiceEndpoint(
            id: id,
            displayName: displayName ?? self.displayName,
            providerKind: providerKind ?? self.providerKind,
            baseURL: baseURL ?? self.baseURL,
            models: models ?? self.models,
            defaultModel: defaultModel ?? self.defaultModel,
            isEnabled: isEnabled ?? self.isEnabled,
            isBuiltIn: isBuiltIn
        )
    }
}

public enum AIServiceConnectionState: Equatable, Sendable {
    case idle
    case testing
    case succeeded(String)
    case failed(String)
}
