import SwiftUI

enum OverviewMetricKind: CaseIterable {
    case totalDuration
    case eventCount
    case averageDailyDuration
    case longestDay

    var title: String {
        switch self {
        case .totalDuration:
            "总时长"
        case .eventCount:
            "事件数"
        case .averageDailyDuration:
            "日均时长"
        case .longestDay:
            "最长单日"
        }
    }
}

struct OverviewMetricsSection: View {
    let overview: TimeOverview

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            ForEach(OverviewMetricKind.allCases, id: \.self) { metric in
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(value(for: metric))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func value(for metric: OverviewMetricKind) -> String {
        switch metric {
        case .totalDuration:
            overview.totalDuration.formattedDuration
        case .eventCount:
            "\(overview.totalEventCount)"
        case .averageDailyDuration:
            overview.averageDailyDuration.formattedDuration
        case .longestDay:
            overview.longestDayDuration.formattedDuration
        }
    }
}
