import SwiftUI

struct OverviewBucketTable: View {
    let overview: TimeOverview

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("日历排行")
                    .font(.headline)

                ForEach(overview.buckets) { bucket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)
                            Text(bucket.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(bucket.totalDuration.formattedDuration)
                                .fontWeight(.semibold)
                        }

                        HStack(spacing: 12) {
                            Text("占比 \(bucket.shareText)")
                            Text("事件 \(bucket.eventCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
