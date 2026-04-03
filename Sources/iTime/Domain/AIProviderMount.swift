import Foundation

public struct AIProviderMount: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let providerType: AIProviderKind
    public let baseURL: String
    public let models: [String]
    public let defaultModel: String
    public let isEnabled: Bool
    public let isBuiltIn: Bool

    public init(
        id: UUID,
        displayName: String,
        providerType: AIProviderKind,
        baseURL: String,
        models: [String],
        defaultModel: String,
        isEnabled: Bool,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerType = providerType
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.models = models.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.defaultModel = defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }

    public static func builtIn(
        providerType: AIProviderKind,
        baseURL: String? = nil,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIProviderMount {
        AIProviderMount(
            id: providerType.builtInMountID,
            displayName: providerType.title,
            providerType: providerType,
            baseURL: baseURL ?? providerType.defaultBaseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: true
        )
    }

    public static func custom(
        displayName: String,
        providerType: AIProviderKind,
        baseURL: String,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIProviderMount {
        AIProviderMount(
            id: UUID(),
            displayName: displayName,
            providerType: providerType,
            baseURL: baseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: false
        )
    }

    public func updating(
        displayName: String? = nil,
        baseURL: String? = nil,
        models: [String]? = nil,
        defaultModel: String? = nil,
        isEnabled: Bool? = nil
    ) -> AIProviderMount {
        AIProviderMount(
            id: id,
            displayName: displayName ?? self.displayName,
            providerType: providerType,
            baseURL: baseURL ?? self.baseURL,
            models: models ?? self.models,
            defaultModel: defaultModel ?? self.defaultModel,
            isEnabled: isEnabled ?? self.isEnabled,
            isBuiltIn: isBuiltIn
        )
    }
}
