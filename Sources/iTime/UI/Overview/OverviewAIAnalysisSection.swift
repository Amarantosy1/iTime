import SwiftUI

enum AIAnalysisCopy {
    static let sectionTitle = "AI 时间评估"
    static let startConversationAction = "开始复盘对话"
    static let sendReplyAction = "发送"
    static let finishConversationAction = "结束复盘"
    static let historyAction = "查看历史总结"
    static let askingText = "AI 正在准备问题…"
    static let summarizingText = "AI 正在整理总结…"
    static let helperText = "先基于当前范围内的日程和统计发起提问，再在对话结束后生成总结。"
    static let inputPlaceholder = "补充这个日程具体做了什么"
    static let findingsTitle = "主要发现"
    static let suggestionsTitle = "改进建议"
    static let historyEmptyText = "还没有历史总结。"
}

struct OverviewAIAnalysisSection: View {
    @Bindable var model: AppModel
    @State private var replyDraft = ""
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

                case .idle:
                    Text(AIAnalysisCopy.helperText)
                        .foregroundStyle(.secondary)

                    Button(AIAnalysisCopy.startConversationAction) {
                        Task { await model.startAIConversation() }
                    }
                    .buttonStyle(.borderedProminent)

                case .asking:
                    ProgressView(AIAnalysisCopy.askingText)

                case .waitingForUser(let session):
                    conversationContent(session: session)

                case .summarizing(let session):
                    conversationMessages(session.messages)
                    ProgressView(AIAnalysisCopy.summarizingText)

                case .completed(let summary):
                    summaryContent(summary)

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button(AIAnalysisCopy.startConversationAction) {
                        Task { await model.startAIConversation() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showsHistory) {
            AIConversationHistoryView(summaries: model.aiConversationHistory)
        }
    }

    @ViewBuilder
    private func conversationContent(session: AIConversationSession) -> some View {
        conversationMessages(session.messages)

        TextField(AIAnalysisCopy.inputPlaceholder, text: $replyDraft, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3, reservesSpace: false)

        HStack {
            Button(AIAnalysisCopy.sendReplyAction) {
                let reply = replyDraft
                replyDraft = ""
                Task { await model.sendAIConversationReply(reply) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button(AIAnalysisCopy.finishConversationAction) {
                replyDraft = ""
                Task { await model.finishAIConversation() }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func summaryContent(_ summary: AIConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.headline)
                .font(.title3.weight(.semibold))

            Text(summary.summary)
                .foregroundStyle(.secondary)

            if !summary.findings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AIAnalysisCopy.findingsTitle)
                        .font(.subheadline.weight(.semibold))
                    ForEach(summary.findings, id: \.self) { item in
                        Text("• \(item)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !summary.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AIAnalysisCopy.suggestionsTitle)
                        .font(.subheadline.weight(.semibold))
                    ForEach(summary.suggestions, id: \.self) { item in
                        Text("• \(item)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        Button(AIAnalysisCopy.startConversationAction) {
            Task { await model.startAIConversation() }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func conversationMessages(_ messages: [AIConversationMessage]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(messages, id: \.id) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.role == .assistant ? "AI" : "你")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(message.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(message.role == .assistant ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

private struct AIConversationHistoryView: View {
    let summaries: [AIConversationSummary]

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    Text(AIAnalysisCopy.historyEmptyText)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(summaries, id: \.id) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summary.headline)
                                .font(.headline)
                            Text(summary.range.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(summary.summary)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(AIAnalysisCopy.historyAction)
            .frame(minWidth: 480, minHeight: 360)
        }
    }
}
