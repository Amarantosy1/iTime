import Foundation
import Testing
@testable import iTime

private final class FakeTransport: @unchecked Sendable, MultipeerTransport {
    let discoveredPeers: AsyncStream<DevicePeer>
    private let discoveredContinuation: AsyncStream<DevicePeer>.Continuation
    private let incoming: AsyncStream<(peerID: String, message: SyncMessage)>
    private let incomingContinuation: AsyncStream<(peerID: String, message: SyncMessage)>.Continuation

    private(set) var sentMessages: [SyncMessage] = []
    private(set) var connectedPeerIDs: [String] = []

    init() {
        let peers = AsyncStream<DevicePeer>.makeStream()
        discoveredPeers = peers.stream
        discoveredContinuation = peers.continuation
        let messages = AsyncStream<(peerID: String, message: SyncMessage)>.makeStream()
        incoming = messages.stream
        incomingContinuation = messages.continuation
    }

    func startBrowsing() async {
        discoveredContinuation.yield(DevicePeer(id: "peer-a", displayName: "Peer A", state: .discovered))
    }

    func stopBrowsing() async {}

    func connect(to peerID: String) async throws {
        connectedPeerIDs.append(peerID)
    }

    func send(_ message: SyncMessage, to peerID: String) async throws {
        sentMessages.append(message)
    }

    func incomingMessages() -> AsyncStream<(peerID: String, message: SyncMessage)> {
        incoming
    }

    func pushIncoming(peerID: String, message: SyncMessage) {
        incomingContinuation.yield((peerID: peerID, message: message))
    }
}

private final class CoordinatorInMemoryArchiveStore: @unchecked Sendable, AIConversationArchiveStoring {
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

private final class CoordinatorInMemoryKeyStore: @unchecked Sendable, AIAPIKeyStoring {
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

@Test func syncCoordinatorRunsHelloManifestPatchResultFlow() async throws {
    let archive = AIConversationArchive(
        sessions: [],
        summaries: [],
        memorySnapshots: [],
        longFormReports: []
    )
    let archiveStore = CoordinatorInMemoryArchiveStore(archive: archive)
    let preferences = UserPreferences(storage: .inMemory)
    preferences.setAIProviderEnabled(true, for: .openAI)
    preferences.setAIProviderModel("gpt-5-mini", for: .openAI)
    let keyStore = CoordinatorInMemoryKeyStore(values: [AIProviderKind.openAI.builtInServiceID: "sk-local"])
    let adapter = SyncPersistenceAdapter(
        archiveStore: archiveStore,
        preferences: preferences,
        apiKeyStore: keyStore
    )
    let transport = FakeTransport()
    let coordinator = SyncCoordinator(
        transport: transport,
        adapter: adapter,
        localDeviceName: "Local Device",
        timeoutNanoseconds: 2_000_000_000
    )

    Task {
        try await Task.sleep(nanoseconds: 100_000_000)
        transport.pushIncoming(
            peerID: "peer-a",
            message: .manifest(
                SyncManifest(
                    archiveVersion: 0,
                    preferencesVersion: 0,
                    apiKeyFingerprintByServiceID: [:],
                    generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
                )
            )
        )
        transport.pushIncoming(
            peerID: "peer-a",
            message: .patch(
                SyncPatch(
                    archiveVersion: 1,
                    preferencesVersion: 1,
                    archivePayload: nil,
                    preferencesPayload: nil,
                    encryptedAPIKeysByServiceID: [:]
                )
            )
        )
    }

    try await coordinator.syncNow(with: "peer-a")

    #expect(transport.connectedPeerIDs == ["peer-a"])
    #expect(transport.sentMessages.contains(where: {
        if case .hello = $0 { return true }
        return false
    }))
    #expect(transport.sentMessages.contains(where: {
        if case .manifest = $0 { return true }
        return false
    }))
    #expect(transport.sentMessages.contains(where: {
        if case .patch = $0 { return true }
        return false
    }))
    #expect(transport.sentMessages.contains(where: {
        if case .result = $0 { return true }
        return false
    }))
}
