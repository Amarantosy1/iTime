import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct OverviewWindowView: View {
    static let windowID = "overview"

    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.overviewBackgroundGradient(for: colorScheme)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
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
                    .frame(maxWidth: .infinity, alignment: .center)

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
                .padding(32)
            }
        }
        .task {
            await model.refresh()
        }
        .onAppear {
            #if canImport(AppKit)
            let application = NSApplication.shared
            application.setActivationPolicy(.regular)
            application.activate(ignoringOtherApps: true)
            #endif
        }
        .onDisappear {
            #if canImport(AppKit)
            let hasVisibleMainWindow = NSApplication.shared.windows.contains { window in
                window.isVisible && !window.title.isEmpty
            }
            if !hasVisibleMainWindow {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            GlassHeadlineText(text: "我的时间去哪了？")
            
            Text("基于日历数据的个人时间深度复盘")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var customDateRangeControls: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(CustomDateRangePreset.allCases, id: \.self) { preset in
                        Button(preset.title) {
                            Task { await model.setCustomDateRange(preset: preset) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

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
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = model.overview, !overview.buckets.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                OverviewMetricsSection(overview: overview)
                OverviewAIAnalysisSection(model: model)
                OverviewTrendChartView(overview: overview)

                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("分类分布")
                            .font(.headline)

                        OverviewChartView(overview: overview)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

private struct GlassHeadlineText: View {
    let text: String

    var body: some View {
        titleText
            .foregroundStyle(
                LinearGradient(
                    colors: [.primary, .primary.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
    }

    private var titleText: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold, design: .rounded))
    }
}
