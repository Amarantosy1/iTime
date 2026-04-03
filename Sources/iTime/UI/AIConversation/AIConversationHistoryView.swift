import SwiftUI

struct AIConversationHistoryView: View {
    let summaries: [AIConversationSummary]
    @State private var selectedSummaryID: UUID?

    var body: some View {
        NavigationSplitView {
            if summaries.isEmpty {
                Text("还没有历史总结。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(selection: $selectedSummaryID) {
                    ForEach(summaries, id: \.id) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summary.headline)
                                .font(.headline)
                            Text("\(summary.provider.title) · \(summary.range.title)")
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
                    selectedSummaryID = selectedSummaryID ?? summaries.first?.id
                }
            }
        } detail: {
            if let summary = selectedSummary {
                AIConversationSummaryDetailView(summary: summary)
            } else {
                Text("还没有历史总结。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AIAnalysisCopy.historyAction)
        .frame(minWidth: 700, minHeight: 440)
    }

    private var selectedSummary: AIConversationSummary? {
        if let selectedSummaryID {
            return summaries.first(where: { $0.id == selectedSummaryID })
        }
        return summaries.first
    }
}

private struct AIConversationSummaryDetailView: View {
    let summary: AIConversationSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(summary.headline)
                    .font(.title2.weight(.semibold))

                Text("\(summary.provider.title) · \(summary.range.title)")
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
