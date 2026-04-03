import SwiftUI

enum AIAnalysisCopy {
    static let sectionTitle = "AI 时间评估"
    static let generateAction = "生成评估"
    static let regenerateAction = "重新生成"
    static let loadingText = "正在生成评估…"
    static let helperText = "根据当前范围内的统计结果，生成时间管理诊断与改进建议。"
}

struct OverviewAIAnalysisSection: View {
    @Bindable var model: AppModel

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(AIAnalysisCopy.sectionTitle)
                    .font(.headline)

                switch model.aiAnalysisState {
                case .unavailable(let availability):
                    Text(availability.message)
                        .foregroundStyle(.secondary)

                    if availability != .noData {
                        SettingsLink {
                            Text("打开设置")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                case .idle:
                    Text(AIAnalysisCopy.helperText)
                        .foregroundStyle(.secondary)

                    Button(AIAnalysisCopy.generateAction) {
                        Task { await model.analyzeOverview() }
                    }
                    .buttonStyle(.borderedProminent)

                case .loading:
                    ProgressView(AIAnalysisCopy.loadingText)

                case .loaded(let result):
                    VStack(alignment: .leading, spacing: 10) {
                        Text(result.summary)
                            .font(.title3.weight(.semibold))

                        if !result.findings.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("主要发现")
                                    .font(.subheadline.weight(.semibold))
                                ForEach(result.findings, id: \.self) { item in
                                    Text("• \(item)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !result.suggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("改进建议")
                                    .font(.subheadline.weight(.semibold))
                                ForEach(result.suggestions, id: \.self) { item in
                                    Text("• \(item)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button(AIAnalysisCopy.regenerateAction) {
                        Task { await model.analyzeOverview() }
                    }
                    .buttonStyle(.bordered)

                case .failed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)

                    Button(AIAnalysisCopy.regenerateAction) {
                        Task { await model.analyzeOverview() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
