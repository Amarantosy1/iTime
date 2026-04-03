import SwiftUI

enum AIConversationWindowCopy {
    static let title = "AI 复盘"
    static let askingText = "AI 正在准备问题…"
    static let respondingText = "AI 正在继续追问…"
    static let summarizingText = "AI 正在整理总结…"
    static let unavailableNoDataText = "当前范围内没有可供复盘的统计数据。"
    static let newConversationAction = "开始新复盘"
    static let historyAction = "历史总结"
    static let sendReplyAction = "发送"
    static let finishConversationAction = "结束复盘"
    static let inputPlaceholder = "补充这个日程具体做了什么"
    static let findingsTitle = "主要发现"
    static let suggestionsTitle = "改进建议"
    static let serviceSelectionTitle = "服务"
    static let modelSelectionTitle = "模型"
    static let missingModelText = "请先在设置里补充模型列表。"
    static let discardConversationAccessibilityLabel = "退出本轮复盘"
    static let discardConfirmationTitle = "放弃这轮复盘？"
    static let discardConfirmationMessage = "退出后不会生成报告，这一轮未完成对话也不会进入历史。"
    static let editSummaryAction = "编辑总结"
    static let saveEditsAction = "保存修改"
    static let longFormTitle = "长文复盘"
    static let generateLongFormAction = "生成长文复盘"
    static let regenerateLongFormAction = "重新生成长文"
    static let longFormGeneratingText = "AI 正在撰写长文复盘…"
    static let longFormSaveAction = "保存长文"
}

struct AIConversationWindowView: View {
    static let windowID = "aiConversation"

    @Bindable var model: AppModel
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var replyDraft = ""
    @State private var showsHistory = false
    @State private var showsDiscardConfirmation = false
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showsPreflightOptions {
                preflightOptionsView
                Divider()
            }
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
        .frame(minWidth: 720, minHeight: 560)
        .sheet(isPresented: $showsHistory) {
            AIConversationHistoryView(model: model)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: closeOrDiscardConversation) {
                    Image(systemName: "chevron.left")
                }
                .help(AIConversationWindowCopy.discardConversationAccessibilityLabel)
            }
        }
        .alert(AIConversationWindowCopy.discardConfirmationTitle, isPresented: $showsDiscardConfirmation) {
            Button("退出", role: .destructive) {
                model.discardCurrentAIConversation()
                dismissWindow(id: Self.windowID)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(AIConversationWindowCopy.discardConfirmationMessage)
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
                    .disabled(!canStartConversationNow)
                }
            }
        }
        .padding(20)
    }

    private var preflightOptionsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AIConversationWindowCopy.serviceSelectionTitle)
                        .font(.subheadline.weight(.semibold))

                    Picker(
                        AIConversationWindowCopy.serviceSelectionTitle,
                        selection: Binding(
                            get: { model.selectedConversationServiceID ?? UUID() },
                            set: { model.selectConversationService(id: $0) }
                        )
                    ) {
                        ForEach(model.availableAIServices) { service in
                            Text(service.displayName).tag(service.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AIConversationWindowCopy.modelSelectionTitle)
                        .font(.subheadline.weight(.semibold))

                    if selectedServiceModels.isEmpty {
                        Text(AIConversationWindowCopy.missingModelText)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker(
                            AIConversationWindowCopy.modelSelectionTitle,
                            selection: Binding(
                                get: { model.selectedConversationModel },
                                set: { model.selectConversationModel($0) }
                            )
                        ) {
                            ForEach(selectedServiceModels, id: \.self) { modelName in
                                Text(modelName).tag(modelName)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.06))
    }

    @ViewBuilder
    private var conversationBody: some View {
        switch model.aiConversationState {
        case .unavailable(let availability):
            unavailableView(message: availability.message)

        case .idle:
            emptyStateView()

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
        case .idle, .completed, .failed, .unavailable:
            return true
        case .asking, .responding, .waitingForUser, .summarizing:
            return false
        }
    }

    private var showsPreflightOptions: Bool {
        canStartNewConversation
    }

    private var showsComposer: Bool {
        switch model.aiConversationState {
        case .waitingForUser, .responding:
            return true
        default:
            return false
        }
    }

    private var selectedService: AIServiceEndpoint? {
        guard let selectedID = model.selectedConversationServiceID else { return nil }
        return model.availableAIServices.first(where: { $0.id == selectedID })
    }

    private var selectedServiceModels: [String] {
        guard let selectedService else { return [] }
        var models: [String] = []
        if !selectedService.defaultModel.isEmpty {
            models.append(selectedService.defaultModel)
        }
        models.append(contentsOf: selectedService.models)
        return Array(NSOrderedSet(array: models)) as? [String] ?? models
    }

    private var canStartConversationNow: Bool {
        guard let selectedService else { return false }
        return selectedService.isEnabled && !model.selectedConversationModel.isEmpty
    }

    private var providerTitle: String {
        switch model.aiConversationState {
        case .responding(let session), .waitingForUser(let session), .summarizing(let session):
            return session.serviceDisplayName
        case .completed(let summary):
            return summary.serviceDisplayName
        case .unavailable, .idle, .asking, .failed:
            return selectedService?.displayName ?? "未选择服务"
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

    private func closeOrDiscardConversation() {
        switch model.aiConversationState {
        case .asking, .responding, .waitingForUser, .summarizing:
            showsDiscardConfirmation = true
        case .unavailable, .idle, .completed, .failed:
            dismissWindow(id: Self.windowID)
        }
    }

    private func emptyStateView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !canStartConversationNow {
                Text(AIConversationWindowCopy.missingModelText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

                Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
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

                longFormSection(summaryID: summary.id)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    @ViewBuilder
    private func longFormSection(summaryID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AIConversationWindowCopy.longFormTitle)
                .font(.subheadline.weight(.semibold))

            if let report = model.longFormReport(for: summaryID) {
                Text(report.title)
                    .font(.headline)

                ScrollView {
                    Text(report.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 180, maxHeight: 280)

                Button(AIConversationWindowCopy.regenerateLongFormAction) {
                    Task { await model.generateLongFormReport(for: summaryID) }
                }
                .buttonStyle(.bordered)
            } else {
                Button(AIConversationWindowCopy.generateLongFormAction) {
                    Task { await model.generateLongFormReport(for: summaryID) }
                }
                .buttonStyle(.bordered)
            }

            switch model.aiLongFormState {
            case .generating(let currentSummaryID) where currentSummaryID == summaryID:
                ProgressView(AIConversationWindowCopy.longFormGeneratingText)
            case .failed(let currentSummaryID, let message) where currentSummaryID == summaryID:
                Text(message)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
    }
}
