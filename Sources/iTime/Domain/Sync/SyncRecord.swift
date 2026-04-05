import Foundation

public struct SyncRecord<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let recordID: String
    public let value: Value?
    public let updatedAt: Date
    public let deletedAt: Date?
    public let version: Int

    public init(
        recordID: String,
        value: Value?,
        updatedAt: Date,
        deletedAt: Date?,
        version: Int
    ) {
        self.recordID = recordID
        self.value = value
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.version = version
    }

    public var isDeleted: Bool {
        deletedAt != nil
    }
}
