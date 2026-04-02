import Foundation

public struct TimeBucketSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String
    public let totalDuration: TimeInterval
    public let eventCount: Int
    public var share: Double

    public init(
        id: String,
        name: String,
        colorHex: String,
        totalDuration: TimeInterval,
        eventCount: Int,
        share: Double = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.totalDuration = totalDuration
        self.eventCount = eventCount
        self.share = share
    }

    public var shareText: String {
        "\(Int((share * 100).rounded()))%"
    }
}
