import SwiftUI

enum SettingsCopy {
    static let navigationTitle = "设置"
    static let calendarSectionTitle = "统计日历"
    static let noCalendarsText = "当前没有可用日历。"
    static let aiServicesSectionTitle = "AI 服务"
    static let reviewReminderSectionTitle = "复盘提醒"
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case calendars
    case aiServices
    case reviewReminder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendars:
            SettingsCopy.calendarSectionTitle
        case .aiServices:
            SettingsCopy.aiServicesSectionTitle
        case .reviewReminder:
            SettingsCopy.reviewReminderSectionTitle
        }
    }

    var systemImage: String {
        switch self {
        case .calendars:
            "calendar"
        case .aiServices:
            "sparkles.rectangle.stack"
        case .reviewReminder:
            "bell.badge"
        }
    }
}

enum ReviewReminderCopy {
    static let sectionTitle = SettingsCopy.reviewReminderSectionTitle
    static let enabledTitle = "启用每日复盘提醒"
    static let timeTitle = "提醒时间"
    static let requestPermissionAction = "允许通知"
    static let authorizationGrantedText = "通知权限已允许。"
    static let authorizationPendingText = "需要通知权限后才能按时提醒。"
    static let authorizationDeniedText = "系统通知权限已关闭，请前往系统设置开启。"
}

enum AISettingsCopy {
    static let sectionTitle = SettingsCopy.aiServicesSectionTitle
    static let addCustomServiceAction = "新增自定义服务"
    static let defaultServiceBadge = "默认"
    static let builtInBadge = "内置"
    static let customBadge = "自定义"
    static let serviceListTitle = "服务列表"
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
    static let selectedServiceTitle = "服务详情"

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
        case .reviewReminder:
            reviewReminderSettingsPage
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(SettingsCopy.aiServicesSectionTitle)
                    .font(.title3.weight(.semibold))

                defaultServiceSection
                serviceListSection
                serviceEditorSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private var reviewReminderSettingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(ReviewReminderCopy.sectionTitle)
                    .font(.title3.weight(.semibold))

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(
                            ReviewReminderCopy.enabledTitle,
                            isOn: Binding(
                                get: { model.preferences.reviewReminderEnabled },
                                set: { isEnabled in
                                    Task { await model.updateReviewReminderEnabled(isEnabled) }
                                }
                            )
                        )

                        DatePicker(
                            ReviewReminderCopy.timeTitle,
                            selection: Binding(
                                get: { model.preferences.reviewReminderTime },
                                set: { newTime in
                                    Task { await model.updateReviewReminderTime(newTime) }
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )
                        .disabled(!model.preferences.reviewReminderEnabled)
                        .datePickerStyle(.field)
                        .frame(maxWidth: 240, alignment: .leading)

                        Text(reviewReminderStatusText)
                            .foregroundStyle(reviewReminderStatusColor)

                        if model.reviewReminderAuthorizationStatus != .authorized {
                            Button(ReviewReminderCopy.requestPermissionAction) {
                                Task { await model.requestReviewReminderAuthorization() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private var defaultServiceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(AISettingsCopy.defaultServiceTitle)
                    .font(.headline)

                Picker(AISettingsCopy.defaultServiceTitle, selection: Binding(
                    get: { model.defaultAIServiceID ?? model.availableAIServices.first?.id },
                    set: { id in
                        if let id {
                            model.setDefaultAIService(id: id)
                            if selectedServiceID == nil {
                                selectedServiceID = id
                            }
                        }
                    }
                )) {
                    ForEach(model.availableAIServices) { service in
                        Text(service.displayName).tag(Optional(service.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var serviceListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AISettingsCopy.serviceListTitle)
                .font(.headline)

            aiServiceGroup(title: AISettingsCopy.builtInServicesTitle, services: builtInServices)

            aiServiceGroup(
                title: AISettingsCopy.customServicesTitle,
                services: customServices,
                trailingAction: {
                    Button {
                        selectedServiceID = model.createCustomAIService()
                        syncServiceEditorState()
                    } label: {
                        Label(AISettingsCopy.addCustomServiceAction, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            )
        }
    }

    @ViewBuilder
    private var serviceEditorSection: some View {
        GroupBox {
            if let service = selectedService {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AISettingsCopy.selectedServiceTitle)
                                .font(.headline)
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

                    Toggle(
                        AISettingsCopy.serviceEnabledTitle,
                        isOn: Binding(
                            get: { selectedService?.isEnabled ?? false },
                            set: { updateSelectedService(isEnabled: $0) }
                        )
                    )

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
            } else {
                ContentUnavailableView(
                    AISettingsCopy.servicePlaceholder,
                    systemImage: "slider.horizontal.3"
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            }
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

    private var builtInServices: [AIServiceEndpoint] {
        model.availableAIServices.filter(\.isBuiltIn)
    }

    private var customServices: [AIServiceEndpoint] {
        model.availableAIServices.filter { !$0.isBuiltIn }
    }

    @ViewBuilder
    private func aiServiceGroup(
        title: String,
        services: [AIServiceEndpoint],
        @ViewBuilder trailingAction: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                trailingAction()
            }

            if services.isEmpty {
                Text(AISettingsCopy.servicePlaceholder)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(services) { service in
                        serviceRow(service)
                    }
                }
            }
        }
    }

    private func serviceRow(_ service: AIServiceEndpoint) -> some View {
        Button {
            selectedServiceID = service.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(service.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
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

                Spacer()

                Image(systemName: selectedServiceID == service.id ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedServiceID == service.id ? .accentColor : .secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedServiceID == service.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedServiceID == service.id ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var reviewReminderStatusText: String {
        switch model.reviewReminderAuthorizationStatus {
        case .authorized:
            ReviewReminderCopy.authorizationGrantedText
        case .notDetermined:
            ReviewReminderCopy.authorizationPendingText
        case .denied:
            ReviewReminderCopy.authorizationDeniedText
        }
    }

    private var reviewReminderStatusColor: Color {
        switch model.reviewReminderAuthorizationStatus {
        case .authorized:
            .green
        case .notDetermined:
            .secondary
        case .denied:
            .red
        }
    }
}
