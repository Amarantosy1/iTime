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
                        
                        summarySection(text: $summaryDraft, readOnlyText: summary.summary, isEditing: isEditing)
                        
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
                styledMarkdown(readOnlyText)
            }
        }
    }

    @ViewBuilder
    private func summarySection(text: Binding<String>, readOnlyText: String, isEditing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("总结").font(.headline)
            if isEditing {
                TextEditor(text: text)
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            } else {
                let sections = splitSummarySections(from: readOnlyText)
                VStack(alignment: .leading, spacing: 10) {
                    Text("客观总结")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    styledMarkdown(sections.objective, compact: true)
                    if let subjective = sections.subjective, !subjective.isEmpty {
                        Text("主观评价")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        styledMarkdown(subjective)
                    }
                }
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
                    styledMarkdown(items.map { "- \($0)" }.joined(separator: "\n"))
                }
            }
        }
    }

    @ViewBuilder
    private func styledMarkdown(_ content: String, compact: Bool = false) -> some View {
        markdownView(content, compact: compact)
    }

    private func markdownView(_ content: String, compact: Bool = false) -> some View {
        Markdown(normalizedMarkdown(content))
            .markdownTextStyle {
                BackgroundColor(nil)
                ForegroundColor(compact ? .secondary : .primary)
                if compact {
                    FontSize(.em(0.9))
                }
            }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.88))
                BackgroundColor(.blue.opacity(0.16))
            }
            .markdownTextStyle(\.strong) {
                FontWeight(.bold)
                ForegroundColor(.primary)
                BackgroundColor(.yellow.opacity(0.4))
            }
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .relativeLineSpacing(.em(0.25))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .markdownMargin(top: 0, bottom: 10)
            }
            .markdownBlockStyle(\.codeBlock) { configuration in
                ScrollView(.horizontal, showsIndicators: true) {
                    configuration.label
                        .relativeLineSpacing(.em(0.2))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .markdownMargin(top: 4, bottom: 12)
            }
    }

    private func splitSummarySections(from rawText: String) -> (objective: String, subjective: String?) {
        let normalized = normalizedMarkdown(rawText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer explicit labels if model follows the prompt.
        if let objectiveRange = normalized.range(of: "客观总结[:：]", options: .regularExpression),
           let subjectiveRange = normalized.range(of: "主观评价[:：]", options: .regularExpression),
           objectiveRange.upperBound <= subjectiveRange.lowerBound {
            let objective = String(normalized[objectiveRange.upperBound..<subjectiveRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let subjective = String(normalized[subjectiveRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (objective: objective.isEmpty ? normalized : objective, subjective: subjective.isEmpty ? nil : subjective)
        }

        // Fallback: first paragraph as objective, second paragraph as subjective.
        let parts = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return (objective: normalized, subjective: nil)
        }
        let objective = parts[0]
        let subjective = parts.count > 1 ? parts.dropFirst().joined(separator: "\n\n") : nil
        return (objective: objective, subjective: subjective)
    }

    private func normalizedMarkdown(_ rawText: String) -> String {
        let unescaped = rawText
            .replacingOccurrences(of: "\\\\n", with: "\n")
            .replacingOccurrences(of: "\\`", with: "`")
            .replacingOccurrences(of: "\\*", with: "*")
            .replacingOccurrences(of: "\\_", with: "_")

        // Convert ==highlight== and <mark>highlight</mark> to **highlight**.
        let equalsConverted = unescaped.replacingOccurrences(
            of: #"==([^=\n][^=]*?)=="#,
            with: "**$1**",
            options: .regularExpression
        )

        return equalsConverted.replacingOccurrences(
            of: #"<mark>(.*?)</mark>"#,
            with: "**$1**",
            options: [.regularExpression, .caseInsensitive]
        )
    }
    
    private func parseLines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
