import SwiftUI

enum SettingsCopy {
    static let navigationTitle = "设置"
    static let calendarSectionTitle = "统计日历"
    static let noCalendarsText = "当前没有可用日历。"
    static let aiServicesSectionTitle = "AI 服务"
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case calendars
    case aiServices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendars:
            SettingsCopy.calendarSectionTitle
        case .aiServices:
            SettingsCopy.aiServicesSectionTitle
        }
    }

    var systemImage: String {
        switch self {
        case .calendars:
            "calendar"
        case .aiServices:
            "sparkles.rectangle.stack"
        }
    }
}

enum AISettingsCopy {
    static let sectionTitle = SettingsCopy.aiServicesSectionTitle
    static let addCustomServiceAction = "新增自定义服务"
    static let defaultServiceBadge = "默认"
    static let builtInBadge = "内置"
    static let customBadge = "自定义"
    static let serviceEnabledTitle = "启用此服务"
    static let setDefaultServiceAction = "设为默认服务"
    static let deleteServiceAction = "删除服务"
    static let displayNameTitle = "显示名称"
    static let providerTypeTitle = "服务类型"
    static let baseURLTitle = "Base URL"
    static let apiKeyTitle = "API Key"
    static let modelsTitle = "模型列表"
    static let modelsHint = "用英文逗号分隔多个模型。"
    static let defaultModelTitle = "默认模型"
    static let testConnectionAction = "测试连接"
    static let servicePlaceholder = "请选择或新建一个服务。"
    static let defaultServiceTitle = "默认服务"
    static let builtInServicesTitle = "内置服务"
    static let customServicesTitle = "自定义服务"

    static func connectionStatusText(for state: AIServiceConnectionState) -> String? {
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
    @State private var selectedServiceID: UUID?
    @State private var serviceAPIKeys: [UUID: String] = [:]
    @State private var serviceModelsText: [UUID: String] = [:]

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
            syncServiceEditorState()
            selectedSection = selectedSection ?? .calendars
            selectedServiceID = selectedServiceID ?? model.defaultAIServiceID ?? model.availableAIServices.first?.id
        }
        .onChange(of: model.availableAIServices.map(\.id)) { _, _ in
            syncServiceEditorState()
            if !model.availableAIServices.contains(where: { $0.id == selectedServiceID }) {
                selectedServiceID = model.defaultAIServiceID ?? model.availableAIServices.first?.id
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection ?? .calendars {
        case .calendars:
            calendarSettingsPage
        case .aiServices:
            aiServicesSettingsPage
        }
    }

    private var calendarSettingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(SettingsCopy.calendarSectionTitle)
                    .font(.title3.weight(.semibold))

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

    private var aiServicesSettingsPage: some View {
        HSplitView {
            servicesSidebar
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)

            serviceEditor
                .frame(minWidth: 560, maxWidth: .infinity)
        }
    }

    private var servicesSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(SettingsCopy.aiServicesSectionTitle)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    selectedServiceID = model.createCustomAIService()
                    syncServiceEditorState()
                } label: {
                    Label(AISettingsCopy.addCustomServiceAction, systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            List(selection: $selectedServiceID) {
                ForEach(model.availableAIServices) { service in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(service.displayName)
                                .font(.headline)
                            if service.id == model.defaultAIServiceID {
                                badge(AISettingsCopy.defaultServiceBadge, tint: .accentColor)
                            }
                            badge(
                                service.isBuiltIn ? AISettingsCopy.builtInBadge : AISettingsCopy.customBadge,
                                tint: .secondary
                            )
                        }

                        Text(service.providerKind.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(service.id)
                }
            }
            .listStyle(.inset)
        }
        .padding(20)
    }

    @ViewBuilder
    private var serviceEditor: some View {
        if let service = selectedService {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.displayName)
                                .font(.title3.weight(.semibold))
                            Text("\(service.providerKind.title) · \(service.id == model.defaultAIServiceID ? AISettingsCopy.defaultServiceBadge : "未设为默认")")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if service.id != model.defaultAIServiceID {
                            Button(AISettingsCopy.setDefaultServiceAction) {
                                model.setDefaultAIService(id: service.id)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(
                                AISettingsCopy.serviceEnabledTitle,
                                isOn: Binding(
                                    get: { selectedService?.isEnabled ?? false },
                                    set: { updateSelectedService(isEnabled: $0) }
                                )
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            if service.isBuiltIn {
                                labeledValue(AISettingsCopy.displayNameTitle, value: service.displayName)
                                labeledValue(AISettingsCopy.providerTypeTitle, value: service.providerKind.title)
                            } else {
                                TextField(
                                    AISettingsCopy.displayNameTitle,
                                    text: Binding(
                                        get: { selectedService?.displayName ?? "" },
                                        set: { updateSelectedService(displayName: $0) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)

                                labeledValue(AISettingsCopy.providerTypeTitle, value: AIProviderKind.openAICompatible.title)
                            }

                            TextField(
                                AISettingsCopy.baseURLTitle,
                                text: Binding(
                                    get: { selectedService?.baseURL ?? "" },
                                    set: { updateSelectedService(baseURL: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            SecureField(
                                AISettingsCopy.apiKeyTitle,
                                text: Binding(
                                    get: { serviceAPIKeys[service.id] ?? "" },
                                    set: { newValue in
                                        serviceAPIKeys[service.id] = newValue
                                        model.updateAIAPIKey(newValue, for: service.id)
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
                                        get: { serviceModelsText[service.id] ?? "" },
                                        set: { newValue in
                                            serviceModelsText[service.id] = newValue
                                            updateSelectedService(models: parseModels(from: newValue))
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
                                    get: { selectedService?.defaultModel ?? "" },
                                    set: { updateSelectedService(defaultModel: $0) }
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
                                    Task { await model.testAIServiceConnection(service.id) }
                                }
                                .buttonStyle(.borderedProminent)

                                if !service.isBuiltIn {
                                    Button(AISettingsCopy.deleteServiceAction, role: .destructive) {
                                        let deletingID = service.id
                                        model.deleteAIService(id: deletingID)
                                        selectedServiceID = model.defaultAIServiceID ?? model.availableAIServices.first?.id
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if let statusText = AISettingsCopy.connectionStatusText(
                                for: model.aiServiceConnectionState(for: service.id)
                            ) {
                                Text(statusText)
                                    .foregroundStyle(connectionStatusColor(for: model.aiServiceConnectionState(for: service.id)))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                AISettingsCopy.servicePlaceholder,
                systemImage: "slider.horizontal.3"
            )
        }
    }

    private var selectedService: AIServiceEndpoint? {
        guard let selectedServiceID else { return nil }
        return model.availableAIServices.first(where: { $0.id == selectedServiceID })
    }

    private func binding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { _ in
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }

    private func syncServiceEditorState() {
        for service in model.availableAIServices {
            serviceAPIKeys[service.id] = model.loadAIAPIKey(for: service.id)
            serviceModelsText[service.id] = service.models.joined(separator: ", ")
        }
    }

    private func updateSelectedService(
        displayName: String? = nil,
        baseURL: String? = nil,
        models: [String]? = nil,
        defaultModel: String? = nil,
        isEnabled: Bool? = nil
    ) {
        guard let service = selectedService else { return }
        let updatedService = AIServiceEndpoint(
            id: service.id,
            displayName: displayName ?? service.displayName,
            providerKind: service.providerKind,
            baseURL: baseURL ?? service.baseURL,
            models: models ?? service.models,
            defaultModel: defaultModel ?? service.defaultModel,
            isEnabled: isEnabled ?? service.isEnabled,
            isBuiltIn: service.isBuiltIn
        )
        model.updateAIService(updatedService)
    }

    private func parseModels(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func connectionStatusColor(for state: AIServiceConnectionState) -> Color {
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
