import SwiftUI

struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RangePicker(selection: $model.preferences.selectedRange)
                .onChange(of: model.preferences.selectedRange) { _, newValue in
                    Task { await model.setRange(newValue) }
                }

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
                    ForEach(overview.buckets.prefix(3)) { bucket in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)
                            Text(bucket.name)
                            Spacer()
                            Text(bucket.totalDuration.formattedDuration)
                                .foregroundStyle(.secondary)
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
