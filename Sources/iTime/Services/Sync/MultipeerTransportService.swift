import Foundation
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif

public final class MultipeerTransportService: NSObject, MultipeerTransport {
    public let discoveredPeers: AsyncStream<DevicePeer>

    private let peerStreamContinuation: AsyncStream<DevicePeer>.Continuation
    private let messageStream: AsyncStream<(peerID: String, message: SyncMessage)>
    private let messageStreamContinuation: AsyncStream<(peerID: String, message: SyncMessage)>.Continuation
    private let serviceType: String
    private let localPeerID: String

    #if canImport(MultipeerConnectivity)
    private var mcPeerID: MCPeerID?
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?
    #endif

    public init(serviceType: String, localPeerID: String = Host.current().localizedName ?? "iTime") {
        self.serviceType = serviceType
        self.localPeerID = localPeerID

        let peers = AsyncStream<DevicePeer>.makeStream()
        discoveredPeers = peers.stream
        peerStreamContinuation = peers.continuation

        let incoming = AsyncStream<(peerID: String, message: SyncMessage)>.makeStream()
        messageStream = incoming.stream
        messageStreamContinuation = incoming.continuation
        super.init()
    }

    public func startBrowsing() async {
        #if canImport(MultipeerConnectivity)
        setupSessionIfNeeded()
        browser?.startBrowsingForPeers()
        advertiser?.startAdvertisingPeer()
        #endif
    }

    public func stopBrowsing() async {
        #if canImport(MultipeerConnectivity)
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        #endif
    }

    public func connect(to peerID: String) async throws {
        #if canImport(MultipeerConnectivity)
        setupSessionIfNeeded()
        if let browser {
            // Discovery callback sends invitation; explicit connect kept as no-op placeholder.
            _ = browser
            _ = peerID
            return
        }
        #endif
        throw SyncTransportError.peerNotFound(peerID)
    }

    public func send(_ message: SyncMessage, to peerID: String) async throws {
        #if canImport(MultipeerConnectivity)
        guard let session else { throw SyncTransportError.peerNotFound(peerID) }
        guard
            let target = session.connectedPeers.first(where: { $0.displayName == peerID })
        else {
            throw SyncTransportError.peerNotFound(peerID)
        }
        let data = try JSONEncoder().encode(message)
        try session.send(data, toPeers: [target], with: .reliable)
        return
        #else
        _ = message
        throw SyncTransportError.peerNotFound(peerID)
        #endif
    }

    public func incomingMessages() -> AsyncStream<(peerID: String, message: SyncMessage)> {
        messageStream
    }

    #if canImport(MultipeerConnectivity)
    private func setupSessionIfNeeded() {
        guard session == nil else { return }
        let peer = MCPeerID(displayName: localPeerID)
        mcPeerID = peer
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        browser.delegate = self
        self.browser = browser

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser.delegate = self
        self.advertiser = advertiser
    }
    #endif
}

#if canImport(MultipeerConnectivity)
extension MultipeerTransportService: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let mapped: DevicePeer.ConnectionState
        switch state {
        case .connected:
            mapped = .connected
        case .connecting:
            mapped = .connecting
        case .notConnected:
            mapped = .failed("连接已断开")
        @unknown default:
            mapped = .failed("未知连接状态")
        }
        peerStreamContinuation.yield(DevicePeer(id: peerID.displayName, displayName: peerID.displayName, state: mapped))
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else {
            return
        }
        messageStreamContinuation.yield((peerID: peerID.displayName, message: message))
    }

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

extension MultipeerTransportService: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        peerStreamContinuation.yield(DevicePeer(id: peerID.displayName, displayName: peerID.displayName, state: .discovered))
        if let session {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 8)
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        peerStreamContinuation.yield(DevicePeer(id: peerID.displayName, displayName: peerID.displayName, state: .failed("设备离线")))
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        peerStreamContinuation.yield(DevicePeer(id: "local", displayName: localPeerID, state: .failed(error.localizedDescription)))
    }
}

extension MultipeerTransportService: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        peerStreamContinuation.yield(DevicePeer(id: "local", displayName: localPeerID, state: .failed(error.localizedDescription)))
    }
}
#endif
