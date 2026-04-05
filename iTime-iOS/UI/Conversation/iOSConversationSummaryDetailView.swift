import SwiftUI
import MarkdownUI

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
                    }
                    .padding()
                }
                .navigationTitle(isEditing ? "编辑复盘" : "复盘详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
            Text(title).font(.headline)
            if isEditing {
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            } else {
                Markdown(readOnlyText)
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
                                Markdown(item)
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
}
