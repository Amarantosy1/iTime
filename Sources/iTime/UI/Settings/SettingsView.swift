import SwiftUI

enum SettingsCopy {
    static let navigationTitle = "设置"
    static let calendarSectionTitle = "统计日历"
    static let calendarSectionDescription = "选择要纳入统计的日历。"
    static let noCalendarsText = "当前没有可用日历。"
    static let aiMountSectionTitle = "AI 挂载"
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case calendars
    case aiMounts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendars:
            SettingsCopy.calendarSectionTitle
        case .aiMounts:
            SettingsCopy.aiMountSectionTitle
        }
    }

    var systemImage: String {
        switch self {
        case .calendars:
            "calendar"
        case .aiMounts:
            "sparkles.rectangle.stack"
        }
    }
}

enum AISettingsCopy {
    static let sectionTitle = SettingsCopy.aiMountSectionTitle
    static let helperText = "参考 Cherry Studio 的挂载方式：为每个挂载单独保存 Base URL、模型列表和 API Key，并选择默认挂载。"
    static let addCustomMountAction = "新增挂载"
    static let defaultMountBadge = "默认"
    static let builtInBadge = "内置"
    static let customBadge = "自定义"
    static let mountEnabledTitle = "启用此挂载"
    static let setDefaultMountAction = "设为默认挂载"
    static let deleteMountAction = "删除挂载"
    static let displayNameTitle = "显示名称"
    static let providerTypeTitle = "服务类型"
    static let baseURLTitle = "Base URL"
    static let apiKeyTitle = "API Key"
    static let modelsTitle = "模型列表"
    static let modelsHint = "用英文逗号分隔多个模型。"
    static let defaultModelTitle = "默认模型"
    static let testConnectionAction = "测试连接"
    static let mountPlaceholder = "请选择或新建一个挂载。"

    static func connectionStatusText(for state: AIMountConnectionState) -> String? {
        switch state {
        case .idle:
            return nil
        case .testing:
            return "正在测试连接…"
        case .succeeded(let message), .failed(let message):
            return message
        }
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selectedSection: SettingsSection? = .calendars
    @State private var selectedMountID: UUID?
    @State private var mountAPIKeys: [UUID: String] = [:]
    @State private var mountModelsText: [UUID: String] = [:]

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detailView
                .navigationTitle(SettingsCopy.navigationTitle)
        }
        .frame(width: 960, height: 700)
        .task {
            await model.refresh()
            syncMountEditorState()
            selectedSection = selectedSection ?? .calendars
            selectedMountID = selectedMountID ?? model.defaultAIMountID ?? model.availableAIMounts.first?.id
        }
        .onChange(of: model.availableAIMounts.map(\.id)) { _, _ in
            syncMountEditorState()
            if !model.availableAIMounts.contains(where: { $0.id == selectedMountID }) {
                selectedMountID = model.defaultAIMountID ?? model.availableAIMounts.first?.id
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection ?? .calendars {
        case .calendars:
            calendarSettingsPage
        case .aiMounts:
            aiMountSettingsPage
        }
    }

    private var calendarSettingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(SettingsCopy.calendarSectionTitle)
                    .font(.title3.weight(.semibold))

                Text(SettingsCopy.calendarSectionDescription)
                    .foregroundStyle(.secondary)

                if model.authorizationState != .authorized {
                    AuthorizationStateView(state: model.authorizationState) {
                        Task { await model.requestAccessIfNeeded() }
                    }
                } else if model.availableCalendars.isEmpty {
                    Text(SettingsCopy.noCalendarsText)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private var aiMountSettingsPage: some View {
        HSplitView {
            mountsSidebar
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)

            mountEditor
                .frame(minWidth: 560, maxWidth: .infinity)
        }
    }

    private var mountsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(SettingsCopy.aiMountSectionTitle)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    selectedMountID = model.createCustomAIMount()
                    syncMountEditorState()
                } label: {
                    Label(AISettingsCopy.addCustomMountAction, systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            Text(AISettingsCopy.helperText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(selection: $selectedMountID) {
                ForEach(model.availableAIMounts) { mount in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(mount.displayName)
                                .font(.headline)
                            if mount.id == model.defaultAIMountID {
                                badge(AISettingsCopy.defaultMountBadge, tint: .accentColor)
                            }
                            badge(
                                mount.isBuiltIn ? AISettingsCopy.builtInBadge : AISettingsCopy.customBadge,
                                tint: .secondary
                            )
                        }

                        Text(mount.providerType.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(mount.id)
                }
            }
            .listStyle(.inset)
        }
        .padding(20)
    }

    @ViewBuilder
    private var mountEditor: some View {
        if let mount = selectedMount {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(mount.displayName)
                                .font(.title3.weight(.semibold))
                            Text("\(mount.providerType.title) · \(mount.id == model.defaultAIMountID ? AISettingsCopy.defaultMountBadge : "未设为默认")")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if mount.id != model.defaultAIMountID {
                            Button(AISettingsCopy.setDefaultMountAction) {
                                model.setDefaultAIMount(id: mount.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                AISettingsCopy.mountEnabledTitle,
                                isOn: Binding(
                                    get: { selectedMount?.isEnabled ?? false },
                                    set: { updateSelectedMount(isEnabled: $0) }
                                )
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            if mount.isBuiltIn {
                                labeledValue(AISettingsCopy.displayNameTitle, value: mount.displayName)
                                labeledValue(AISettingsCopy.providerTypeTitle, value: mount.providerType.title)
                            } else {
                                TextField(
                                    AISettingsCopy.displayNameTitle,
                                    text: Binding(
                                        get: { selectedMount?.displayName ?? "" },
                                        set: { updateSelectedMount(displayName: $0) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)

                                Picker(
                                    AISettingsCopy.providerTypeTitle,
                                    selection: Binding(
                                        get: { selectedMount?.providerType ?? .openAI },
                                        set: { updateSelectedMount(providerType: $0) }
                                    )
                                ) {
                                    ForEach(AIProviderKind.allCases, id: \.self) { provider in
                                        Text(provider.title).tag(provider)
                                    }
                                }
                            }

                            TextField(
                                AISettingsCopy.baseURLTitle,
                                text: Binding(
                                    get: { selectedMount?.baseURL ?? "" },
                                    set: { updateSelectedMount(baseURL: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            SecureField(
                                AISettingsCopy.apiKeyTitle,
                                text: Binding(
                                    get: { mountAPIKeys[mount.id] ?? "" },
                                    set: { newValue in
                                        mountAPIKeys[mount.id] = newValue
                                        model.updateAIAPIKey(newValue, for: mount.id)
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(AISettingsCopy.modelsTitle)
                                    .font(.subheadline.weight(.semibold))
                                TextField(
                                    AISettingsCopy.modelsTitle,
                                    text: Binding(
                                        get: { mountModelsText[mount.id] ?? "" },
                                        set: { newValue in
                                            mountModelsText[mount.id] = newValue
                                            updateSelectedMount(models: parseModels(from: newValue))
                                        }
                                    ),
                                    axis: .vertical
                                )
                                .textFieldStyle(.roundedBorder)
                                Text(AISettingsCopy.modelsHint)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            TextField(
                                AISettingsCopy.defaultModelTitle,
                                text: Binding(
                                    get: { selectedMount?.defaultModel ?? "" },
                                    set: { updateSelectedMount(defaultModel: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Button(AISettingsCopy.testConnectionAction) {
                                    Task { await model.testAIMountConnection(mount.id) }
                                }
                                .buttonStyle(.borderedProminent)

                                if !mount.isBuiltIn {
                                    Button(AISettingsCopy.deleteMountAction, role: .destructive) {
                                        let deletingID = mount.id
                                        model.deleteAIMount(id: deletingID)
                                        selectedMountID = model.defaultAIMountID ?? model.availableAIMounts.first?.id
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if let statusText = AISettingsCopy.connectionStatusText(
                                for: model.aiMountConnectionState(for: mount.id)
                            ) {
                                Text(statusText)
                                    .foregroundStyle(connectionStatusColor(for: model.aiMountConnectionState(for: mount.id)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                AISettingsCopy.mountPlaceholder,
                systemImage: "slider.horizontal.3"
            )
        }
    }

    private var selectedMount: AIProviderMount? {
        guard let selectedMountID else { return nil }
        return model.availableAIMounts.first(where: { $0.id == selectedMountID })
    }

    private func binding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { _ in
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }

    private func syncMountEditorState() {
        for mount in model.availableAIMounts {
            mountAPIKeys[mount.id] = model.loadAIAPIKey(for: mount.id)
            mountModelsText[mount.id] = mount.models.joined(separator: ", ")
        }
    }

    private func updateSelectedMount(
        displayName: String? = nil,
        providerType: AIProviderKind? = nil,
        baseURL: String? = nil,
        models: [String]? = nil,
        defaultModel: String? = nil,
        isEnabled: Bool? = nil
    ) {
        guard let mount = selectedMount else { return }
        let updatedMount = AIProviderMount(
            id: mount.id,
            displayName: displayName ?? mount.displayName,
            providerType: providerType ?? mount.providerType,
            baseURL: baseURL ?? mount.baseURL,
            models: models ?? mount.models,
            defaultModel: defaultModel ?? mount.defaultModel,
            isEnabled: isEnabled ?? mount.isEnabled,
            isBuiltIn: mount.isBuiltIn
        )
        model.updateAIMount(updatedMount)
    }

    private func parseModels(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func connectionStatusColor(for state: AIMountConnectionState) -> Color {
        switch state {
        case .failed:
            return .red
        case .succeeded:
            return .green
        case .idle, .testing:
            return .secondary
        }
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }

    private func labeledValue(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
