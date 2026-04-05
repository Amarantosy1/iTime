import Foundation

public enum SyncCoordinatorError: Error, Equatable {
    case manifestTimeout
    case patchTimeout
    case resultTimeout
}

public final class SyncCoordinator: @unchecked Sendable {
    public enum SyncResponderEvent: Equatable, Sendable {
        case completed(peerID: String)
        case failed(peerID: String, message: String)
    }

    private enum SyncResponderState: Sendable {
        case idle
        case awaitingManifest
        case awaitingPatch
    }

    private let transport: MultipeerTransport
    private let adapter: SyncPersistenceAdapter
    private let localDeviceName: String
    private let timeoutNanoseconds: UInt64

    public init(
        transport: MultipeerTransport,
        adapter: SyncPersistenceAdapter,
        localDeviceName: String = ProcessInfo.processInfo.hostName,
        timeoutNanoseconds: UInt64 = 10_000_000_000
    ) {
        self.transport = transport
        self.adapter = adapter
        self.localDeviceName = localDeviceName
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    public func syncNow(with peerID: String) async throws {
        try await transport.connect(to: peerID)
        try await transport.send(
            .hello(SyncHello(protocolVersion: 1, deviceName: localDeviceName)),
            to: peerID
        )

        let localManifest = try await adapter.makeManifest()
        try await transport.send(.manifest(localManifest), to: peerID)

        let remoteManifest = try await waitForManifest(from: peerID)
        let localPatch = try await adapter.buildPatch(since: remoteManifest)
        try await transport.send(.patch(localPatch), to: peerID)

        let remotePatch = try await waitForPatch(from: peerID)
        try await adapter.apply(patch: remotePatch)

        let appliedManifest = try await adapter.makeManifest()
        let result = SyncResult(
            status: .success,
            appliedArchiveVersion: appliedManifest.archiveVersion,
            appliedPreferencesVersion: appliedManifest.preferencesVersion,
            message: nil
        )
        try await transport.send(.result(result), to: peerID)
    }

    public func startDiscovery() async {
        await transport.startBrowsing()
    }

    public func stopDiscovery() async {
        await transport.stopBrowsing()
    }

    public func discoveredPeers() -> AsyncStream<DevicePeer> {
        transport.discoveredPeers
    }

    public func startResponding(
        onEvent: @escaping @Sendable (SyncResponderEvent) async -> Void
    ) async {
        var stateByPeerID: [String: SyncResponderState] = [:]

        for await (peerID, message) in transport.incomingMessages() {
            if Task.isCancelled { return }

            let currentState = stateByPeerID[peerID] ?? .idle

            do {
                switch (currentState, message) {
                case (.idle, .hello):
                    try await transport.send(
                        .hello(SyncHello(protocolVersion: 1, deviceName: localDeviceName)),
                        to: peerID
                    )
                    let localManifest = try await adapter.makeManifest()
                    try await transport.send(.manifest(localManifest), to: peerID)
                    stateByPeerID[peerID] = .awaitingManifest

                case (.awaitingManifest, .manifest(let remoteManifest)):
                    let localPatch = try await adapter.buildPatch(since: remoteManifest)
                    try await transport.send(.patch(localPatch), to: peerID)
                    stateByPeerID[peerID] = .awaitingPatch

                case (.awaitingPatch, .patch(let remotePatch)):
                    try await adapter.apply(patch: remotePatch)
                    let appliedManifest = try await adapter.makeManifest()
                    let result = SyncResult(
                        status: .success,
                        appliedArchiveVersion: appliedManifest.archiveVersion,
                        appliedPreferencesVersion: appliedManifest.preferencesVersion,
                        message: nil
                    )
                    try await transport.send(.result(result), to: peerID)
                    stateByPeerID[peerID] = .idle
                    await onEvent(.completed(peerID: peerID))

                case (.idle, .manifest), (.idle, .patch), (.idle, .result),
                    (.awaitingManifest, .hello), (.awaitingManifest, .patch), (.awaitingManifest, .result),
                    (.awaitingPatch, .hello), (.awaitingPatch, .manifest), (.awaitingPatch, .result):
                    continue
                }
            } catch {
                stateByPeerID[peerID] = .idle
                await onEvent(.failed(peerID: peerID, message: error.localizedDescription))
            }
        }
    }

    private func waitForManifest(from peerID: String) async throws -> SyncManifest {
        try await waitForMessage(from: peerID, extract: { message in
            if case .manifest(let manifest) = message {
                return manifest
            }
            return nil
        }, timeoutError: .manifestTimeout)
    }

    private func waitForPatch(from peerID: String) async throws -> SyncPatch {
        try await waitForMessage(from: peerID, extract: { message in
            if case .patch(let patch) = message {
                return patch
            }
            return nil
        }, timeoutError: .patchTimeout)
    }

    private func waitForMessage<T: Sendable>(
        from peerID: String,
        extract: @escaping @Sendable (SyncMessage) -> T?,
        timeoutError: SyncCoordinatorError
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { [transport] in
                for await incoming in transport.incomingMessages() {
                    guard incoming.peerID == peerID else { continue }
                    if let extracted = extract(incoming.message) {
                        return extracted
                    }
                }
                throw timeoutError
            }
            group.addTask { [timeoutNanoseconds] in
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw timeoutError
            }

            guard let value = try await group.next() else {
                throw timeoutError
            }
            group.cancelAll()
            return value
        }
    }
}
