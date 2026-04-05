import Foundation

public final class SyncPersistenceAdapter: @unchecked Sendable {
    private let archiveStore: AIConversationArchiveStoring
    private let preferences: UserPreferences
    private let apiKeyStore: AIAPIKeyStoring

    public init(
        archiveStore: AIConversationArchiveStoring,
        preferences: UserPreferences,
        apiKeyStore: AIAPIKeyStoring
    ) {
        self.archiveStore = archiveStore
        self.preferences = preferences
        self.apiKeyStore = apiKeyStore
    }

    public func makeManifest() async throws -> SyncManifest {
        let archive = try archiveStore.loadArchive()
        let archiveData = try JSONEncoder().encode(archive)
        let payload = preferences.makeSyncPayload()
        let payloadData = try JSONEncoder().encode(payload)

        var apiKeyFingerprintByServiceID: [String: String] = [:]
        for service in payload.aiServiceEndpoints {
            let apiKey = try apiKeyStore.loadAPIKey(for: service.id)
            let fingerprint = Self.fingerprint(for: apiKey)
            apiKeyFingerprintByServiceID[service.id.uuidString.lowercased()] = fingerprint
        }

        return SyncManifest(
            archiveVersion: Self.stableHash(for: archiveData),
            preferencesVersion: Self.stableHash(for: payloadData),
            apiKeyFingerprintByServiceID: apiKeyFingerprintByServiceID,
            generatedAt: Date()
        )
    }

    public func buildPatch(since remote: SyncManifest) async throws -> SyncPatch {
        let archive = try archiveStore.loadArchive()
        let archiveData = try JSONEncoder().encode(archive)
        let archiveVersion = Self.stableHash(for: archiveData)
        let payload = preferences.makeSyncPayload()
        let preferencesData = try JSONEncoder().encode(payload)
        let localServiceIDs = payload.aiServiceEndpoints.map(\.id)
        let apiKeys = try apiKeyStore.exportAPIKeys(for: localServiceIDs)

        let encryptedAPIKeysByServiceID = Dictionary(
            uniqueKeysWithValues: apiKeys.map { key, value in
                (key.uuidString.lowercased(), Data(value.utf8))
            }
        )

        return SyncPatch(
            archiveVersion: archiveVersion,
            preferencesVersion: Self.stableHash(for: preferencesData),
            archivePayload: archiveVersion != remote.archiveVersion ? archiveData : nil,
            preferencesPayload: Self.stableHash(for: preferencesData) != remote.preferencesVersion ? preferencesData : nil,
            encryptedAPIKeysByServiceID: encryptedAPIKeysByServiceID
        )
    }

    public func apply(patch: SyncPatch) async throws {
        if let archivePayload = patch.archivePayload {
            let incomingArchive = try JSONDecoder().decode(AIConversationArchive.self, from: archivePayload)
            let current = try archiveStore.loadArchive()
            let merged = mergeArchives(local: current, remote: incomingArchive)
            try archiveStore.saveArchive(merged)
        }

        if let preferencesPayload = patch.preferencesPayload {
            let incomingPayload = try JSONDecoder().decode(UserPreferences.SyncablePreferencesPayload.self, from: preferencesPayload)
            preferences.applySyncPayload(incomingPayload)
        }

        let imported: [UUID: String] = Dictionary(
            uniqueKeysWithValues: patch.encryptedAPIKeysByServiceID.compactMap { key, data in
                guard let uuid = UUID(uuidString: key), let value = String(data: data, encoding: .utf8) else {
                    return nil
                }
                return (uuid, value)
            }
        )
        try apiKeyStore.importAPIKeys(imported)
    }

    private func mergeArchives(local: AIConversationArchive, remote: AIConversationArchive) -> AIConversationArchive {
        AIConversationArchive(
            sessions: mergeByID(local.sessions, remote.sessions, keyPath: \.id),
            summaries: mergeByID(local.summaries, remote.summaries, keyPath: \.id),
            memorySnapshots: mergeByID(local.memorySnapshots, remote.memorySnapshots, keyPath: \.id),
            longFormReports: mergeByID(local.longFormReports, remote.longFormReports, keyPath: \.id)
        )
    }

    private func mergeByID<T: Equatable, Key: Hashable>(
        _ local: [T],
        _ remote: [T],
        keyPath: KeyPath<T, Key>
    ) -> [T] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0[keyPath: keyPath], $0) })
        for item in remote {
            merged[item[keyPath: keyPath]] = item
        }
        return Array(merged.values)
    }

    private static func fingerprint(for apiKey: String) -> String {
        guard !apiKey.isEmpty else { return "empty" }
        return "plain:\(stableHash(for: Data(apiKey.utf8)))"
    }

    private static func stableHash(for data: Data) -> Int {
        data.reduce(0) { partialResult, byte in
            (partialResult &* 31) &+ Int(byte)
        }
    }
}
