import Foundation

public enum TimeRangePreset: String, CaseIterable, Codable, Sendable {
    case today
    case week
    case month
    case custom

    static var menuCases: [Self] { [.today, .week, .month] }
    static var overviewCases: [Self] { allCases }
    static var runtimeCases: [Self] { menuCases }

    var isRuntimeSelectable: Bool {
        Self.runtimeCases.contains(self)
    }

    var title: String {
        switch self {
        case .today:
            "今天"
        case .week:
            "本周"
        case .month:
            "本月"
        case .custom:
            "自定义"
        }
    }
}

public enum CustomDateRangePreset: String, CaseIterable, Sendable {
    case yesterday
    case lastWeek
    case lastMonth

    public var title: String {
        switch self {
        case .yesterday:
            "昨日"
        case .lastWeek:
            "上周"
        case .lastMonth:
            "上月"
        }
    }
}
