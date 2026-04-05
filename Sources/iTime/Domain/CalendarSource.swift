import Foundation

public struct CalendarSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let colorHex: String
    public var isSelected: Bool
    public var isIncludedInReview: Bool

    public init(
        id: String,
        name: String,
        colorHex: String,
        isSelected: Bool,
        isIncludedInReview: Bool = true
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isSelected = isSelected
        self.isIncludedInReview = isIncludedInReview
    }
}
