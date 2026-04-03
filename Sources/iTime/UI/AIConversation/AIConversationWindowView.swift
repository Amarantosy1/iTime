import SwiftUI

enum AIConversationWindowCopy {
    static let title = "AI 复盘"
    static let helperText = "AI 会先基于当前范围内的统计和具体日程发起提问，再在结束时生成总结。"
    static let askingText = "AI 正在准备问题…"
    static let respondingText = "AI 正在继续追问…"
    static let summarizingText = "AI 正在整理总结…"
    static let unavailableNoDataText = "当前范围内没有可供复盘的统计数据。"
    static let newConversationAction = "开始新复盘"
    static let historyAction = "历史总结"
    static let sendReplyAction = "发送"
    static let finishConversationAction = "结束复盘"
    static let inputPlaceholder = "补充这个日程具体做了什么"
    static let composerHint = "Enter 发送，Shift+Enter 换行"
    static let findingsTitle = "主要发现"
    static let suggestionsTitle = "改进建议"
}

struct AIConversationWindowView: View {
    static let windowID = "aiConversation"

    @Bindable var model: AppModel
    @State private var replyDraft = ""
    @State private var showsHistory = false
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversationBody
            if showsComposer {
                Divider()
                AIConversationComposerView(
                    replyDraft: $replyDraft,
                    isFocused: $isComposerFocused,
                    isSending: isComposerSending,
                    statusText: composerStatusText,
                    onSend: sendReply,
                    onFinish: finishConversation
                )
            }
        }
        .navigationTitle(AIConversationWindowCopy.title)
        .frame(minWidth: 620, minHeight: 540)
        .sheet(isPresented: $showsHistory) {
            AIConversationHistoryView(summaries: model.aiConversationHistory)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AIConversationWindowCopy.title)
                    .font(.title2.weight(.semibold))
                Text("\(providerTitle) · \(periodTitle)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                if !model.aiConversationHistory.isEmpty {
                    Button(AIConversationWindowCopy.historyAction) {
                        showsHistory = true
                    }
                    .buttonStyle(.bordered)
                }

                if canStartNewConversation {
                    Button(AIConversationWindowCopy.newConversationAction) {
                        Task { await model.startAIConversation() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var conversationBody: some View {
        switch model.aiConversationState {
        case .unavailable(let availability):
            unavailableView(message: availability.message)

        case .idle:
            emptyStateView(text: AIConversationWindowCopy.helperText)

        case .asking:
            progressView(AIConversationWindowCopy.askingText)

        case .responding(let session):
            AIConversationMessagesView(messages: session.messages)

        case .waitingForUser(let session):
            AIConversationMessagesView(messages: session.messages)

        case .summarizing(let session):
            VStack(spacing: 0) {
                AIConversationMessagesView(messages: session.messages)
                Divider()
                progressView(AIConversationWindowCopy.summarizingText)
            }

        case .completed(let summary):
            summaryView(summary)

        case .failed(let message):
            unavailableView(message: message)
        }
    }

    private var canStartNewConversation: Bool {
        switch model.aiConversationState {
        case .idle, .completed, .failed:
            return true
        case .unavailable, .asking, .responding, .waitingForUser, .summarizing:
            return false
        }
    }

    private var showsComposer: Bool {
        switch model.aiConversationState {
        case .waitingForUser, .responding:
            return true
        default:
            return false
        }
    }

    private var providerTitle: String {
        switch model.aiConversationState {
        case .responding(let session), .waitingForUser(let session), .summarizing(let session):
            return session.provider.title
        case .completed(let summary):
            return summary.provider.title
        case .unavailable, .idle, .asking, .failed:
            return model.preferences.defaultAIProvider.title
        }
    }

    private var periodTitle: String {
        switch model.aiConversationState {
        case .responding(let session), .waitingForUser(let session), .summarizing(let session):
            return session.displayPeriodText
        case .completed(let summary):
            return summary.displayPeriodText
        case .unavailable, .idle, .asking, .failed:
            return model.liveSelectedRange.title
        }
    }

    private var isComposerSending: Bool {
        if case .responding = model.aiConversationState {
            return true
        }
        return false
    }

    private var composerStatusText: String? {
        if case .responding = model.aiConversationState {
            return AIConversationWindowCopy.respondingText
        }
        return nil
    }

    private func sendReply() {
        let reply = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return }
        replyDraft = ""
        Task { await model.sendAIConversationReply(reply) }
    }

    private func finishConversation() {
        replyDraft = ""
        Task { await model.finishAIConversation() }
    }

    private func emptyStateView(text: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text)
                .foregroundStyle(.secondary)

            Button(AIConversationWindowCopy.newConversationAction) {
                Task { await model.startAIConversation() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func unavailableView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(message)
                .foregroundStyle(.secondary)

            if case .unavailable(let availability) = model.aiConversationState, availability != .noData {
                SettingsLink {
                    Text("打开设置")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func progressView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView(text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func summaryView(_ summary: AIConversationSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(summary.headline)
                    .font(.title3.weight(.semibold))

                Text("\(summary.provider.title) · \(summary.displayPeriodText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(summary.summary)
                    .foregroundStyle(.secondary)

                if !summary.findings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AIConversationWindowCopy.findingsTitle)
                            .font(.subheadline.weight(.semibold))
                        ForEach(summary.findings, id: \.self) { finding in
                            Text("• \(finding)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !summary.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AIConversationWindowCopy.suggestionsTitle)
                            .font(.subheadline.weight(.semibold))
                        ForEach(summary.suggestions, id: \.self) { suggestion in
                            Text("• \(suggestion)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}
