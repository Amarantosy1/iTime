import SwiftUI

enum AISettingsCopy {
    static let sectionTitle = "AI 评估"
    static let enableTitle = "启用 AI 时间评估"
    static let helperText = "为每个 AI 单独保存 Base URL、Model 和 API Key，并选择默认使用的提供商。"
    static let defaultProviderTitle = "默认 AI"
    static let baseURLPlaceholder = "Base URL"
    static let modelPlaceholder = "Model"
    static let apiKeyPlaceholder = "API Key"
    static let providerEnabledTitle = "启用此提供商"

    static func providerSectionTitle(for provider: AIProviderKind) -> String {
        provider.title
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var aiAPIKeys: [AIProviderKind: String] = [:]

    var body: some View {
        NavigationStack {
            settingsForm
                .navigationTitle("设置")
        }
        .frame(width: 520, height: 620)
        .task {
            await model.refresh()
            for provider in AIProviderKind.allCases {
                aiAPIKeys[provider] = model.loadAIAPIKey(for: provider)
            }
        }
    }

    private var settingsForm: some View {
        Form {
            aiSettingsSection

            ForEach(AIProviderKind.allCases, id: \.self) { provider in
                providerSection(for: provider)
            }

            calendarSection
        }
        .formStyle(.grouped)
    }

    private var aiSettingsSection: some View {
        Section(AISettingsCopy.sectionTitle) {
            Toggle(
                AISettingsCopy.enableTitle,
                isOn: Binding(
                    get: { model.preferences.aiAnalysisEnabled },
                    set: { model.updateAIAnalysisEnabled($0) }
                )
            )

            Picker(
                AISettingsCopy.defaultProviderTitle,
                selection: Binding(
                    get: { model.preferences.defaultAIProvider },
                    set: { model.updateDefaultAIProvider($0) }
                )
            ) {
                ForEach(AIProviderKind.allCases, id: \.self) { provider in
                    Text(provider.title).tag(provider)
                }
            }

            Text(AISettingsCopy.helperText)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func providerSection(for provider: AIProviderKind) -> some View {
        let configuration = model.aiProviderConfiguration(for: provider)

        Section(AISettingsCopy.providerSectionTitle(for: provider)) {
            Toggle(
                AISettingsCopy.providerEnabledTitle,
                isOn: Binding(
                    get: { model.aiProviderConfiguration(for: provider).isEnabled },
                    set: { model.updateAIProviderEnabled($0, for: provider) }
                )
            )

            TextField(
                AISettingsCopy.baseURLPlaceholder,
                text: Binding(
                    get: { model.aiProviderConfiguration(for: provider).baseURL },
                    set: { model.updateAIProviderBaseURL($0, for: provider) }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                AISettingsCopy.modelPlaceholder,
                text: Binding(
                    get: { model.aiProviderConfiguration(for: provider).model },
                    set: { model.updateAIProviderModel($0, for: provider) }
                )
            )
            .textFieldStyle(.roundedBorder)

            SecureField(
                AISettingsCopy.apiKeyPlaceholder,
                text: Binding(
                    get: { aiAPIKeys[provider] ?? "" },
                    set: { newValue in
                        aiAPIKeys[provider] = newValue
                        model.updateAIAPIKey(newValue, for: provider)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            Text(configuration.isEnabled ? "已为 \(provider.title) 启用独立配置。" : "可先填写配置，再按需启用 \(provider.title)。")
                .foregroundStyle(.secondary)
        }
    }

    private var calendarSection: some View {
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

    private func binding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { _ in
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }
}
