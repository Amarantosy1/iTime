import UniformTypeIdentifiers

import SwiftUI
import MarkdownUI

enum AIConversationHistoryCopy {
    static let emptyText = "还没有历史总结。"
    static let deleteAction = "删除总结"
    static let deleteConfirmationTitle = "删除这条历史总结？"
    static let deleteConfirmationMessage = "删除后会同时移除关联会话记录和依赖它的 memory。"
    static let longFormPlaceholder = "这条历史总结还没有生成流水账复盘。"
}

struct AIConversationHistoryView: View {
    @Bindable var model: AppModel
    @State private var selectedSummaryIDs: Set<UUID> = []
    @State private var pendingDeletionSummaryIDs: Set<UUID> = []
    @State private var isExporting: Bool = false

    private var exportContentType: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }

    var body: some View {
        NavigationSplitView {
            if model.aiConversationHistory.isEmpty {
                Text(AIConversationHistoryCopy.emptyText)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(selection: $selectedSummaryIDs) {
                    ForEach(model.aiConversationHistory, id: \.id) { summary in
                        HistorySummaryRow(summary: summary)
                            .tag(summary.id as UUID)
                    }
                }
                .onAppear {
                    if selectedSummaryIDs.isEmpty, let firstID = model.aiConversationHistory.first?.id {
                        selectedSummaryIDs = [firstID]
                    }
                }
            }
        } detail: {
            if selectedSummaryIDs.count > 1 {
                VStack(spacing: 20) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("已选择 \(selectedSummaryIDs.count) 项记录")
                        .font(.title2)
                    
                    HStack(spacing: 16) {
                        Button {
                            isExporting = true
                        } label: {
                            Label("导出所选 (.md)", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        .fileExporter(
                            isPresented: $isExporting,
                            document: HistoryMarkdownExportDocument(content: exportMarkdown(for: selectedSummaryIDs)),
                            contentType: exportContentType,
                            defaultFilename: "iTime-复盘导出"
                        ) { result in
                            // Handle export result if needed
                        }
                        
                        Button(role: .destructive) {
                            pendingDeletionSummaryIDs = selectedSummaryIDs
                        } label: {
                            Label("删除所选", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let summary = selectedSummary {
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
                    onDelete: { pendingDeletionSummaryIDs = [summary.id] }
                )
            } else {
                Text(AIConversationHistoryCopy.emptyText)
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !model.aiConversationHistory.isEmpty {
                    Button {
                        if selectedSummaryIDs.count == model.aiConversationHistory.count {
                            selectedSummaryIDs.removeAll()
                        } else {
                            selectedSummaryIDs = Set(model.aiConversationHistory.map(\.id))
                        }
                    } label: {
                        Text(selectedSummaryIDs.count == model.aiConversationHistory.count ? "取消全选" : "全选")
                    }
                }
            }
        }
        .navigationTitle(AIAnalysisCopy.historyAction)
        .frame(minWidth: 760, minHeight: 480)
        .alert(
            AIConversationHistoryCopy.deleteConfirmationTitle,
            isPresented: Binding(
                get: { !pendingDeletionSummaryIDs.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletionSummaryIDs.removeAll()
                    }
                }
            )
        ) {
            Button("删除", role: .destructive) {
                deleteSummaries(ids: pendingDeletionSummaryIDs)
                pendingDeletionSummaryIDs.removeAll()
            }
            Button("取消", role: .cancel) {
                pendingDeletionSummaryIDs.removeAll()
            }
        } message: {
            Text(AIConversationHistoryCopy.deleteConfirmationMessage)
        }
    }

    private var selectedSummary: AIConversationSummary? {
        if selectedSummaryIDs.count == 1, let id = selectedSummaryIDs.first {
            return model.aiConversationHistory.first(where: { $0.id == id })
        }
        return nil
    }

    private func deleteSummaries(ids: Set<UUID>) {
        model.deleteAIConversationSummaries(ids: ids)
        if selectedSummaryIDs.count <= ids.count {
            selectedSummaryIDs = [model.aiConversationHistory.first?.id].compactMap { $0 }.reduce(into: Set<UUID>()) { $0.insert($1) }
        } else {
            selectedSummaryIDs.subtract(ids)
        }
    }

    private func exportMarkdown(for ids: Set<UUID>) -> String {
        model.aiConversationHistory
            .filter { ids.contains($0.id) }
            .sorted { $0.endDate > $1.endDate }
            .map { summary in
                var lines = ["# \(summary.headline)", ""]
                lines.append("> \(summary.displayPeriodText) · \(summary.serviceDisplayName)")
                lines.append("")
                lines.append("## 核心总结")
                lines.append(summary.summary)
                lines.append("")

                if !summary.findings.isEmpty {
                    lines.append("## 主要发现")
                    for finding in summary.findings {
                        lines.append("- \(finding)")
                    }
                    lines.append("")
                }

                if !summary.suggestions.isEmpty {
                    lines.append("## 改进建议")
                    for suggestion in summary.suggestions {
                        lines.append("- \(suggestion)")
                    }
                    lines.append("")
                }

                if let report = model.longFormReport(for: summary.id) {
                    lines.append("## 流水账：\(report.title)")
                    lines.append(report.content)
                    lines.append("")
                }

                return lines.joined(separator: "\n")
            }
            .joined(separator: "\n\n---\n\n")
    }
}

private struct HistorySummaryRow: View {
    let summary: AIConversationSummary

    var body: some View {
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

private struct HistoryMarkdownExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "md") ?? .plainText] }
    static var writableContentTypes: [UTType] { [UTType(filenameExtension: "md") ?? .plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            content = string
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
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
    private func styledMarkdown(_ content: String) -> some View {
        Markdown(content)
            .markdownTextStyle {
                BackgroundColor(nil)
                TextTracking(0.3)
            }
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(0.4))
                    .markdownMargin(top: 0, bottom: 16)
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
            styledMarkdown(readOnlyText)
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
                styledMarkdown(items.map { "- \($0)" }.joined(separator: "\n"))
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
                    TextField("流水账标题", text: $longFormTitleDraft)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $longFormContentDraft)
                        .frame(minHeight: 220)
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(report.title)
                        .font(.headline)

                    styledMarkdown(report.content)

                    if let flowchart = report.flowchart {
                        let calendarColorHexByName = Dictionary(uniqueKeysWithValues: model.availableCalendars.map { ($0.name, $0.colorHex) })

                        Text("当日流程图")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)

                        FlowchartView(flowchart: flowchart, calendarColorHexByName: calendarColorHexByName)
                            .frame(minHeight: 200)
                    }
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
