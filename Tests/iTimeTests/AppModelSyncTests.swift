import Foundation
import Testing
@testable import iTime

private final class SyncStubCalendarService: CalendarAccessServing {
    let state: CalendarAuthorizationState = .authorized

    func authorizationState() -> CalendarAuthorizationState { state }
    func requestAccess() async -> CalendarAuthorizationState { state }
    func fetchCalendars() -> [CalendarSource] { [] }
    func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] { [] }
}

private final class SyncTestTransport: @unchecked Sendable, MultipeerTransport {
    let discoveredPeers: AsyncStream<DevicePeer>
    private let discoveredContinuation: AsyncStream<DevicePeer>.Continuation
    private let incoming: AsyncStream<(peerID: String, message: SyncMessage)>
    private let incomingContinuation: AsyncStream<(peerID: String, message: SyncMessage)>.Continuation

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

    func connect(to peerID: String) async throws {}

    func send(_ message: SyncMessage, to peerID: String) async throws {}

    func incomingMessages() -> AsyncStream<(peerID: String, message: SyncMessage)> {
        incoming
    }

    func pushIncoming(_ item: (peerID: String, message: SyncMessage)) {
        incomingContinuation.yield(item)
    }
}

private final class AppModelSyncArchiveStore: @unchecked Sendable, AIConversationArchiveStoring {
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

private final class AppModelSyncKeyStore: @unchecked Sendable, AIAPIKeyStoring {
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

@MainActor
private func makeSyncModelFixture() -> (model: AppModel, transport: SyncTestTransport) {
    let prefs = UserPreferences(storage: .inMemory)
    prefs.setAIProviderEnabled(true, for: .openAI)
    prefs.setAIProviderModel("gpt-5-mini", for: .openAI)

    let archiveStore = AppModelSyncArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [],
            memorySnapshots: [],
            longFormReports: []
        )
    )
    let keyStore = AppModelSyncKeyStore(values: [AIProviderKind.openAI.builtInServiceID: "sk-local"])
    let adapter = SyncPersistenceAdapter(
        archiveStore: archiveStore,
        preferences: prefs,
        apiKeyStore: keyStore
    )
    let transport = SyncTestTransport()
    let coordinator = SyncCoordinator(
        transport: transport,
        adapter: adapter,
        localDeviceName: "Local Device",
        timeoutNanoseconds: 2_000_000_000
    )
    let model = AppModel(
        service: SyncStubCalendarService(),
        preferences: prefs,
        aiKeyStore: keyStore,
        aiConversationArchiveStore: archiveStore,
        reviewReminderScheduler: NoopReviewReminderScheduler(),
        syncCoordinator: coordinator
    )
    return (model, transport)
}

@MainActor
@Test func appModelSyncFlowUpdatesStateToSucceeded() async throws {
    let fixture = makeSyncModelFixture()
    let model = fixture.model
    let transport = fixture.transport

    await model.startDeviceDiscovery()
    try? await Task.sleep(nanoseconds: 100_000_000)
    #expect(!model.discoveredPeers.isEmpty)

    Task {
        try await Task.sleep(nanoseconds: 100_000_000)
        transport.pushIncoming(
            (
                peerID: "peer-a",
                message: .manifest(
                    SyncManifest(
                        archiveVersion: 0,
                        preferencesVersion: 0,
                        apiKeyFingerprintByServiceID: [:],
                        generatedAt: Date()
                    )
                )
            )
        )
        transport.pushIncoming(
            (
                peerID: "peer-a",
                message: .patch(
                    SyncPatch(
                        archiveVersion: 0,
                        preferencesVersion: 0,
                        archivePayload: nil,
                        preferencesPayload: nil,
                        encryptedAPIKeysByServiceID: [:]
                    )
                )
            )
        )
    }

    try await model.syncNow(with: "peer-a")
    #expect(model.lastSyncStatus == .succeeded)
}
