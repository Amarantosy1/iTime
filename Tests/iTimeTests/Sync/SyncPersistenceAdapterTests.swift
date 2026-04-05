import Foundation
import Testing
@testable import iTime

private final class InMemorySyncArchiveStore: @unchecked Sendable, AIConversationArchiveStoring {
    var archive: AIConversationArchive

    init(archive: AIConversationArchive) {
        self.archive = archive
    }

    func loadArchive() throws -> AIConversationArchive {
        archive
    }

    func saveArchive(_ archive: AIConversationArchive) throws {
        self.archive = archive
    }
}

private final class InMemorySyncKeyStore: @unchecked Sendable, AIAPIKeyStoring {
    var values: [UUID: String]

    init(values: [UUID: String]) {
        self.values = values
    }

    func loadAPIKey(for serviceID: UUID) throws -> String {
        values[serviceID] ?? ""
    }

    func saveAPIKey(_ apiKey: String, for serviceID: UUID) throws {
        values[serviceID] = apiKey
    }
}

private func makeSyncAdapterFixture() -> (
    adapter: SyncPersistenceAdapter,
    archiveStore: InMemorySyncArchiveStore,
    keyStore: InMemorySyncKeyStore,
    preferences: UserPreferences
) {
    let archive = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: [],
        longFormReports: []
    )
    let archiveStore = InMemorySyncArchiveStore(archive: archive)
    let preferences = UserPreferences(storage: .inMemory)
    let serviceID = AIProviderKind.openAI.builtInServiceID
    preferences.setAIProviderEnabled(true, for: .openAI)
    preferences.setAIProviderModel("gpt-5-mini", for: .openAI)
    let keyStore = InMemorySyncKeyStore(values: [serviceID: "sk-local"])
    let adapter = SyncPersistenceAdapter(
        archiveStore: archiveStore,
        preferences: preferences,
        apiKeyStore: keyStore
    )
    return (adapter, archiveStore, keyStore, preferences)
}

private func makePatchFixture(
    preferences: UserPreferences,
    baseServiceID: UUID
) throws -> SyncPatch {
    let remotePayload = UserPreferences.SyncablePreferencesPayload(
        selectedRange: .week,
        selectedCalendarIDs: ["work"],
        reviewExcludedCalendarIDs: [],
        customStartDate: Date(timeIntervalSince1970: 100),
        customEndDate: Date(timeIntervalSince1970: 200),
        reviewReminderEnabled: true,
        reviewReminderTime: Date(timeIntervalSince1970: 300),
        aiServiceEndpoints: preferences.aiServiceEndpoints,
        defaultAIServiceID: baseServiceID
    )
    let remoteArchive = AIConversationArchive.empty
    return SyncPatch(
        archiveVersion: 10,
        preferencesVersion: 11,
        archivePayload: try JSONEncoder().encode(remoteArchive),
        preferencesPayload: try JSONEncoder().encode(remotePayload),
        encryptedAPIKeysByServiceID: [baseServiceID.uuidString.lowercased(): Data("sk-remote".utf8)]
    )
}

@Test func syncPersistenceAdapterBuildsManifestFromArchiveAndPreferences() async throws {
    let fixture = makeSyncAdapterFixture()
    let manifest = try await fixture.adapter.makeManifest()
    #expect(manifest.archiveVersion != 0)
    #expect(manifest.preferencesVersion != 0)
}

@Test func syncPersistenceAdapterAppliesPatchToArchiveAndPreferences() async throws {
    let fixture = makeSyncAdapterFixture()
    let serviceID = AIProviderKind.openAI.builtInServiceID
    let patch = try makePatchFixture(preferences: fixture.preferences, baseServiceID: serviceID)
    try await fixture.adapter.apply(patch: patch)
    let after = try await fixture.adapter.makeManifest()
    #expect(after.archiveVersion != 0)
    #expect(fixture.preferences.selectedRange == .week)
    #expect(fixture.keyStore.values[serviceID] == "sk-remote")
}

@Test func syncPersistenceAdapterBuildPatchIncludesLongFormContentUpdates() async throws {
    let fixture = makeSyncAdapterFixture()

    let reportID = UUID()
    let summaryID = UUID()
    let sessionID = UUID()
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    fixture.archiveStore.archive = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: [],
        longFormReports: [
            AIConversationLongFormReport(
                id: reportID,
                sessionID: sessionID,
                summaryID: summaryID,
                createdAt: createdAt,
                updatedAt: createdAt,
                title: "初版长文",
                content: "第一版内容"
            )
        ]
    )

    let remoteManifest = try await fixture.adapter.makeManifest()

    fixture.archiveStore.archive = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: [],
        longFormReports: [
            AIConversationLongFormReport(
                id: reportID,
                sessionID: sessionID,
                summaryID: summaryID,
                createdAt: createdAt,
                updatedAt: createdAt.addingTimeInterval(60),
                title: "初版长文",
                content: "第一版内容（已修订）"
            )
        ]
    )

    let patch = try await fixture.adapter.buildPatch(since: remoteManifest)
    #expect(patch.archivePayload != nil)
}
