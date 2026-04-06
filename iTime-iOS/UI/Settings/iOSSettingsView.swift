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
    @State private var editorTarget: CustomThemeEditorTarget?

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
        .fullScreenCover(item: $editorTarget) { target in
            CustomThemeFullscreenEditorView(target: target) { result in
                saveEditorResult(result)
            }
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
        Section("我的自定义主题") {
            ThemeSquareGridLayout(columns: 2, spacing: 12) {
                Button {
                    presentNewPresetEditor()
                } label: {
                    SquareThemeTile {
                        AddCustomThemeCard()
                    }
                }
                .buttonStyle(.plain)

                ForEach(model.preferences.customThemePresets) { preset in
                    ThemePresetTile(
                        preset: preset,
                        image: CustomThemeBackgroundImageStore.loadImage(named: preset.imageName),
                        isSelected: model.preferences.selectedCustomThemePresetID == preset.id,
                        onApply: { applyPreset(preset) },
                        onEdit: { presentEditor(for: preset) },
                        onDelete: { deletePreset(preset) }
                    )
                }
            }
            .padding(.vertical, 2)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
    }

    private func presentNewPresetEditor() {
        editorTarget = CustomThemeEditorTarget(
            presetID: nil,
            displayName: defaultThemeName,
            originalImageName: nil,
            imageName: nil,
            scale: 1.12,
            offsetX: 0,
            offsetY: 0
        )
    }

    private func presentEditor(for preset: CustomThemePreset) {
        editorTarget = CustomThemeEditorTarget(
            presetID: preset.id,
            displayName: preset.displayName,
            originalImageName: preset.imageName,
            imageName: preset.imageName,
            scale: preset.scale,
            offsetX: preset.offsetX,
            offsetY: preset.offsetY
        )
    }

    private func applyPreset(_ preset: CustomThemePreset) {
        model.preferences.applyCustomThemePreset(id: preset.id)
    }

    private func deletePreset(_ preset: CustomThemePreset) {
        guard let removedPreset = model.preferences.removeCustomThemePreset(id: preset.id) else { return }
        if !model.preferences.customThemePresets.contains(where: { $0.imageName == removedPreset.imageName }) {
            CustomThemeBackgroundImageStore.removeImage(named: removedPreset.imageName)
        }
    }

    private func saveEditorResult(_ result: CustomThemeEditorResult) {
        let previousImageName: String?
        if let presetID = result.presetID,
           let existingPreset = model.preferences.customThemePresets.first(where: { $0.id == presetID }) {
            previousImageName = existingPreset.imageName
        } else {
            previousImageName = nil
        }

        _ = model.preferences.saveCustomThemePreset(
            id: result.presetID,
            displayName: result.displayName,
            imageName: result.imageName,
            scale: result.scale,
            offsetX: result.offsetX,
            offsetY: result.offsetY
        )

        if let previousImageName,
           previousImageName != result.imageName,
           !model.preferences.customThemePresets.contains(where: { $0.imageName == previousImageName }) {
            CustomThemeBackgroundImageStore.removeImage(named: previousImageName)
        }
    }

    private var defaultThemeName: String {
        "我的主题 \(model.preferences.customThemePresets.count + 1)"
    }
}

private struct ThemeSquareGridLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? 320
        let safeColumns = max(columns, 1)
        let squareSide = max((availableWidth - CGFloat(safeColumns - 1) * spacing) / CGFloat(safeColumns), 0)
        let rowCount = Int(ceil(Double(subviews.count) / Double(safeColumns)))
        let totalHeight = CGFloat(rowCount) * squareSide + CGFloat(max(rowCount - 1, 0)) * spacing
        return CGSize(width: availableWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let safeColumns = max(columns, 1)
        let squareSide = max((bounds.width - CGFloat(safeColumns - 1) * spacing) / CGFloat(safeColumns), 0)

        for index in subviews.indices {
            let row = index / safeColumns
            let column = index % safeColumns
            let x = bounds.minX + CGFloat(column) * (squareSide + spacing)
            let y = bounds.minY + CGFloat(row) * (squareSide + spacing)
            subviews[index].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: squareSide, height: squareSide)
            )
        }
    }
}

private struct SquareThemeTile<Content: View>: View {
    var isSelected: Bool = false
    @ViewBuilder let content: Content
    private let cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                content
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct ThemePresetTile: View {
    let preset: CustomThemePreset
    let image: UIImage?
    let isSelected: Bool
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SquareThemeTile(isSelected: isSelected) {
            CustomThemePresetCard(
                preset: preset,
                image: image,
                isSelected: isSelected
            )
        }
        .onTapGesture {
            onApply()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "slider.horizontal.3")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

private struct AddCustomThemeCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [5]))
                }

            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                Text("新增主题")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CustomThemePresetCard: View {
    let preset: CustomThemePreset
    let image: UIImage?
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.12))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(preset.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CustomThemeEditorTarget: Identifiable {
    let id = UUID()
    let presetID: UUID?
    let displayName: String
    let originalImageName: String?
    let imageName: String?
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}

private struct CustomThemeEditorResult {
    let presetID: UUID?
    let displayName: String
    let imageName: String
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}

private struct CustomThemeFullscreenEditorView: View {
    let target: CustomThemeEditorTarget
    let onSave: (CustomThemeEditorResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var draftImageName: String?
    @State private var previewImage: UIImage?
    @State private var cropScale: Double
    @State private var cropOffsetX: Double
    @State private var cropOffsetY: Double
    @State private var transientImageNames: Set<String> = []
    @State private var uploadErrorMessage: String?
    @State private var showUploadError = false

    init(target: CustomThemeEditorTarget, onSave: @escaping (CustomThemeEditorResult) -> Void) {
        self.target = target
        self.onSave = onSave
        _draftImageName = State(initialValue: target.imageName)
        _previewImage = State(initialValue: CustomThemeBackgroundImageStore.loadImage(named: target.imageName))
        _cropScale = State(initialValue: target.scale)
        _cropOffsetX = State(initialValue: target.offsetX)
        _cropOffsetY = State(initialValue: target.offsetY)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let previewImage {
                CustomThemeFullscreenCropper(
                    image: previewImage,
                    scale: $cropScale,
                    offsetX: $cropOffsetX,
                    offsetY: $cropOffsetY
                )
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .top) {
            topBar
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await handlePhotoSelection(item) }
        }
        .task {
            if draftImageName == nil {
                isPhotoPickerPresented = true
            }
        }
        .alert("图片加载失败", isPresented: $showUploadError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(uploadErrorMessage ?? "请重试")
        }
    }

    private var topBar: some View {
        HStack {
            Button("退出") {
                cancelAndDismiss()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button("保存") {
                saveAndDismiss()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .disabled(draftImageName == nil)
            .opacity(draftImageName == nil ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        HStack(spacing: 14) {
            Button {
                isPhotoPickerPresented = true
            } label: {
                Image(systemName: "photo")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())

            Button {
                cropScale = 1.12
                cropOffsetX = 0
                cropOffsetY = 0
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
            .disabled(previewImage == nil)
            .opacity(previewImage == nil ? 0.5 : 1)
        }
        .padding(.bottom, 12)
    }

    private func cancelAndDismiss() {
        cleanupTransientImages(keeping: target.originalImageName)
        dismiss()
    }

    private func saveAndDismiss() {
        guard let draftImageName else { return }

        onSave(
            CustomThemeEditorResult(
                presetID: target.presetID,
                displayName: target.displayName,
                imageName: draftImageName,
                scale: cropScale,
                offsetX: cropOffsetX,
                offsetY: cropOffsetY
            )
        )
        cleanupTransientImages(keeping: draftImageName)
        dismiss()
    }

    @MainActor
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }

            let oldDraftImageName = draftImageName
            let newImageName = try CustomThemeBackgroundImageStore.saveImageData(data, replacing: nil)

            if let oldDraftImageName, transientImageNames.contains(oldDraftImageName), oldDraftImageName != newImageName {
                CustomThemeBackgroundImageStore.removeImage(named: oldDraftImageName)
                transientImageNames.remove(oldDraftImageName)
            }

            if newImageName != target.originalImageName {
                transientImageNames.insert(newImageName)
            }

            draftImageName = newImageName
            previewImage = CustomThemeBackgroundImageStore.loadImage(named: newImageName)
        } catch {
            uploadErrorMessage = error.localizedDescription
            showUploadError = true
        }
    }

    private func cleanupTransientImages(keeping imageName: String?) {
        for name in transientImageNames where name != imageName {
            CustomThemeBackgroundImageStore.removeImage(named: name)
        }
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

private struct CustomThemeFullscreenCropper: View {
    let image: UIImage
    @Binding var scale: Double
    @Binding var offsetX: Double
    @Binding var offsetY: Double

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let transientScale = CustomThemeCropMath.clampedScale(scale * Double(pinchScale))
            let maxTranslation = CustomThemeCropMath.maxTranslation(
                containerSize: proxy.size,
                imageSize: image.size,
                scale: transientScale
            )
            let transientOffsetX = resolvedOffsetX(
                dragWidth: dragTranslation.width,
                maxTranslationWidth: maxTranslation.width
            )
            let transientOffsetY = resolvedOffsetY(
                dragHeight: dragTranslation.height,
                maxTranslationHeight: maxTranslation.height
            )
            let translation = CustomThemeCropMath.translation(
                containerSize: proxy.size,
                imageSize: image.size,
                scale: transientScale,
                offsetX: transientOffsetX,
                offsetY: transientOffsetY
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(transientScale)
                    .offset(x: translation.width, y: translation.height)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Color.black.opacity(0.08)

                CropRuleOfThirdsGrid()
            }
            .highPriorityGesture(cropGesture(in: proxy.size))
            .onTapGesture(count: 2) {
                scale = 1.12
                offsetX = 0
                offsetY = 0
            }
        }
        .ignoresSafeArea()
    }

    private func cropGesture(in containerSize: CGSize) -> some Gesture {
        let drag = DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let maxTranslation = CustomThemeCropMath.maxTranslation(
                    containerSize: containerSize,
                    imageSize: image.size,
                    scale: scale
                )

                if maxTranslation.width > 0 {
                    let deltaX = Double(value.translation.width / maxTranslation.width)
                    offsetX = CustomThemeCropMath.clampedOffset(offsetX + deltaX)
                }

                if maxTranslation.height > 0 {
                    let deltaY = Double(value.translation.height / maxTranslation.height)
                    offsetY = CustomThemeCropMath.clampedOffset(offsetY + deltaY)
                }
            }

        let pinch = MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale = CustomThemeCropMath.clampedScale(scale * value)
            }

        return drag.simultaneously(with: pinch)
    }

    private func resolvedOffsetX(dragWidth: CGFloat, maxTranslationWidth: CGFloat) -> Double {
        guard maxTranslationWidth > 0 else { return 0 }
        let delta = Double(dragWidth / maxTranslationWidth)
        return CustomThemeCropMath.clampedOffset(offsetX + delta)
    }

    private func resolvedOffsetY(dragHeight: CGFloat, maxTranslationHeight: CGFloat) -> Double {
        guard maxTranslationHeight > 0 else { return 0 }
        let delta = Double(dragHeight / maxTranslationHeight)
        return CustomThemeCropMath.clampedOffset(offsetY + delta)
    }
}

private struct CropRuleOfThirdsGrid: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            Path { path in
                path.move(to: CGPoint(x: w / 3, y: 0))
                path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                path.addLine(to: CGPoint(x: 2 * w / 3, y: h))

                path.move(to: CGPoint(x: 0, y: h / 3))
                path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
            }
            .stroke(.white.opacity(0.35), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
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
