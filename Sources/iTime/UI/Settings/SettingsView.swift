import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var aiAPIKey = ""

    var body: some View {
        NavigationStack {
            settingsForm
            .navigationTitle("设置")
        }
        .frame(width: 420, height: 360)
        .task {
            await model.refresh()
            aiAPIKey = model.loadAIAPIKey()
        }
    }

    private var settingsForm: some View {
        Form {
            Section("AI 评估") {
                Toggle(
                    "启用 AI 时间评估",
                    isOn: Binding(
                        get: { model.preferences.aiAnalysisEnabled },
                        set: { model.updateAIAnalysisEnabled($0) }
                    )
                )

                Text("配置兼容 OpenAI 接口的 AI 服务，用于生成时间管理诊断与建议。")
                    .foregroundStyle(.secondary)

                TextField(
                    "Base URL",
                    text: Binding(
                        get: { model.preferences.aiBaseURL },
                        set: { model.updateAIBaseURL($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "Model",
                    text: Binding(
                        get: { model.preferences.aiModel },
                        set: { model.updateAIModel($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $aiAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aiAPIKey) { _, newValue in
                        model.updateAIAPIKey(newValue)
                    }
            }

            Section("统计日历") {
                Text("选择要纳入统计的日历。")
                    .foregroundStyle(.secondary)

                if model.authorizationState != .authorized {
                    AuthorizationStateView(state: model.authorizationState) {
                        Task { await model.requestAccessIfNeeded() }
                    }
                } else if model.availableCalendars.isEmpty {
                    Text("当前没有可用日历。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.availableCalendars) { calendar in
                        Toggle(isOn: binding(for: calendar)) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: calendar.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(calendar.name)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { _ in
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }
}
