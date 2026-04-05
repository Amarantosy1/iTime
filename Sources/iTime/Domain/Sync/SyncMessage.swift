import Foundation

public struct SyncHello: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let deviceName: String

    public init(protocolVersion: Int, deviceName: String) {
        self.protocolVersion = protocolVersion
        self.deviceName = deviceName
    }
}

public struct SyncManifest: Codable, Equatable, Sendable {
    public let archiveVersion: Int
    public let preferencesVersion: Int
    public let apiKeyFingerprintByServiceID: [String: String]
    public let generatedAt: Date

    public init(
        archiveVersion: Int,
        preferencesVersion: Int,
        apiKeyFingerprintByServiceID: [String: String],
        generatedAt: Date
    ) {
        self.archiveVersion = archiveVersion
        self.preferencesVersion = preferencesVersion
        self.apiKeyFingerprintByServiceID = apiKeyFingerprintByServiceID
        self.generatedAt = generatedAt
    }
}

public struct SyncPatch: Codable, Equatable, Sendable {
    public let archiveVersion: Int
    public let preferencesVersion: Int
    public let archivePayload: Data?
    public let preferencesPayload: Data?
    public let encryptedAPIKeysByServiceID: [String: Data]

    public init(
        archiveVersion: Int,
        preferencesVersion: Int,
        archivePayload: Data?,
        preferencesPayload: Data?,
        encryptedAPIKeysByServiceID: [String: Data]
    ) {
        self.archiveVersion = archiveVersion
        self.preferencesVersion = preferencesVersion
        self.archivePayload = archivePayload
        self.preferencesPayload = preferencesPayload
        self.encryptedAPIKeysByServiceID = encryptedAPIKeysByServiceID
    }
}

public struct SyncResult: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case success
        case failure
    }

    public let status: Status
    public let appliedArchiveVersion: Int
    public let appliedPreferencesVersion: Int
    public let message: String?

    public init(
        status: Status,
        appliedArchiveVersion: Int,
        appliedPreferencesVersion: Int,
        message: String?
    ) {
        self.status = status
        self.appliedArchiveVersion = appliedArchiveVersion
        self.appliedPreferencesVersion = appliedPreferencesVersion
        self.message = message
    }
}

public enum SyncMessage: Equatable, Sendable {
    case hello(SyncHello)
    case manifest(SyncManifest)
    case patch(SyncPatch)
    case result(SyncResult)
}

extension SyncMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case hello
        case manifest
        case patch
        case result
    }

    private enum Kind: String, Codable {
        case hello
        case manifest
        case patch
        case result
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .hello:
            self = .hello(try container.decode(SyncHello.self, forKey: .hello))
        case .manifest:
            self = .manifest(try container.decode(SyncManifest.self, forKey: .manifest))
        case .patch:
            self = .patch(try container.decode(SyncPatch.self, forKey: .patch))
        case .result:
            self = .result(try container.decode(SyncResult.self, forKey: .result))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let hello):
            try container.encode(Kind.hello, forKey: .kind)
            try container.encode(hello, forKey: .hello)
        case .manifest(let manifest):
            try container.encode(Kind.manifest, forKey: .kind)
            try container.encode(manifest, forKey: .manifest)
        case .patch(let patch):
            try container.encode(Kind.patch, forKey: .kind)
            try container.encode(patch, forKey: .patch)
        case .result(let result):
            try container.encode(Kind.result, forKey: .kind)
            try container.encode(result, forKey: .result)
        }
    }
}
