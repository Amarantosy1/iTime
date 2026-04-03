import SwiftUI

private enum AIConversationHistoryCopy {
    static let emptyText = "还没有历史总结。"
    static let deleteAction = "删除总结"
    static let deleteConfirmationTitle = "删除这条历史总结？"
    static let deleteConfirmationMessage = "删除后会同时移除关联会话记录和依赖它的 memory。"
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
                            Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(summary.summary)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
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
                    summary: summary,
                    onDelete: { pendingDeletionSummaryID = summary.id }
                )
            } else {
                Text(AIConversationHistoryCopy.emptyText)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AIAnalysisCopy.historyAction)
        .frame(minWidth: 760, minHeight: 480)
        .toolbar {
            if selectedSummary != nil {
                ToolbarItem {
                    Button(AIConversationHistoryCopy.deleteAction, role: .destructive) {
                        pendingDeletionSummaryID = selectedSummaryID
                    }
                }
            }
        }
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
    let summary: AIConversationSummary
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.headline)
                            .font(.title2.weight(.semibold))

                        Text("\(summary.serviceDisplayName) · \(summary.displayPeriodText)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(AIConversationHistoryCopy.deleteAction, role: .destructive, action: onDelete)
                }

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
