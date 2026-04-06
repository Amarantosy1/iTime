# iOS 自定义主题网格重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重做自定义主题网格：圆角容器严格裁切、长按菜单归属于方块自身、彻底移除 `displayName` 属性。

**Architecture:** TDD 优先锁定数据层 API，再切 UI 层。数据层：移除 `CustomThemePreset.displayName`，用自定义 Codable 兼容旧 JSON。UI 层：`iOSThemeSettingsDetailView` 改为 VStack 顶部 Picker + 条件分支（内置 List / 自定义 ScrollView+LazyVGrid），新增合并后的 `CustomThemePresetTile` 和 `AddThemeTile`，删除旧的 `ThemeSquareGridLayout`、`SquareThemeTile`、`ThemePresetTile`、`CustomThemePresetCard`、`AddCustomThemeCard`。

**Tech Stack:** Swift 6, SwiftUI, Observation, UserDefaults Codable, Swift Testing (`@Test`)

---

## File Map

| 操作 | 文件 | 职责 |
|------|------|------|
| Modify | `Sources/iTime/Support/Persistence/UserPreferences.swift` | 移除 `CustomThemePreset.displayName`、自定义 Codable、更新 `saveCustomThemePreset` 签名与 legacy init 路径 |
| Modify | `Tests/iTimeTests/UserPreferencesTests.swift` | 更新 `saveCustomThemePreset` 调用（去掉 `displayName`），新增旧 JSON 兼容回归用例 |
| Modify | `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift` | 更新 `CustomThemePreset` 初始化（去掉 `displayName`） |
| Modify | `iTime-iOS/UI/Settings/iOSSettingsView.swift` | 重构主题网格 UI：条件切换结构、新增两个 Tile 视图、删除旧五个视图、清理 editor 数据流 |

---

### Task 1: 写失败测试锁定数据层目标

**Files:**
- Modify: `Tests/iTimeTests/UserPreferencesTests.swift`
- Modify: `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift`

- [ ] **Step 1: 更新 `customThemePresetsPersistAcrossPreferenceInstances` 测试（移除 `displayName:`）**

在 `Tests/iTimeTests/UserPreferencesTests.swift` 中，找到并修改以下两次调用：

```swift
// 原代码 (约第 156 行)
_ = first.saveCustomThemePreset(
    displayName: "晨光",
    imageName: "preset-a.jpg",
    scale: 1.3,
    offsetX: 0.1,
    offsetY: -0.2
)
let secondPresetID = first.saveCustomThemePreset(
    displayName: "夜色",
    imageName: "preset-b.jpg",
    scale: 1.7,
    offsetX: -0.25,
    offsetY: 0.3
)
```

改为：

```swift
_ = first.saveCustomThemePreset(
    imageName: "preset-a.jpg",
    scale: 1.3,
    offsetX: 0.1,
    offsetY: -0.2
)
let secondPresetID = first.saveCustomThemePreset(
    imageName: "preset-b.jpg",
    scale: 1.7,
    offsetX: -0.25,
    offsetY: 0.3
)
```

- [ ] **Step 2: 更新 `applyingCustomThemePresetUpdatesActiveCropFields` 测试（移除 `displayName:`）**

同文件，找到并修改：

```swift
// 原代码 (约第 182 行)
let firstPresetID = preferences.saveCustomThemePreset(
    displayName: "主题 A",
    imageName: "theme-a.jpg",
    scale: 1.2,
    offsetX: 0.2,
    offsetY: -0.1
)
_ = preferences.saveCustomThemePreset(
    displayName: "主题 B",
    imageName: "theme-b.jpg",
    scale: 1.8,
    offsetX: -0.3,
    offsetY: 0.4
)
```

改为：

```swift
let firstPresetID = preferences.saveCustomThemePreset(
    imageName: "theme-a.jpg",
    scale: 1.2,
    offsetX: 0.2,
    offsetY: -0.1
)
_ = preferences.saveCustomThemePreset(
    imageName: "theme-b.jpg",
    scale: 1.8,
    offsetX: -0.3,
    offsetY: 0.4
)
```

- [ ] **Step 3: 在 `UserPreferencesTests.swift` 末尾新增旧 JSON 兼容用例**

在文件末尾（所有现有 `@Test` 之后）追加：

```swift
@Test func customThemePresetLegacyPayloadWithDisplayNameStillDecodes() throws {
    let suite = "iTime.tests.custom-theme-legacy-display-name"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    let legacyJSON = """
    [
      {
        "id": "11111111-1111-1111-1111-111111111111",
        "displayName": "旧主题名",
        "imageName": "legacy-theme.jpg",
        "scale": 1.4,
        "offsetX": 0.2,
        "offsetY": -0.1,
        "createdAt": 765705600,
        "updatedAt": 765707400
      }
    ]
    """.data(using: .utf8)!

    defaults.set(legacyJSON, forKey: "customThemePresets")

    let preferences = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(preferences.customThemePresets.count == 1)
    #expect(preferences.customThemePresets.first?.imageName == "legacy-theme.jpg")
    #expect(preferences.customThemePresets.first?.scale == 1.4)
}
```

- [ ] **Step 4: 更新 `SyncPersistenceAdapterTests.swift` 中 `makePatchFixture` 的 `CustomThemePreset` 初始化（移除 `displayName:`）**

在 `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift` 中，找到 `makePatchFixture` 函数（约第 63 行），将两个 `CustomThemePreset(...)` 改为：

```swift
let remotePresets = [
    CustomThemePreset(
        id: presetAID,
        imageName: "custom-theme-sync-a.jpg",
        scale: 1.4,
        offsetX: -0.1,
        offsetY: 0.15,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_060)
    ),
    CustomThemePreset(
        id: presetBID,
        imageName: "custom-theme-sync.jpg",
        scale: 1.6,
        offsetX: -0.2,
        offsetY: 0.28,
        createdAt: Date(timeIntervalSince1970: 1_700_000_100),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_200)
    )
]
```

- [ ] **Step 5: 运行测试确认失败**

```bash
swift test --filter iTimeTests.UserPreferencesTests
```

Expected: 编译失败，错误为 `displayName` 参数不匹配。证明测试先于实现。

- [ ] **Step 6: Commit（仅测试变更）**

```bash
git add Tests/iTimeTests/UserPreferencesTests.swift Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift
git commit -m "test: target displayName-free saveCustomThemePreset API and add legacy JSON compat coverage"
```

---

### Task 2: 移除 `CustomThemePreset.displayName`，实现兼容解码

**Files:**
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`

- [ ] **Step 1: 替换 `CustomThemePreset` 结构体（约第 33–62 行）**

将现有 struct 全部替换为：

```swift
public struct CustomThemePreset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var imageName: String
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        imageName: String,
        scale: Double,
        offsetX: Double,
        offsetY: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.imageName = imageName
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, imageName, scale, offsetX, offsetY, createdAt, updatedAt, displayName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageName = try container.decode(String.self, forKey: .imageName)
        scale = try container.decode(Double.self, forKey: .scale)
        offsetX = try container.decode(Double.self, forKey: .offsetX)
        offsetY = try container.decode(Double.self, forKey: .offsetY)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        _ = try container.decodeIfPresent(String.self, forKey: .displayName) // 兼容旧字段，忽略值
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageName, forKey: .imageName)
        try container.encode(scale, forKey: .scale)
        try container.encode(offsetX, forKey: .offsetX)
        try container.encode(offsetY, forKey: .offsetY)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
```

- [ ] **Step 2: 更新 legacy init 路径（约第 338–350 行）**

找到以下代码并替换：

```swift
// 原代码
let now = Date()
initialCustomThemePresets = [
    CustomThemePreset(
        id: UUID(),
        displayName: "我的主题",
        imageName: legacyImageName,
        scale: storedCustomThemeScale,
        offsetX: storedCustomThemeOffsetX,
        offsetY: storedCustomThemeOffsetY,
        createdAt: now,
        updatedAt: now
    )
]
```

改为：

```swift
let now = Date()
initialCustomThemePresets = [
    CustomThemePreset(
        id: UUID(),
        imageName: legacyImageName,
        scale: storedCustomThemeScale,
        offsetX: storedCustomThemeOffsetX,
        offsetY: storedCustomThemeOffsetY,
        createdAt: now,
        updatedAt: now
    )
]
```

- [ ] **Step 3: 替换 `saveCustomThemePreset` 函数（约第 557–611 行）**

将整个函数替换为：

```swift
@discardableResult
public func saveCustomThemePreset(
    id: UUID? = nil,
    imageName: String,
    scale: Double,
    offsetX: Double,
    offsetY: Double
) -> UUID {
    let now = Date()
    let clampedScale = Self.clampCustomThemeScale(scale)
    let clampedOffsetX = Self.clampCustomThemeOffset(offsetX)
    let clampedOffsetY = Self.clampCustomThemeOffset(offsetY)

    let resolvedID: UUID
    if let id, let index = customThemePresets.firstIndex(where: { $0.id == id }) {
        let createdAt = customThemePresets[index].createdAt
        customThemePresets[index] = CustomThemePreset(
            id: id,
            imageName: imageName,
            scale: clampedScale,
            offsetX: clampedOffsetX,
            offsetY: clampedOffsetY,
            createdAt: createdAt,
            updatedAt: now
        )
        resolvedID = id
    } else {
        let newID = id ?? UUID()
        customThemePresets.append(
            CustomThemePreset(
                id: newID,
                imageName: imageName,
                scale: clampedScale,
                offsetX: clampedOffsetX,
                offsetY: clampedOffsetY,
                createdAt: now,
                updatedAt: now
            )
        )
        resolvedID = newID
    }

    customThemePresets.sort { $0.updatedAt > $1.updatedAt }
    selectedCustomThemePresetID = resolvedID
    customThemeImageName = imageName
    customThemeScale = clampedScale
    customThemeOffsetX = clampedOffsetX
    customThemeOffsetY = clampedOffsetY
    interfaceTheme = .custom
    return resolvedID
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter iTimeTests.UserPreferencesTests
swift test --filter iTimeTests.SyncPersistenceAdapterTests
```

Expected: 全部 PASS，包含新增的 `customThemePresetLegacyPayloadWithDisplayNameStillDecodes`。

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Support/Persistence/UserPreferences.swift
git commit -m "refactor: remove displayName from CustomThemePreset with backward-compat decode"
```

---

### Task 3: 重构 iOS 主题网格 UI

**Files:**
- Modify: `iTime-iOS/UI/Settings/iOSSettingsView.swift`

- [ ] **Step 1: 替换 `iOSThemeSettingsDetailView.body`**

找到 `private struct iOSThemeSettingsDetailView: View` 中的 `var body: some View`，将整个 `body` 替换为：

```swift
var body: some View {
    VStack(spacing: 0) {
        Picker("主题类型", selection: $selectedTab) {
            ForEach(ThemeSettingsTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        if selectedTab == .builtIn {
            List {
                builtInThemeSection
            }
            .magazineGlassList(theme: model.preferences.interfaceTheme)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    AddThemeTile {
                        presentNewPresetEditor()
                    }
                    ForEach(model.preferences.customThemePresets) { preset in
                        CustomThemePresetTile(
                            preset: preset,
                            image: CustomThemeBackgroundImageStore.loadImage(named: preset.imageName),
                            isSelected: model.preferences.selectedCustomThemePresetID == preset.id,
                            onApply: { applyPreset(preset) },
                            onEdit: { presentEditor(for: preset) },
                            onDelete: { deletePreset(preset) }
                        )
                    }
                }
                .padding(16)
            }
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
```

- [ ] **Step 2: 删除旧的 `customThemeSection` 计算属性和 `defaultThemeName` 计算属性**

找到并删除以下两个计算属性（在 `iOSThemeSettingsDetailView` 内）：

```swift
private var customThemeSection: some View { ... }     // 整个属性删除

private var defaultThemeName: String { ... }           // 整个属性删除
```

- [ ] **Step 3: 替换 `CustomThemeEditorTarget` 结构体**

找到：
```swift
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
```

替换为：

```swift
private struct CustomThemeEditorTarget: Identifiable {
    let id = UUID()
    let presetID: UUID?
    let originalImageName: String?
    let imageName: String?
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}
```

- [ ] **Step 4: 替换 `CustomThemeEditorResult` 结构体**

找到：
```swift
private struct CustomThemeEditorResult {
    let presetID: UUID?
    let displayName: String
    let imageName: String
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}
```

替换为：

```swift
private struct CustomThemeEditorResult {
    let presetID: UUID?
    let imageName: String
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}
```

- [ ] **Step 5: 替换 `presentNewPresetEditor()` 方法**

找到：
```swift
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
```

替换为：

```swift
private func presentNewPresetEditor() {
    editorTarget = CustomThemeEditorTarget(
        presetID: nil,
        originalImageName: nil,
        imageName: nil,
        scale: 1.12,
        offsetX: 0,
        offsetY: 0
    )
}
```

- [ ] **Step 6: 替换 `presentEditor(for:)` 方法**

找到：
```swift
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
```

替换为：

```swift
private func presentEditor(for preset: CustomThemePreset) {
    editorTarget = CustomThemeEditorTarget(
        presetID: preset.id,
        originalImageName: preset.imageName,
        imageName: preset.imageName,
        scale: preset.scale,
        offsetX: preset.offsetX,
        offsetY: preset.offsetY
    )
}
```

- [ ] **Step 7: 替换 `saveEditorResult(_:)` 方法**

找到：
```swift
private func saveEditorResult(_ result: CustomThemeEditorResult) {
    ...
    _ = model.preferences.saveCustomThemePreset(
        id: result.presetID,
        displayName: result.displayName,
        imageName: result.imageName,
        scale: result.scale,
        offsetX: result.offsetX,
        offsetY: result.offsetY
    )
    ...
}
```

替换为（保留前后的 `previousImageName` 逻辑不变，只改 `saveCustomThemePreset` 调用）：

```swift
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
```

- [ ] **Step 8: 更新 `CustomThemeFullscreenEditorView.saveAndDismiss()`**

找到：
```swift
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
```

替换为：

```swift
private func saveAndDismiss() {
    guard let draftImageName else { return }

    onSave(
        CustomThemeEditorResult(
            presetID: target.presetID,
            imageName: draftImageName,
            scale: cropScale,
            offsetX: cropOffsetX,
            offsetY: cropOffsetY
        )
    )
    cleanupTransientImages(keeping: draftImageName)
    dismiss()
}
```

- [ ] **Step 9: 删除五个旧视图（整个 struct 定义全部删除）**

删除以下五个 `private struct`：
- `ThemeSquareGridLayout: Layout`（自定义 Layout，约 307–336 行区域）
- `SquareThemeTile: View`（约 338–356 行区域）
- `ThemePresetTile: View`（约 358–391 行区域）
- `AddCustomThemeCard: View`（约 393–413 行区域）
- `CustomThemePresetCard: View`（约 415–452 行区域）

- [ ] **Step 10: 在旧视图位置新增 `AddThemeTile` 和 `CustomThemePresetTile`**

在删除旧视图后，在同一位置插入：

```swift
private struct AddThemeTile: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                Color.secondary.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1, dash: [5])
                            )
                    }
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                    Text("新增主题")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CustomThemePresetTile: View {
    let preset: CustomThemePreset
    let image: UIImage?
    let isSelected: Bool
    let onApply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            LinearGradient(
                colors: [.clear, .black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { onApply() }
        .contextMenu(menuItems: {
            Button { onEdit() } label: {
                Label("编辑", systemImage: "slider.horizontal.3")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("删除", systemImage: "trash")
            }
        }, preview: {
            ZStack {
                Color.secondary.opacity(0.12)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        })
    }
}
```

- [ ] **Step 11: iOS 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'generic/platform=iOS' build 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`，无编译错误。

- [ ] **Step 12: 运行全量测试**

```bash
swift test
```

Expected: 全部 PASS。

- [ ] **Step 13: Commit**

```bash
git add iTime-iOS/UI/Settings/iOSSettingsView.swift
git commit -m "feat(ios): redo custom theme grid with clipped tiles, per-tile context menu, and no displayName"
```

---

### Task 4: 手工验收

- [ ] **Step 1: 在 iOS 模拟器/真机上验收**

```text
1. 设置 → 主题 → 切换到"自定义"选项卡
2. 确认第一格是"+"新增方块（虚线边框）
3. 点击"+"，进入编辑器选一张图片，保存
4. 确认方块：仅显示图片，无底部文字，圆角边界内无溢出
5. 长按方块：确认弹出的预览是方块本身（160pt 圆角正方形），不是底层整行容器
6. 弹出菜单选"编辑"，修改裁切后保存，确认方块更新
7. 弹出菜单选"删除"，确认方块消失
8. 切换到"内置"选项卡，确认内置主题 Picker 展示正常
9. 重启 App，确认自定义预设仍可读取（数据持久化正常）
```
