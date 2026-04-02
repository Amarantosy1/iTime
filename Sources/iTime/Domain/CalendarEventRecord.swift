import Foundation

public struct CalendarEventRecord: Equatable, Sendable {
    public let id: String
    public let title: String
    public let calendarID: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool

    public init(
        id: String,
        title: String,
        calendarID: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) {
        self.id = id
        self.title = title
        self.calendarID = calendarID
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }
}
