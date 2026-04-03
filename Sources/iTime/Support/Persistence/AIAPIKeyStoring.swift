import Foundation
import Security

public protocol AIAPIKeyStoring: Sendable {
    func loadAPIKey(for serviceID: UUID) throws -> String
    func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws
}

public struct KeychainAIAPIKeyStore: AIAPIKeyStoring {
    private let service = "com.amarantos.iTime.ai"

    public init() {}

    public func loadAPIKey(for serviceID: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serviceID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard
                let data = item as? Data,
                let value = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return value
        case errSecItemNotFound:
            return ""
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws {
        let encoded = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serviceID),
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = encoded
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
            return
        }

        throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
    }

    private func account(for serviceID: UUID) -> String {
        "compat-\(serviceID.uuidString.lowercased())-api-key"
    }
}

public extension AIAPIKeyStoring {
    func loadAPIKey(for provider: AIProviderKind) throws -> String {
        try loadAPIKey(for: provider.builtInServiceID)
    }

    func saveAPIKey(_ apiKey: String, for provider: AIProviderKind) throws {
        try saveAPIKey(apiKey, for: provider.builtInServiceID)
    }

    func loadAPIKey() throws -> String {
        try loadAPIKey(for: .openAI)
    }

    func saveAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, for: .openAI)
    }
}
