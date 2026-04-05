import SwiftUI

struct iOSConversationView: View {
    @Bindable var model: AppModel
    @State private var reply = ""
    @State private var showsDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                rangeSection

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        switch model.aiConversationState {
                        case .waitingForUser(let session), .responding(let session), .summarizing(let session):
                            ForEach(session.messages, id: \.id) { item in
                                messageBubble(item)
                            }
                            if case .responding = model.aiConversationState {
                                ProgressView("AI 正在继续追问…")
                            } else if case .summarizing = model.aiConversationState {
                                ProgressView("AI 正在整理总结…")
                            }
                        case .completed(let summary):
                            Text(summary.headline)
                                .font(.headline)
                            Text(summary.summary)
                                .foregroundStyle(.secondary)
                        case .failed(let message):
                            Text(message)
                                .foregroundStyle(.red)
                        case .unavailable(let availability):
                            Text(availability.message)
                                .foregroundStyle(.secondary)
                        case .idle:
                            Text("点击右上角“开始新复盘”")
                                .foregroundStyle(.secondary)
                        case .asking:
                            ProgressView("AI 正在准备问题…")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
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
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("AI 复盘")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 10) {
                        if model.hasActiveAIConversation {
                            Button("退出不保存") {
                                showsDiscardConfirmation = true
                            }
                            .foregroundStyle(.red)
                        }

                        NavigationLink(destination: iOSConversationHistoryView(model: model)) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("开始新复盘") {
                        Task { await model.startAIConversation() }
                    }
                    .disabled(!canStart)
                }
            }
            .alert("放弃这轮复盘？", isPresented: $showsDiscardConfirmation) {
                Button("退出", role: .destructive) {
                    model.discardCurrentAIConversation()
                    reply = ""
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("退出后不会生成报告，这一轮未完成对话也不会进入历史。")
            }
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

    @ViewBuilder
    private func messageBubble(_ message: AIConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.role.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(message.content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(message.role == .assistant ? Color.secondary.opacity(0.12) : Color.accentColor.opacity(0.12))
                )
        }
    }
}

private extension AIConversationMessageRole {
    var displayTitle: String {
        switch self {
        case .assistant:
            return "AI"
        case .user:
            return "你"
        }
    }
}



struct iOSConversationHistoryView: View {
    @Bindable var model: AppModel
    
    var body: some View {
        Group {
            if model.aiConversationHistory.isEmpty {
                Text("还没有历史总结。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(model.aiConversationHistory, id: \.id) { summary in
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
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("复盘历史")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let summary = model.aiConversationHistory[index]
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
    @State private var isEditingLongForm = false
    @State private var longFormTitleDraft = ""
    @State private var longFormContentDraft = ""
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
                        
                        detailSection(title: "主要发现", items: summary.findings, draftText: $findingsDraft, isEditing: isEditing)
                        
                        detailSection(title: "改进建议", items: summary.suggestions, draftText: $suggestionsDraft, isEditing: isEditing)

                        longFormSection(summary: summary)
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
                                    synchronizeDrafts(from: summary)
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
                                synchronizeDrafts(from: summary)
                                isEditing = false
                            }
                        }
                    }
                }
                .onAppear {
                    synchronizeDrafts(from: summary)
                }
                .onChange(of: summary.id) { _, _ in
                    isEditing = false
                    isEditingLongForm = false
                    synchronizeDrafts(from: summary)
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
            Text(title).font(.headline)
            if isEditing {
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            } else {
                Text(LocalizedStringKey(readOnlyText))
            }
        }
    }
    
    @ViewBuilder
    private func detailSection(title: String, items: [String], draftText: Binding<String>, isEditing: Bool) -> some View {
        if !items.isEmpty || isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                
                if isEditing {
                    TextEditor(text: draftText)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { item in
                            HStack(alignment: .top) {
                                Text("•")
                                Text(LocalizedStringKey(item))
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

    private func synchronizeDrafts(from summary: AIConversationSummary) {
        headlineDraft = summary.headline
        summaryDraft = summary.summary
        findingsDraft = summary.findings.joined(separator: "\n")
        suggestionsDraft = summary.suggestions.joined(separator: "\n")

        if let report = model.longFormReport(for: summary.id) {
            longFormTitleDraft = report.title
            longFormContentDraft = report.content
        } else {
            longFormTitleDraft = ""
            longFormContentDraft = ""
        }
    }

    @ViewBuilder
    private func longFormSection(summary: AIConversationSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("长文复盘")
                    .font(.headline)
                Spacer()

                if let report = model.longFormReport(for: summary.id) {
                    if isEditingLongForm {
                        Button("取消") {
                            synchronizeDrafts(from: summary)
                            isEditingLongForm = false
                        }

                        Button("保存长文") {
                            model.updateLongFormReport(
                                id: report.id,
                                title: longFormTitleDraft,
                                content: longFormContentDraft
                            )
                            isEditingLongForm = false
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("编辑长文") {
                            synchronizeDrafts(from: summary)
                            isEditingLongForm = true
                        }
                    }

                    Button("重新生成长文") {
                        Task { await model.generateLongFormReport(for: summary.id) }
                    }
                } else {
                    Button("生成长文复盘") {
                        Task { await model.generateLongFormReport(for: summary.id) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let report = model.longFormReport(for: summary.id) {
                if isEditingLongForm {
                    TextField("长文标题", text: $longFormTitleDraft)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $longFormContentDraft)
                        .frame(minHeight: 220)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                } else {
                    Text(report.title)
                        .font(.title3.weight(.semibold))
                    Text(LocalizedStringKey(report.content))
                }
            } else {
                Text("这条历史总结还没有生成长文复盘。")
                    .foregroundStyle(.secondary)
            }

            switch model.aiLongFormState {
            case .generating(let generatingSummaryID) where generatingSummaryID == summary.id:
                ProgressView("AI 正在撰写长文复盘…")
            case .failed(let failedSummaryID, let message) where failedSummaryID == summary.id:
                Text(message)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
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
            lines.append("长文复盘")
            lines.append(report.title)
            lines.append("")
            lines.append(report.content)
        }

        return lines.joined(separator: "\n")
    }
}
