import Foundation
import Security

public protocol AIAPIKeyStoring: Sendable {
    func loadAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
}

public struct KeychainAIAPIKeyStore: AIAPIKeyStoring {
    private let service = "com.amarantos.iTime.ai"
    private let account = "compat-openai-api-key"

    public init() {}

    public func loadAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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

    public func saveAPIKey(_ apiKey: String) throws {
        let encoded = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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
}
