import SwiftUI

enum MenuBarBucketChartCopy {
    static let sectionTitle = "按日历分布"
}

struct MenuBarBucketChartRow: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let durationText: String
    let shareText: String
    let fillRatio: Double

    static func makeRows(
        from buckets: [TimeBucketSummary],
        limit: Int = 4
    ) -> [MenuBarBucketChartRow] {
        Array(buckets.prefix(limit)).map { bucket in
            MenuBarBucketChartRow(
                id: bucket.id,
                name: bucket.name,
                colorHex: bucket.colorHex,
                durationText: bucket.totalDuration.formattedDuration,
                shareText: bucket.shareText,
                fillRatio: min(max(bucket.share, 0), 1)
            )
        }
    }
}

struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RangePicker(
                selection: Binding(
                    get: { model.liveSelectedRange },
                    set: { newValue in
                        Task { await model.setRange(newValue) }
                    }
                )
            )

            switch model.authorizationState {
            case .authorized:
                authorizedContent
            default:
                AuthorizationStateView(state: model.authorizationState) {
                    Task { await model.requestAccessIfNeeded() }
                }
            }

            HStack(spacing: 10) {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    openWindow(id: "overview")
                } label: {
                    Label("查看详情", systemImage: "chart.bar.xaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 340)
        .task {
            await model.refresh()
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("已追踪时间")
                    .font(.headline)

                Text(model.overview?.totalDuration.formattedDuration ?? "0m")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                if let overview = model.overview, !overview.buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(MenuBarBucketChartCopy.sectionTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(MenuBarBucketChartRow.makeRows(from: overview.buckets)) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: row.colorHex))
                                        .frame(width: 8, height: 8)

                                    Text(row.name)
                                        .font(.subheadline)
                                        .lineLimit(1)

                                    Spacer(minLength: 8)

                                    Text(row.shareText)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(.quaternary)

                                        Capsule()
                                            .fill(Color(hex: row.colorHex))
                                            .frame(width: max(proxy.size.width * row.fillRatio, row.fillRatio > 0 ? 10 : 0))
                                    }
                                }
                                .frame(height: 8)

                                Text(row.durationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("当前范围内没有日程。")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
