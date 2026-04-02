import Foundation

public enum TimeRangePreset: String, CaseIterable, Codable, Sendable {
    case today
    case week
    case month

    var title: String {
        switch self {
        case .today:
            "今天"
        case .week:
            "本周"
        case .month:
            "本月"
        }
    }
}
