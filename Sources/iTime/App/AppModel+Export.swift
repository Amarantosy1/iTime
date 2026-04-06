import Foundation
import CoreGraphics

extension AppModel {
    public func exportMarkdown(for ids: Set<UUID>) -> String {
        return aiConversationHistory
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
                
                if let report = longFormReport(for: summary.id) {
                    lines.append("## 流水账：\(report.title)")
                    lines.append(report.content)
                    lines.append("")
                }
                
                return lines.joined(separator: "\n")
            }
            .joined(separator: "\n\n---\n\n")
    }
}
