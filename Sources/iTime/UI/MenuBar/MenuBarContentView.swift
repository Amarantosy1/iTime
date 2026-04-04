import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

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
        VStack(alignment: .leading, spacing: 20) {
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

            HStack(spacing: 12) {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    openOverviewWindow()
                } label: {
                    Label("查看详情", systemImage: "chart.bar.xaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(20)
        .frame(width: 340)
        .task {
            await model.refresh()
        }
    }

    @MainActor
    private func openOverviewWindow() {
        #if canImport(AppKit)
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)
        #endif

        openWindow(id: OverviewWindowView.windowID)

        #if canImport(AppKit)
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        #endif
    }

    @ViewBuilder
    private var authorizedContent: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已追踪时间")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(model.overview?.totalDuration.formattedDuration ?? "0m")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                if let overview = model.overview, !overview.buckets.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(MenuBarBucketChartCopy.sectionTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        ForEach(MenuBarBucketChartRow.makeRows(from: overview.buckets)) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: row.colorHex))
                                        .frame(width: 8, height: 8)

                                    Text(row.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)

                                    Spacer(minLength: 8)

                                    Text(row.shareText)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }

                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(.quaternary.opacity(0.5))

                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: row.colorHex), Color(hex: row.colorHex).opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: max(proxy.size.width * row.fillRatio, row.fillRatio > 0 ? 10 : 0))
                                            .shadow(color: Color(hex: row.colorHex).opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                }
                                .frame(height: 6)

                                Text(row.durationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("当前范围内没有日程。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
