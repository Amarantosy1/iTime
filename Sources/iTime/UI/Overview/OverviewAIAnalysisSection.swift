import SwiftUI

enum AIAnalysisCopy {
    static let sectionTitle = "AI 时间评估"
    static let openConversationWindowAction = "打开 AI 复盘"
    static let historyAction = "查看历史总结"
    static let latestSummaryTitle = "最近一次总结"
}

struct OverviewAIAnalysisSection: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var showsHistory = false

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text(AIAnalysisCopy.sectionTitle)
                        .font(.headline)

                    Spacer()

                    if !model.aiConversationHistory.isEmpty {
                        Button(AIAnalysisCopy.historyAction) {
                            showsHistory = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                switch model.aiConversationState {
                case .unavailable(let availability):
                    Text(availability.message)
                        .foregroundStyle(.secondary)

                    if availability != .noData {
                        SettingsLink {
                            Text("打开设置")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                case .asking, .responding, .waitingForUser, .summarizing:
                    openWindowButton
                    latestSummaryCard

                case .idle, .completed:
                    openWindowButton
                    latestSummaryCard

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)
                    openWindowButton
                    latestSummaryCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showsHistory) {
            AIConversationHistoryView(model: model)
        }
    }

    private var openWindowButton: some View {
        Button(AIAnalysisCopy.openConversationWindowAction) {
            openWindow(id: AIConversationWindowView.windowID)
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var latestSummaryCard: some View {
        if let summary = model.latestAIConversationSummary {
            VStack(alignment: .leading, spacing: 8) {
                Text(AIAnalysisCopy.latestSummaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(summary.headline)
                    .font(.title3.weight(.semibold))

                Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(summary.summary)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
