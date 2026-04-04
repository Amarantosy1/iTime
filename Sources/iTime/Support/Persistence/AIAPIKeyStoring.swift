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
        // Try Data Protection Keychain first — no ACL, no per-binary prompts.
        let dpkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serviceID),
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let dpkStatus = SecItemCopyMatching(dpkQuery as CFDictionary, &item)
        if dpkStatus == errSecSuccess {
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                return tryFallback(for: serviceID) ?? ""
            }
            return value
        }

        // Fall back to legacy login keychain and migrate on success.
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serviceID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var legacyItem: CFTypeRef?
        let legacyStatus = SecItemCopyMatching(legacyQuery as CFDictionary, &legacyItem)
        if legacyStatus == errSecSuccess {
            guard let data = legacyItem as? Data, let value = String(data: data, encoding: .utf8) else {
                return tryFallback(for: serviceID) ?? ""
            }
            // Migrate to Data Protection Keychain, then remove legacy item.
            try? saveAPIKey(value, for: serviceID)
            SecItemDelete(legacyQuery as CFDictionary)
            return value
        }

        if let validFallback = tryFallback(for: serviceID) {
            return validFallback
        }

        if dpkStatus == errSecItemNotFound || legacyStatus == errSecItemNotFound {
            return ""
        }
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(dpkStatus))
    }

    private func tryFallback(for serviceID: UUID) -> String? {
        // 兜底方案：解决因为 ad-hoc 签名或本地调试导致 Keychain 访问权限丢失的问题
        let fallbackKey = "dev.fallback.apiKey.\(serviceID.uuidString)"
        if let data = UserDefaults.standard.data(forKey: fallbackKey),
           let value = String(data: data, encoding: .utf8), !value.isEmpty {
            return value
        }
        return nil
    }

    public func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws {
        // 同步存入 UserDefaults 作为本地调试与 ad-hoc 更新时的兜底
        // 正式签名的 App 主要依赖 Keychain，但缺失 Team ID 时依赖此 fallback 防止每次更新需重输
        let fallbackKey = "dev.fallback.apiKey.\(serviceID.uuidString)"
        if let baseKeyData = apiKey.data(using: .utf8) {
            UserDefaults.standard.set(baseKeyData, forKey: fallbackKey)
        }

        let encoded = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: serviceID),
            kSecUseDataProtectionKeychain as String: true,
        ]
        let attributes: [String: Any] = [kSecValueData as String: encoded]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = encoded
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            // 不抛出 Keychain 异常，如果 Keychain 写入失败（如缺乏 entitlement），依赖 UserDefaults 兜底
            guard addStatus == errSecSuccess else {
                return
            }
            return
        }

        // 不抛出 Keychain 异常
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
