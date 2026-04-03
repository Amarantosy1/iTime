import Charts
import SwiftUI

enum OverviewTrendChartCopy {
    static let summaryPrefix = "最忙时段"

    static func title(for resolution: OverviewStackedBucketResolution) -> String {
        switch resolution {
        case .hour:
            return "今日分布"
        case .day:
            return "每日分布"
        case .week:
            return "每周分布"
        }
    }

    static func summary(for bucket: OverviewStackedBucket) -> String? {
        guard
            bucket.totalDuration > 0,
            let dominantSegment = bucket.segments.max(by: { $0.duration < $1.duration })
        else {
            return nil
        }

        return "\(summaryPrefix)：\(bucket.label)，共 \(bucket.totalDuration.formattedDuration)，其中\(dominantSegment.calendarName) \(dominantSegment.duration.formattedDuration)。"
    }

    static func xDomainLabels(for buckets: [OverviewStackedBucket]) -> [String] {
        buckets.map(\.label)
    }
}

struct OverviewTrendChartView: View {
    let overview: TimeOverview

    private let legendColumns = [
        GridItem(.adaptive(minimum: 120), alignment: .leading),
    ]

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(OverviewTrendChartCopy.title(for: overview.stackedBucketResolution))
                    .font(.headline)

                Chart {
                    ForEach(overview.stackedBuckets) { bucket in
                        BarMark(
                            x: .value("时间", bucket.label),
                            y: .value("时长", 0)
                        )
                        .opacity(0.001)
                    }

                    ForEach(overview.stackedBuckets) { bucket in
                        ForEach(bucket.segments) { segment in
                            BarMark(
                                x: .value("时间", bucket.label),
                                y: .value("时长", segment.duration / 3600)
                            )
                            .foregroundStyle(Color(hex: segment.calendarColorHex))
                            .cornerRadius(6)
                        }
                    }
                }
                .chartXScale(domain: OverviewTrendChartCopy.xDomainLabels(for: overview.stackedBuckets))
                .chartLegend(.hidden)
                .frame(height: 260)

                if let summary = busiestBucketSummary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: legendColumns, alignment: .leading, spacing: 10) {
                    ForEach(overview.buckets) { bucket in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)

                            Text(bucket.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var busiestBucketSummary: String? {
        guard let bucket = overview.stackedBuckets.max(by: { $0.totalDuration < $1.totalDuration }) else {
            return nil
        }

        return OverviewTrendChartCopy.summary(for: bucket)
    }
}
