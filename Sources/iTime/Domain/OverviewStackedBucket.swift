import Foundation

public enum OverviewStackedBucketResolution: String, Equatable, Sendable {
    case day
    case week
}

public struct OverviewStackedSegment: Identifiable, Equatable, Sendable {
    public let calendarID: String
    public let calendarName: String
    public let calendarColorHex: String
    public let duration: TimeInterval

    public var id: String { calendarID }

    public init(
        calendarID: String,
        calendarName: String,
        calendarColorHex: String,
        duration: TimeInterval
    ) {
        self.calendarID = calendarID
        self.calendarName = calendarName
        self.calendarColorHex = calendarColorHex
        self.duration = duration
    }
}

public struct OverviewStackedBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let interval: DateInterval
    public let totalDuration: TimeInterval
    public let segments: [OverviewStackedSegment]

    public init(
        id: String,
        label: String,
        interval: DateInterval,
        totalDuration: TimeInterval,
        segments: [OverviewStackedSegment]
    ) {
        self.id = id
        self.label = label
        self.interval = interval
        self.totalDuration = totalDuration
        self.segments = segments
    }
}
