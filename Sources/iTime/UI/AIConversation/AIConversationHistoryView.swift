import SwiftUI

enum AIConversationHistoryCopy {
    static let emptyText = "还没有历史总结。"
    static let deleteAction = "删除总结"
    static let deleteConfirmationTitle = "删除这条历史总结？"
    static let deleteConfirmationMessage = "删除后会同时移除关联会话记录和依赖它的 memory。"
    static let longFormPlaceholder = "这条历史总结还没有生成长文复盘。"
}

struct AIConversationHistoryView: View {
    @Bindable var model: AppModel
    @State private var selectedSummaryID: UUID?
    @State private var pendingDeletionSummaryID: UUID?

    var body: some View {
        NavigationSplitView {
            if model.aiConversationHistory.isEmpty {
                Text(AIConversationHistoryCopy.emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(selection: $selectedSummaryID) {
                    ForEach(model.aiConversationHistory, id: \.id) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summary.headline)
                                .font(.headline)
                                .lineLimit(2)

                            Text(summary.displayPeriodText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(summary.id)
                    }
                }
                .onAppear {
                    selectedSummaryID = selectedSummaryID ?? model.aiConversationHistory.first?.id
                }
            }
        } detail: {
            if let summary = selectedSummary {
                AIConversationSummaryDetailView(
                    model: model,
                    summary: summary,
                    onSave: { headline, summaryText, findings, suggestions in
                        model.updateAIConversationSummary(
                            id: summary.id,
                            headline: headline,
                            summary: summaryText,
                            findings: findings,
                            suggestions: suggestions
                        )
                    },
                    onDelete: { pendingDeletionSummaryID = summary.id }
                )
            } else {
                Text(AIConversationHistoryCopy.emptyText)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AIAnalysisCopy.historyAction)
        .frame(minWidth: 760, minHeight: 480)
        .alert(
            AIConversationHistoryCopy.deleteConfirmationTitle,
            isPresented: Binding(
                get: { pendingDeletionSummaryID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletionSummaryID = nil
                    }
                }
            )
        ) {
            Button("删除", role: .destructive) {
                guard let summaryID = pendingDeletionSummaryID else { return }
                deleteSummary(id: summaryID)
                pendingDeletionSummaryID = nil
            }
            Button("取消", role: .cancel) {
                pendingDeletionSummaryID = nil
            }
        } message: {
            Text(AIConversationHistoryCopy.deleteConfirmationMessage)
        }
    }

    private var selectedSummary: AIConversationSummary? {
        if let selectedSummaryID {
            return model.aiConversationHistory.first(where: { $0.id == selectedSummaryID })
        }
        return model.aiConversationHistory.first
    }

    private func deleteSummary(id: UUID) {
        model.deleteAIConversationSummary(id: id)
        selectedSummaryID = model.aiConversationHistory.first?.id
    }
}

private struct AIConversationSummaryDetailView: View {
    @Bindable var model: AppModel
    let summary: AIConversationSummary
    let onSave: (_ headline: String, _ summary: String, _ findings: [String], _ suggestions: [String]) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var headlineDraft = ""
    @State private var summaryDraft = ""
    @State private var findingsDraft = ""
    @State private var suggestionsDraft = ""
    @State private var isEditingLongForm = false
    @State private var longFormTitleDraft = ""
    @State private var longFormContentDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        if isEditing {
                            TextField("标题", text: $headlineDraft)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text(summary.headline)
                                .font(.title2.weight(.semibold))
                        }

                        Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        if isEditing {
                            Button("取消") {
                                synchronizeDrafts()
                                isEditing = false
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(isEditing ? AIConversationWindowCopy.saveEditsAction : AIConversationWindowCopy.editSummaryAction) {
                            if isEditing {
                                onSave(
                                    headlineDraft,
                                    summaryDraft,
                                    parseLines(from: findingsDraft),
                                    parseLines(from: suggestionsDraft)
                                )
                            }
                            isEditing.toggle()
                        }
                        .buttonStyle(.bordered)

                        Button(AIConversationHistoryCopy.deleteAction, role: .destructive, action: onDelete)
                    }
                }

                editorOrText(
                    text: $summaryDraft,
                    readOnlyText: summary.summary,
                    isEditing: isEditing
                )

                detailSection(
                    title: AIConversationWindowCopy.findingsTitle,
                    items: summary.findings,
                    draftText: $findingsDraft,
                    isEditing: isEditing
                )

                detailSection(
                    title: AIConversationWindowCopy.suggestionsTitle,
                    items: summary.suggestions,
                    draftText: $suggestionsDraft,
                    isEditing: isEditing
                )

                longFormSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .onAppear(perform: synchronizeDrafts)
        .onChange(of: summary.id) { _, _ in
            isEditing = false
            isEditingLongForm = false
            synchronizeDrafts()
        }
    }

    private func synchronizeDrafts() {
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
    private func editorOrText(
        text: Binding<String>,
        readOnlyText: String,
        isEditing: Bool
    ) -> some View {
        if isEditing {
            TextEditor(text: text)
                .frame(minHeight: 120)
                .padding(10)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Text(readOnlyText)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func detailSection(
        title: String,
        items: [String],
        draftText: Binding<String>,
        isEditing: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if isEditing {
                TextEditor(text: draftText)
                    .frame(minHeight: 110)
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if !items.isEmpty {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func parseLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private var longFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AIConversationWindowCopy.longFormTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()

                if let report = model.longFormReport(for: summary.id) {
                    if isEditingLongForm {
                        Button("取消") {
                            synchronizeDrafts()
                            isEditingLongForm = false
                        }
                        .buttonStyle(.bordered)

                        Button(AIConversationWindowCopy.longFormSaveAction) {
                            model.updateLongFormReport(
                                id: report.id,
                                title: longFormTitleDraft,
                                content: longFormContentDraft
                            )
                            isEditingLongForm = false
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(AIConversationWindowCopy.editSummaryAction) {
                            isEditingLongForm = true
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(AIConversationWindowCopy.regenerateLongFormAction) {
                        Task { await model.generateLongFormReport(for: summary.id) }
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(AIConversationWindowCopy.generateLongFormAction) {
                        Task { await model.generateLongFormReport(for: summary.id) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let report = model.longFormReport(for: summary.id) {
                if isEditingLongForm {
                    TextField("长文标题", text: $longFormTitleDraft)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $longFormContentDraft)
                        .frame(minHeight: 220)
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(report.title)
                        .font(.headline)

                    Text(report.content)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(AIConversationHistoryCopy.longFormPlaceholder)
                    .foregroundStyle(.secondary)
            }

            switch model.aiLongFormState {
            case .generating(let summaryID) where summaryID == summary.id:
                ProgressView(AIConversationWindowCopy.longFormGeneratingText)
            case .failed(let summaryID, let message) where summaryID == summary.id:
                Text(message)
                    .foregroundStyle(.red)
            default:
                EmptyView()
            }
        }
    }
}
