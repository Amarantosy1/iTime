import SwiftUI

struct OverviewWindowView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                RangePicker(selection: $model.preferences.selectedRange)
                    .onChange(of: model.preferences.selectedRange) { _, newValue in
                        Task { await model.setRange(newValue) }
                    }

                if model.authorizationState == .authorized {
                    overviewContent
                } else {
                    AuthorizationStateView(state: model.authorizationState) {
                        Task { await model.requestAccessIfNeeded() }
                    }
                }
            }
            .padding(24)
        }
        .background(AppTheme.overviewBackgroundGradient(for: colorScheme).linearGradient)
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的时间去哪了？")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("基于日历事件统计你的时间分布。")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = model.overview, !overview.buckets.isEmpty {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(overview.totalDuration.formattedDuration)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))

                    OverviewChartView(overview: overview)

                    ForEach(overview.buckets) { bucket in
                        HStack {
                            Label(bucket.name, systemImage: "circle.fill")
                                .foregroundStyle(Color(hex: bucket.colorHex))
                            Spacer()
                            Text(bucket.shareText)
                                .fontWeight(.semibold)
                            Text(bucket.totalDuration.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            LiquidGlassCard {
                Text("当前时间范围内没有可统计的日程。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
