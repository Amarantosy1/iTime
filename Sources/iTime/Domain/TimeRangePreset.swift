import Foundation

public enum TimeRangePreset: String, CaseIterable, Codable, Sendable {
    case today
    case week
    case month

    var title: String {
        switch self {
        case .today:
            "Today"
        case .week:
            "Week"
        case .month:
            "Month"
        }
    }
}
