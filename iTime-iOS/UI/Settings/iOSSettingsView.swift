import SwiftUI
import UIKit
import PhotosUI

struct iOSSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                iOSThemeBackground(
                    theme: model.preferences.interfaceTheme,
                    accentColor: .accentColor,
                    customImageName: model.preferences.customThemeImageName,
                    customScale: model.preferences.customThemeScale,
                    customOffsetX: model.preferences.customThemeOffsetX,
                    customOffsetY: model.preferences.customThemeOffsetY,
                    starCount: 160,
                    twinkleBoost: 1.8,
                    meteorCount: 5
                )

                List {
                    Section("偏好") {
                        NavigationLink {
                            iOSThemeSettingsDetailView(model: model)
                        } label: {
                            SettingsEntryRow(
                                icon: "paintpalette",
                                tint: .pink,
                                title: "主题",
                                subtitle: themeSummaryText
                            )
                        }

                        NavigationLink {
                            iOSCalendarSettingsDetailView(model: model)
                        } label: {
                            SettingsEntryRow(
                                icon: "calendar",
                                tint: .blue,
                                title: "统计日历",
                                subtitle: calendarSummaryText
                            )
                        }

                        NavigationLink {
                            iOSReviewReminderSettingsDetailView(model: model)
                        } label: {
                            SettingsEntryRow(
                                icon: "bell.badge",
                                tint: .orange,
                                title: "复盘提醒",
                                subtitle: reminderSummaryText
                            )
                        }
                    }

                    Section("AI") {
                        NavigationLink {
                            iOSAISettingsDetailView(model: model)
                        } label: {
                            SettingsEntryRow(
                                icon: "sparkles.rectangle.stack",
                                tint: .purple,
                                title: "AI 服务",
                                subtitle: aiSummaryText
                            )
                        }
                    }

                    Section("同步") {
                        NavigationLink {
                            iOSDeviceSyncSettingsDetailView(model: model)
                        } label: {
                            SettingsEntryRow(
                                icon: "arrow.triangle.2.circlepath.icloud",
                                tint: .teal,
                                title: "设备互传",
                                subtitle: syncSummaryText
                            )
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("设置")
            .task {
                await model.refresh()
            }
        }
    }

    private var calendarSummaryText: String {
        guard model.authorizationState == .authorized else {
            return "需要日历权限"
        }
        let selectedCount = model.availableCalendars.filter(\.isSelected).count
        let reviewCount = model.availableCalendars.filter { $0.isSelected && $0.isIncludedInReview }.count
        return "已选 \(selectedCount) 个，复盘 \(reviewCount) 个"
    }

    private var themeSummaryText: String {
        model.preferences.interfaceTheme.title
    }

    private var reminderSummaryText: String {
        if !model.preferences.reviewReminderEnabled {
            return "已关闭"
        }
        switch model.reviewReminderAuthorizationStatus {
        case .authorized:
            return "已启用"
        case .notDetermined:
            return "等待授权"
        case .denied:
            return "权限已拒绝"
        }
    }

    private var aiSummaryText: String {
        let defaultService = model.availableAIServices.first(where: { $0.id == model.defaultAIServiceID })
        return defaultService?.displayName ?? "未配置默认服务"
    }

    private var syncSummaryText: String {
        if model.discoveredPeers.isEmpty {
            return "暂未发现设备"
        }
        return "已发现 \(model.discoveredPeers.count) 台设备"
    }
}

private struct iOSThemeSettingsDetailView: View {
    @Bindable var model: AppModel
    @State private var selectedTab: ThemeSettingsTab = .builtIn
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var cropScale: Double = 1.12
    @State private var cropOffsetX: Double = 0
    @State private var cropOffsetY: Double = 0
    @State private var uploadErrorText: String?

    var body: some View {
        List {
            Section("主题类型") {
                Picker("主题类型", selection: $selectedTab) {
                    ForEach(ThemeSettingsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }

            if selectedTab == .builtIn {
                builtInThemeSection
            } else {
                customThemeSection
            }
        }
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            syncThemeEditorStateFromPreferences()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await handlePhotoSelection(item) }
        }
        .onChange(of: cropScale) { _, _ in
            persistCropTransform()
        }
        .onChange(of: cropOffsetX) { _, _ in
            persistCropTransform()
        }
        .onChange(of: cropOffsetY) { _, _ in
            persistCropTransform()
        }
    }

    private var builtInThemeSection: some View {
        Section("内置主题") {
            Picker(
                "内置主题",
                selection: Binding(
                    get: {
                        model.preferences.interfaceTheme.isBuiltIn ? model.preferences.interfaceTheme : .flowing
                    },
                    set: {
                        model.preferences.interfaceTheme = $0
                    }
                )
            ) {
                ForEach(AppDisplayTheme.builtInCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.inline)

            Text(builtInThemeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var customThemeSection: some View {
        Section("自定义主题") {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("上传背景图片", systemImage: "photo.on.rectangle")
            }

            if let previewImage {
                CustomThemeCropPreview(
                    image: previewImage,
                    scale: cropScale,
                    offsetX: cropOffsetX,
                    offsetY: cropOffsetY
                )

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("缩放") {
                        Text(String(format: "%.2fx", cropScale))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cropScale, in: 1.0...4.0)

                    LabeledContent("水平偏移") {
                        Text(String(format: "%.2f", cropOffsetX))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cropOffsetX, in: -1.0...1.0)

                    LabeledContent("垂直偏移") {
                        Text(String(format: "%.2f", cropOffsetY))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cropOffsetY, in: -1.0...1.0)
                }

                HStack(spacing: 10) {
                    Button("应用自定义主题") {
                        model.preferences.interfaceTheme = .custom
                    }
                    .buttonStyle(.borderedProminent)

                    Button("重置裁切") {
                        cropScale = 1.12
                        cropOffsetX = 0
                        cropOffsetY = 0
                        persistCropTransform()
                    }
                    .buttonStyle(.bordered)
                }

                Button("移除背景图片", role: .destructive) {
                    removeCustomThemeImage()
                }

                if model.preferences.interfaceTheme != .custom {
                    Text("已保存图片与裁切，点击“应用自定义主题”后生效。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("先上传一张图片作为背景。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let uploadErrorText {
                Text(uploadErrorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Text("参考成熟项目：Mantis（1.2k⭐）和 ImageCropper（SwiftUI 原生），当前实现采用本地图片 + 手动裁切参数，便于和现有主题系统集成。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var builtInThemeDescription: String {
        switch model.preferences.interfaceTheme {
        case .flowing:
            return "流光：动态星空与玻璃卡片效果。"
        case .pure:
            return "纯净：去除动态与玻璃效果，保持简洁。"
        case .custom:
            return "当前已启用自定义主题，可在“自定义”选项卡中调整背景图片裁切。"
        }
    }

    private func syncThemeEditorStateFromPreferences() {
        selectedTab = model.preferences.interfaceTheme == .custom ? .custom : .builtIn
        cropScale = model.preferences.customThemeScale
        cropOffsetX = model.preferences.customThemeOffsetX
        cropOffsetY = model.preferences.customThemeOffsetY
        previewImage = CustomThemeBackgroundImageStore.loadImage(named: model.preferences.customThemeImageName)
    }

    private func persistCropTransform() {
        model.preferences.customThemeScale = min(max(cropScale, 1.0), 4.0)
        model.preferences.customThemeOffsetX = min(max(cropOffsetX, -1.0), 1.0)
        model.preferences.customThemeOffsetY = min(max(cropOffsetY, -1.0), 1.0)
    }

    @MainActor
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                uploadErrorText = "未读取到图片数据，请重试。"
                return
            }

            let oldImageName = model.preferences.customThemeImageName
            let newImageName = try CustomThemeBackgroundImageStore.saveImageData(data, replacing: oldImageName)

            model.preferences.customThemeImageName = newImageName
            model.preferences.customThemeScale = cropScale
            model.preferences.customThemeOffsetX = cropOffsetX
            model.preferences.customThemeOffsetY = cropOffsetY
            model.preferences.interfaceTheme = .custom

            previewImage = CustomThemeBackgroundImageStore.loadImage(named: newImageName)
            uploadErrorText = nil
        } catch {
            uploadErrorText = "上传失败：\(error.localizedDescription)"
        }
    }

    private func removeCustomThemeImage() {
        CustomThemeBackgroundImageStore.removeImage(named: model.preferences.customThemeImageName)
        model.preferences.customThemeImageName = nil
        previewImage = nil

        if model.preferences.interfaceTheme == .custom {
            model.preferences.interfaceTheme = .pure
            selectedTab = .builtIn
        }

        uploadErrorText = nil
    }
}

private enum ThemeSettingsTab: String, CaseIterable, Identifiable {
    case builtIn
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtIn:
            "内置"
        case .custom:
            "自定义"
        }
    }
}

private struct CustomThemeCropPreview: View {
    let image: UIImage
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedScale = min(max(scale, 1.0), 4.0)
            let clampedOffsetX = min(max(offsetX, -1.0), 1.0)
            let clampedOffsetY = min(max(offsetY, -1.0), 1.0)
            let x = clampedOffsetX * proxy.size.width * 0.35
            let y = clampedOffsetY * proxy.size.height * 0.35

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(clampedScale)
                    .offset(x: x, y: y)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(height: 220)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
    }
}

private struct SettingsEntryRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct iOSCalendarSettingsDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            Section("统计日历") {
                if model.authorizationState != .authorized {
                    Text(calendarAuthorizationMessage)
                        .foregroundStyle(.secondary)

                    if model.authorizationState == .notDetermined {
                        Button("允许访问日历") {
                            Task { await model.requestAccessIfNeeded() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if model.availableCalendars.isEmpty {
                    Text("当前没有可用日历。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.availableCalendars) { calendar in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: calendar.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(calendar.name)
                                    .font(.headline)
                            }

                            Toggle("参与统计", isOn: statsBinding(for: calendar))

                            Toggle("参与 AI 复盘", isOn: reviewBinding(for: calendar))
                                .disabled(!calendar.isSelected)

                            Text(calendar.isSelected ? "关闭后该日历仍计入统计，但不会传给 AI 复盘。" : "先开启参与统计，才能配置是否参与复盘。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("统计日历")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statsBinding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { isSelected in
                guard isSelected != calendar.isSelected else { return }
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }

    private func reviewBinding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isIncludedInReview },
            set: { isIncludedInReview in
                guard isIncludedInReview != calendar.isIncludedInReview else { return }
                Task {
                    await model.setCalendarReviewParticipation(
                        id: calendar.id,
                        isIncludedInReview: isIncludedInReview
                    )
                }
            }
        )
    }

    private var calendarAuthorizationMessage: String {
        switch model.authorizationState {
        case .notDetermined:
            return "请授予日历访问权限，以便 iTime 统计你的时间分布。"
        case .restricted:
            return "系统策略限制了日历访问。"
        case .denied:
            return "日历访问已被拒绝，请到系统设置中重新开启。"
        case .authorized:
            return ""
        }
    }
}

private struct iOSReviewReminderSettingsDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            Section("复盘提醒") {
                Toggle(
                    "启用每日复盘提醒",
                    isOn: Binding(
                        get: { model.preferences.reviewReminderEnabled },
                        set: { isEnabled in
                            Task { await model.updateReviewReminderEnabled(isEnabled) }
                        }
                    )
                )

                DatePicker(
                    "提醒时间",
                    selection: Binding(
                        get: { model.preferences.reviewReminderTime },
                        set: { newTime in
                            Task { await model.updateReviewReminderTime(newTime) }
                        }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .disabled(!model.preferences.reviewReminderEnabled)

                Text(reviewReminderStatusText)
                    .font(.footnote)
                    .foregroundStyle(reviewReminderStatusColor)

                if model.reviewReminderAuthorizationStatus != .authorized {
                    if model.reviewReminderAuthorizationStatus == .denied {
                        Button("打开系统通知设置") {
                            openSystemNotificationSettings()
                        }
                    } else {
                        Button("允许通知") {
                            Task { await model.requestReviewReminderAuthorization() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle("复盘提醒")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reviewReminderStatusText: String {
        switch model.reviewReminderAuthorizationStatus {
        case .authorized:
            return "通知权限已允许。"
        case .notDetermined:
            return "需要通知权限后才能按时提醒。"
        case .denied:
            return "系统通知权限已关闭，请前往系统设置开启。"
        }
    }

    private var reviewReminderStatusColor: Color {
        switch model.reviewReminderAuthorizationStatus {
        case .authorized:
            return .green
        case .notDetermined:
            return .secondary
        case .denied:
            return .red
        }
    }

    private func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct iOSAISettingsDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            Section("默认服务") {
                Picker(
                    "默认服务",
                    selection: Binding(
                        get: { model.defaultAIServiceID ?? model.availableAIServices.first?.id },
                        set: { newID in
                            guard let newID else { return }
                            model.setDefaultAIService(id: newID)
                        }
                    )
                ) {
                    ForEach(model.availableAIServices) { service in
                        Text(service.displayName).tag(Optional(service.id))
                    }
                }
            }

            Section("内置服务") {
                ForEach(model.availableAIServices.filter(\.isBuiltIn)) { service in
                    NavigationLink {
                        iOSAIServiceDetailView(model: model, serviceID: service.id)
                    } label: {
                        AIServiceSummaryRow(
                            service: service,
                            isDefault: service.id == model.defaultAIServiceID
                        )
                    }
                }
            }

            Section("自定义服务") {
                let customServices = model.availableAIServices.filter { !$0.isBuiltIn }
                if customServices.isEmpty {
                    Text("暂无自定义服务")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customServices) { service in
                        NavigationLink {
                            iOSAIServiceDetailView(model: model, serviceID: service.id)
                        } label: {
                            AIServiceSummaryRow(
                                service: service,
                                isDefault: service.id == model.defaultAIServiceID
                            )
                        }
                    }
                }

                Button {
                    _ = model.createCustomAIService()
                } label: {
                    Label("新增自定义服务", systemImage: "plus")
                }
            }
        }
        .navigationTitle("AI 服务")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AIServiceSummaryRow: View {
    let service: AIServiceEndpoint
    let isDefault: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(service.displayName)
                    .foregroundStyle(.primary)
                if isDefault {
                    badge("默认", tint: .accentColor)
                }
                badge(service.isBuiltIn ? "内置" : "自定义", tint: .secondary)
                if !service.isEnabled {
                    badge("已停用", tint: .orange)
                }
            }
            Text(service.providerKind.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct iOSAIServiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel

    let serviceID: UUID

    @State private var apiKey: String = ""
    @State private var modelsText: String = ""

    var body: some View {
        List {
            if let service {
                Section("基础配置") {
                    if service.id != model.defaultAIServiceID {
                        Button("设为默认服务") {
                            model.setDefaultAIService(id: service.id)
                        }
                    }

                    Toggle(
                        "启用此服务",
                        isOn: Binding(
                            get: { service.isEnabled },
                            set: { enabled in
                                updateService(isEnabled: enabled)
                            }
                        )
                    )

                    if service.isBuiltIn {
                        labeledValue(title: "显示名称", value: service.displayName)
                    } else {
                        TextField(
                            "显示名称",
                            text: Binding(
                                get: { service.displayName },
                                set: { updateService(displayName: $0) }
                            )
                        )
                    }

                    labeledValue(title: "服务类型", value: service.providerKind.title)

                    TextField(
                        "Base URL",
                        text: Binding(
                            get: { service.baseURL },
                            set: { updateService(baseURL: $0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.footnote.monospaced())
                        .onChange(of: apiKey) { _, newValue in
                            model.updateAIAPIKey(newValue, for: service.id)
                        }
                }

                Section("模型配置") {
                    TextField("模型列表（逗号分隔）", text: $modelsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: modelsText) { _, newValue in
                            updateService(models: parseModels(from: newValue))
                        }

                    TextField(
                        "默认模型",
                        text: Binding(
                            get: { service.defaultModel },
                            set: { updateService(defaultModel: $0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section("连接") {
                    Button("测试连接") {
                        Task { await model.testAIServiceConnection(service.id) }
                    }

                    if let statusText = connectionStatusText(for: model.aiServiceConnectionState(for: service.id)) {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundStyle(connectionStatusColor(for: model.aiServiceConnectionState(for: service.id)))
                    }
                }

                if !service.isBuiltIn {
                    Section {
                        Button("删除服务", role: .destructive) {
                            model.deleteAIService(id: service.id)
                            dismiss()
                        }
                    }
                }
            } else {
                Section {
                    Text("服务不存在或已删除。")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(service?.displayName ?? "服务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncEditorState()
        }
    }

    private var service: AIServiceEndpoint? {
        model.availableAIServices.first(where: { $0.id == serviceID })
    }

    private func syncEditorState() {
        apiKey = model.loadAIAPIKey(for: serviceID)
        modelsText = service?.models.joined(separator: ", ") ?? ""
    }

    private func labeledValue(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func updateService(
        displayName: String? = nil,
        baseURL: String? = nil,
        models: [String]? = nil,
        defaultModel: String? = nil,
        isEnabled: Bool? = nil
    ) {
        guard let service else { return }
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

    private func connectionStatusText(for state: AIServiceConnectionState) -> String? {
        switch state {
        case .idle:
            return nil
        case .testing:
            return "正在测试连接…"
        case .succeeded(let message), .failed(let message):
            return message
        }
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
}

private struct iOSDeviceSyncSettingsDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            iOSDeviceSyncView(model: model)
        }
        .navigationTitle("设备互传")
        .navigationBarTitleDisplayMode(.inline)
    }
}
