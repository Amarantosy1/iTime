import SwiftUI
import MarkdownUI

struct iOSConversationView: View {
    @Bindable var model: AppModel
    @State private var customModelInput = ""
    @State private var showsConversationSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    rangeSection
                    modelSelectionSection
                    entrySection
                }
                .padding(.vertical, 10)
            }
            .navigationTitle("AI 复盘")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: iOSConversationHistoryView(model: model)) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("开始新复盘") {
                        startConversationAndOpen()
                    }
                    .disabled(!canStart)
                }
            }
            .fullScreenCover(isPresented: $showsConversationSession) {
                iOSConversationSessionView(model: model)
            }
            .onAppear {
                customModelInput = model.selectedConversationModel
            }
            .onChange(of: model.selectedConversationModel) { _, newValue in
                customModelInput = newValue
            }
        }
    }

    private var entrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("对话入口")
                .font(.footnote)
                .foregroundStyle(.secondary)

            stateCard(
                title: entryCardTitle,
                message: "\(selectedServiceDisplayName) · \(selectedModelDisplayText)",
                color: .secondary
            )

            HStack(spacing: 10) {
                Button(model.hasActiveAIConversation ? "继续对话" : "进入对话") {
                    if model.hasActiveAIConversation {
                        showsConversationSession = true
                    } else {
                        startConversationAndOpen()
                    }
                }
                .buttonStyle(.borderedProminent)

                if model.hasActiveAIConversation {
                    Button("退出不保存", role: .destructive) {
                        model.discardCurrentAIConversation()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal)
    }

    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("模型选择")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI 服务")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker(
                        "AI 服务",
                        selection: Binding(
                            get: { selectedServiceIDBinding },
                            set: { id in
                                model.selectConversationService(id: id)
                            }
                        )
                    ) {
                        ForEach(model.availableAIServices) { service in
                            HStack {
                                Text(service.displayName)
                                if !service.isEnabled {
                                    Text("(未启用)")
                                }
                            }
                            .tag(service.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("模型")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let selectedService {
                        if selectedService.models.isEmpty {
                            TextField("输入模型名", text: $customModelInput)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onSubmit {
                                    let trimmed = customModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        model.selectConversationModel(trimmed)
                                    }
                                }
                        } else {
                            Picker(
                                "模型",
                                selection: Binding(
                                    get: { model.selectedConversationModel },
                                    set: { model.selectConversationModel($0) }
                                )
                            ) {
                                ForEach(selectedService.models, id: \.self) { item in
                                    Text(item)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .tag(item)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    } else {
                        Text("暂无服务")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("复盘范围")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Picker(
                "复盘范围",
                selection: Binding(
                    get: { model.liveSelectedRange },
                    set: { range in
                        Task { await model.setRange(range) }
                    }
                )
            ) {
                ForEach(TimeRangePreset.overviewCases, id: \.self) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .disabled(!model.canAdjustConversationRange)

            if model.liveSelectedRange == .custom {
                customDateRangeControls
            }
        }
    }

    @ViewBuilder
    private var customDateRangeControls: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CustomDateRangePreset.allCases, id: \.self) { preset in
                    Button(preset.title) {
                        Task { await model.setCustomDateRange(preset: preset) }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.canAdjustConversationRange)
                }
            }
            .padding(.horizontal)
        }

        DatePicker(
            "开始日期",
            selection: Binding(
                get: { model.preferences.customStartDate },
                set: { start in
                    Task {
                        await model.setCustomDateRange(
                            start: start,
                            end: model.preferences.customEndDate
                        )
                    }
                }
            ),
            displayedComponents: .date
        )
        .padding(.horizontal)
        .disabled(!model.canAdjustConversationRange)

        DatePicker(
            "结束日期",
            selection: Binding(
                get: { model.preferences.customEndDate },
                set: { end in
                    Task {
                        await model.setCustomDateRange(
                            start: model.preferences.customStartDate,
                            end: end
                        )
                    }
                }
            ),
            displayedComponents: .date
        )
        .padding(.horizontal)
        .disabled(!model.canAdjustConversationRange)
    }

    private var canStart: Bool {
        switch model.aiConversationState {
        case .idle, .completed, .failed, .unavailable:
            return true
        case .asking, .responding, .waitingForUser, .summarizing:
            return false
        }
    }

    private var entryCardTitle: String {
        switch model.aiConversationState {
        case .idle:
            return "准备开始"
        case .completed:
            return "上次复盘已完成"
        case .failed:
            return "上次复盘失败"
        case .unavailable:
            return "服务暂不可用"
        case .asking, .responding, .waitingForUser, .summarizing:
            return "有一轮复盘进行中"
        }
    }

    private var selectedServiceIDBinding: UUID {
        if let selectedID = model.selectedConversationServiceID {
            return selectedID
        }
        return model.availableAIServices.first?.id ?? AIProviderKind.openAI.builtInServiceID
    }

    private var selectedService: AIServiceEndpoint? {
        model.availableAIServices.first(where: { $0.id == selectedServiceIDBinding })
    }

    private var selectedServiceDisplayName: String {
        selectedService?.displayName ?? "AI 服务"
    }

    private var selectedModelDisplayText: String {
        let modelName = model.selectedConversationModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return modelName.isEmpty ? "未选择模型" : modelName
    }

    private func startConversationAndOpen() {
        Task {
            await model.startAIConversation()
            await MainActor.run {
                showsConversationSession = model.hasActiveAIConversation
            }
        }
    }


    @ViewBuilder
    private func completedCard(_ summary: AIConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("复盘完成", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text(summary.headline)
                .font(.headline)

            Text(summary.summary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.08))
        )
    }

    @ViewBuilder
    private func stateCard(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func messageBubble(_ message: AIConversationMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                messageAvatar(systemImage: "sparkles", tint: .indigo)
            } else {
                Spacer(minLength: 28)
            }

            VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 4) {
                Text(message.role.displayTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .assistant ? Color.primary : Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                message.role == .assistant
                                    ? Color(uiColor: .secondarySystemBackground)
                                    : Color.accentColor
                            )
                    )

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)

            if message.role == .user {
                messageAvatar(systemImage: "person.fill", tint: .teal)
            } else {
                Spacer(minLength: 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
    }

    private func messageAvatar(systemImage: String, tint: Color) -> some View {
        Circle()
            .fill(tint.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            )
    }
}

struct iOSConversationSessionView: View {
    @Bindable var model: AppModel
    @State private var reply = ""
    @State private var showsDiscardConfirmation = false
    @State private var lastAutoScrolledAssistantMessageID: UUID?

    @Environment(\.dismiss) private var dismiss

    private let chatBottomID = "chat-bottom-anchor"

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            switch model.aiConversationState {
                            case .waitingForUser(let session), .responding(let session), .summarizing(let session):
                                conversationStatusRow

                                ForEach(session.messages, id: \.id) { item in
                                    messageBubble(item)
                                        .id(item.id)
                                }

                                if case .responding = model.aiConversationState {
                                    ProgressView("AI 正在继续追问…")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                } else if case .summarizing = model.aiConversationState {
                                    ProgressView("AI 正在整理总结…")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                            case .completed(let summary):
                                completedCard(summary)
                            case .failed(let message):
                                stateCard(title: "请求失败", message: message, color: .red)
                            case .unavailable(let availability):
                                stateCard(title: "暂不可用", message: availability.message, color: .secondary)
                            case .idle:
                                stateCard(title: "还未开始", message: "请返回上一页点击“开始新复盘”", color: .secondary)
                            case .asking:
                                ProgressView("AI 正在准备问题…")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(chatBottomID)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: lastAssistantMessageID) { _, newID in
                        guard let newID, newID != lastAutoScrolledAssistantMessageID else { return }
                        lastAutoScrolledAssistantMessageID = newID
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(chatBottomID, anchor: .bottom)
                        }
                    }
                    .onChange(of: currentMessageCount) { oldCount, newCount in
                        guard newCount > oldCount, lastAssistantMessageID == nil else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(chatBottomID, anchor: .bottom)
                        }
                    }
                }

                if canReply {
                    HStack(spacing: 8) {
                        TextField("补充这个日程具体做了什么", text: $reply, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)

                        Button("发送") {
                            let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            Task {
                                let outgoing = trimmed
                                reply = ""
                                await model.sendAIConversationReply(outgoing)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSending)
                    }
                    .padding(.horizontal)

                    Button("结束复盘") {
                        Task { await model.finishAIConversation() }
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("复盘对话")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if model.hasActiveAIConversation {
                        Button("退出不保存") {
                            showsDiscardConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert("放弃这轮复盘？", isPresented: $showsDiscardConfirmation) {
                Button("退出", role: .destructive) {
                    model.discardCurrentAIConversation()
                    reply = ""
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后不会生成报告，这一轮未完成对话也不会进入历史。")
            }
        }
    }

    private var conversationStatusRow: some View {
        HStack(spacing: 8) {
            Label("\(selectedServiceDisplayName) · \(selectedModelDisplayText)", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Label("共 \(currentMessageCount) 条", systemImage: "text.bubble")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, 4)
    }

    private var canReply: Bool {
        switch model.aiConversationState {
        case .waitingForUser, .responding:
            return true
        default:
            return false
        }
    }

    private var isSending: Bool {
        if case .responding = model.aiConversationState {
            return true
        }
        return false
    }

    private var selectedService: AIServiceEndpoint? {
        let selectedID = model.selectedConversationServiceID
        return model.availableAIServices.first(where: { $0.id == selectedID })
    }

    private var selectedServiceDisplayName: String {
        selectedService?.displayName ?? "AI 服务"
    }

    private var selectedModelDisplayText: String {
        let modelName = model.selectedConversationModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return modelName.isEmpty ? "未选择模型" : modelName
    }

    private var currentMessageCount: Int {
        model.currentConversationSession?.messages.count ?? 0
    }

    private var lastAssistantMessageID: UUID? {
        model.currentConversationSession?.messages.last(where: { $0.role == .assistant })?.id
    }

    @ViewBuilder
    private func completedCard(_ summary: AIConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("复盘完成", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text(summary.headline)
                .font(.headline)

            Text(summary.summary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.08))
        )
    }

    @ViewBuilder
    private func stateCard(title: String, message: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private func messageBubble(_ message: AIConversationMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                messageAvatar(systemImage: "sparkles", tint: .indigo)
            } else {
                Spacer(minLength: 28)
            }

            VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 4) {
                Text(message.role.displayTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .assistant ? Color.primary : Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                message.role == .assistant
                                    ? Color(uiColor: .secondarySystemBackground)
                                    : Color.accentColor
                            )
                    )

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)

            if message.role == .user {
                messageAvatar(systemImage: "person.fill", tint: .teal)
            } else {
                Spacer(minLength: 28)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .assistant ? .leading : .trailing)
    }

    private func messageAvatar(systemImage: String, tint: Color) -> some View {
        Circle()
            .fill(tint.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            )
    }
}

private extension AIConversationMessageRole {
    var displayTitle: String {
        switch self {
        case .assistant:
            return "AI"
        case .user:
            return "我"
        }
    }
}

private enum iOSConversationLongFormCopy {
    static let sectionTitle = "流水账复盘"
    static let placeholder = "这条历史总结还没有生成流水账复盘。"
    static let generateAction = "生成流水账复盘"
    static let regenerateAction = "重新生成流水账"
    static let generatingText = "AI 正在撰写流水账复盘…"
}

struct iOSConversationHistoryView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.aiConversationHistory.isEmpty {
                Text("还没有历史总结。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(TimeRangePreset.allCases, id: \.self) { range in
                        let summaries = model.aiConversationHistory.filter { $0.dynamicRangeCategory == range }
                        if !summaries.isEmpty {
                            Section(header: Text(range.historyCategoryTitle)) {
                                ForEach(summaries, id: \.id) { summary in
                                    NavigationLink(destination: iOSConversationSummaryDetailView(model: model, summaryID: summary.id)) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(summary.headline)
                                                .font(.headline)
                                                .lineLimit(2)

                                            Text(summary.displayPeriodText)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete { offsets in
                                    deleteItems(in: summaries, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("复盘历史")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteItems(in summaries: [AIConversationSummary], at offsets: IndexSet) {
        for index in offsets {
            let summary = summaries[index]
            model.deleteAIConversationSummary(id: summary.id)
        }
    }
}

struct iOSConversationSummaryDetailView: View {
    @Bindable var model: AppModel
    let summaryID: UUID

    @State private var isEditing = false
    @State private var headlineDraft = ""
    @State private var summaryDraft = ""
    @State private var findingsDraft = ""
    @State private var suggestionsDraft = ""
    @State private var pendingDeletion = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let summary = model.aiConversationHistory.first(where: { $0.id == summaryID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            if isEditing {
                                TextField("标题", text: $headlineDraft)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.title2.weight(.semibold))
                            } else {
                                Text(summary.headline)
                                    .font(.title2.weight(.semibold))
                            }

                            Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        editorOrText(text: $summaryDraft, readOnlyText: summary.summary, isEditing: isEditing, title: "总结")
                        detailSection(title: "发现", items: summary.findings, draftText: $findingsDraft, isEditing: isEditing)
                        detailSection(title: "建议", items: summary.suggestions, draftText: $suggestionsDraft, isEditing: isEditing)
                        longFormSection(summaryID: summary.id)
                    }
                    .padding()
                }
                .navigationTitle(isEditing ? "编辑复盘" : "复盘详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !isEditing {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(
                                item: shareContent(for: summary),
                                subject: Text(summary.headline)
                            ) {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        if isEditing {
                            Button("保存") {
                                model.updateAIConversationSummary(
                                    id: summary.id,
                                    headline: headlineDraft,
                                    summary: summaryDraft,
                                    findings: parseLines(from: findingsDraft),
                                    suggestions: parseLines(from: suggestionsDraft)
                                )
                                isEditing = false
                            }
                        } else {
                            Menu {
                                Button("编辑", systemImage: "pencil") {
                                    headlineDraft = summary.headline
                                    summaryDraft = summary.summary
                                    findingsDraft = summary.findings.joined(separator: "\n")
                                    suggestionsDraft = summary.suggestions.joined(separator: "\n")
                                    isEditing = true
                                }
                                Button("删除", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }

                    if isEditing {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") {
                                isEditing = false
                            }
                        }
                    }
                }
                .alert("删除这条历史总结？", isPresented: $pendingDeletion) {
                    Button("删除", role: .destructive) {
                        model.deleteAIConversationSummary(id: summary.id)
                        dismiss()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("删除后会同时移除关联会话记录和依赖它的 memory。")
                }
            } else {
                Text("内容不存在或已被删除")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func editorOrText(text: Binding<String>, readOnlyText: String, isEditing: Bool, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if isEditing {
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            } else {
                Text(readOnlyText)
            }
        }
    }

    @ViewBuilder
    private func detailSection(title: String, items: [String], draftText: Binding<String>, isEditing: Bool) -> some View {
        if !items.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                if isEditing {
                    TextEditor(text: draftText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func parseLines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func shareContent(for summary: AIConversationSummary) -> String {
        var lines: [String] = [
            summary.headline,
            "",
            "服务：\(summary.serviceDisplayName)",
            "时间范围：\(summary.displayPeriodText)",
            "",
            "总结",
            summary.summary
        ]

        if !summary.findings.isEmpty {
            lines.append("")
            lines.append("主要发现")
            lines.append(contentsOf: summary.findings.map { "- \($0)" })
        }

        if !summary.suggestions.isEmpty {
            lines.append("")
            lines.append("改进建议")
            lines.append(contentsOf: summary.suggestions.map { "- \($0)" })
        }

        if let report = model.longFormReport(for: summary.id) {
            lines.append("")
            lines.append("流水账复盘")
            lines.append(report.title)
            lines.append("")
            lines.append(report.content)
        }

        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func longFormSection(summaryID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(iOSConversationLongFormCopy.sectionTitle)
                    .font(.headline)
                Spacer()

                if model.longFormReport(for: summaryID) != nil {
                    Button(iOSConversationLongFormCopy.regenerateAction) {
                        Task { await model.generateLongFormReport(for: summaryID) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(iOSConversationLongFormCopy.generateAction) {
                        Task { await model.generateLongFormReport(for: summaryID) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let report = model.longFormReport(for: summaryID) {
                Text(report.title)
                    .font(.subheadline.weight(.semibold))
                Markdown(report.content)

                if let flowchart = report.flowchart {
                    let calendarColorHexByName = Dictionary(uniqueKeysWithValues: model.availableCalendars.map { ($0.name, $0.colorHex) })

                    Text("当日流程图")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)

                    FlowchartView(flowchart: flowchart, calendarColorHexByName: calendarColorHexByName)
                        .frame(minHeight: 180)
                }
            } else {
                Text(iOSConversationLongFormCopy.placeholder)
                    .foregroundStyle(.secondary)
            }

            switch model.aiLongFormState {
            case .generating(let currentSummaryID) where currentSummaryID == summaryID:
                ProgressView(iOSConversationLongFormCopy.generatingText)
            case .failed(let currentSummaryID, let message) where currentSummaryID == summaryID:
                Text(message)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
    }
}
