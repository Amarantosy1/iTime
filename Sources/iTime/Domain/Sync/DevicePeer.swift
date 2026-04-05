import Foundation

public struct DevicePeer: Identifiable, Equatable, Sendable {
    public enum ConnectionState: Equatable, Sendable {
        case discovered
        case connecting
        case connected
        case failed(String)
    }

    public let id: String
    public let displayName: String
    public let state: ConnectionState

    public init(id: String, displayName: String, state: ConnectionState) {
        self.id = id
        self.displayName = displayName
        self.state = state
    }
}
