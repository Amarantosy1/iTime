import Foundation

public struct DailyDurationSummary: Identifiable, Equatable, Sendable {
    public let date: Date
    public let totalDuration: TimeInterval

    public var id: Date { date }

    public init(date: Date, totalDuration: TimeInterval) {
        self.date = date
        self.totalDuration = totalDuration
    }
}
