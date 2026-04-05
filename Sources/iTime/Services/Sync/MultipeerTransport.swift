import Foundation

public protocol MultipeerTransport {
    var discoveredPeers: AsyncStream<DevicePeer> { get }

    func startBrowsing() async
    func stopBrowsing() async
    func connect(to peerID: String) async throws
    func send(_ message: SyncMessage, to peerID: String) async throws
    func incomingMessages() -> AsyncStream<(peerID: String, message: SyncMessage)>
}

public enum SyncTransportError: Error, Equatable {
    case peerNotFound(String)
    case invalidPayload
    case timeout
}
