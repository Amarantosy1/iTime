import SwiftUI

struct OverviewBucketTable: View {
    let overview: TimeOverview

    private let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .leading),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(overview.buckets) { bucket in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(hex: bucket.colorHex))
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bucket.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(bucket.shareText)
                            Text(bucket.totalDuration.formattedDuration)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    Color.secondary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
    }
}
