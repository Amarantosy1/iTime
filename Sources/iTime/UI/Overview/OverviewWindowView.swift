import SwiftUI

struct OverviewWindowView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.overviewBackgroundGradient(for: colorScheme)
                .linearGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    RangePicker(
                        selection: Binding(
                            get: { model.preferences.selectedRange },
                            set: { newValue in
                                Task { await model.setRange(newValue) }
                            }
                        ),
                        ranges: TimeRangePreset.overviewCases
                    )

                    if model.preferences.selectedRange == .custom {
                        customDateRangeControls
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
        }
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的时间去哪了？")
                .font(.system(size: 32, weight: .bold, design: .rounded))
        }
    }

    private var customDateRangeControls: some View {
        LiquidGlassCard {
            HStack(spacing: 16) {
                DatePicker(
                    "开始日期",
                    selection: Binding(
                        get: { model.preferences.customStartDate },
                        set: { newValue in
                            Task {
                                await model.setCustomDateRange(
                                    start: newValue,
                                    end: model.preferences.customEndDate
                                )
                            }
                        }
                    ),
                    displayedComponents: .date
                )

                DatePicker(
                    "结束日期",
                    selection: Binding(
                        get: { model.preferences.customEndDate },
                        set: { newValue in
                            Task {
                                await model.setCustomDateRange(
                                    start: model.preferences.customStartDate,
                                    end: newValue
                                )
                            }
                        }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = model.overview, !overview.buckets.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                OverviewMetricsSection(overview: overview)
                OverviewTrendChartView(overview: overview)

                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("分类分布")
                            .font(.headline)

                        OverviewChartView(overview: overview)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                OverviewBucketTable(overview: overview)
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
