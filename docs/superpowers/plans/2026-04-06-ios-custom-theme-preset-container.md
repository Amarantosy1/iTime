# iOS 自定义主题方块容器重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 iOS 设置页把自定义主题方块改为严格圆角容器承接、点击即应用、长按同容器弹编辑/删除，并从数据模型中移除 `displayName` 且保持旧数据可读。

**Architecture:** UI 层在 `iOSSettingsView.swift` 内新增统一方块容器并收敛交互到容器本身，保证视觉裁切与命中区域一致。数据层在 `UserPreferences.swift` 精简 `CustomThemePreset` 结构和 `saveCustomThemePreset` API，同时通过兼容解码与回归测试保障旧持久化数据和同步载荷不受破坏。测试优先覆盖持久化与同步路径，再完成 UI 调整与手工验收。

**Tech Stack:** Swift 6, SwiftUI, Observation, UserDefaults Codable persistence, Swift Testing (`@Test`)

---

## File Map

| 操作 | 文件 | 职责 |
|------|------|------|
| Modify | `Sources/iTime/Support/Persistence/UserPreferences.swift` | 移除 `CustomThemePreset.displayName`，更新保存 API 与旧数据兼容解码 |
| Modify | `iTime-iOS/UI/Settings/iOSSettingsView.swift` | 主题网格容器重构、点击/长按交互归位、去除主题名称展示与编辑输入依赖 |
| Modify | `Tests/iTimeTests/UserPreferencesTests.swift` | 更新新 API 调用方式，新增“旧数据含 displayName 仍可解码”回归用例 |
| Modify | `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift` | 更新 `CustomThemePreset` 构造调用，验证同步补丁应用不受字段移除影响 |

---

### Task 1: 先写失败测试锁定数据层目标

**Files:**
- Modify: `Tests/iTimeTests/UserPreferencesTests.swift`
- Modify: `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift`

- [ ] **Step 1: 在 `UserPreferencesTests` 增加旧数据兼容解码用例（先失败）**

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

- [ ] **Step 2: 把测试调用切到目标 API（移除 `displayName` 参数）**

将以下调用改成新签名（示例之一）：

```swift
_ = first.saveCustomThemePreset(
    imageName: "preset-a.jpg",
    scale: 1.3,
    offsetX: 0.1,
    offsetY: -0.2
)
```

并在 `SyncPersistenceAdapterTests` 中把 `CustomThemePreset(...)` 初始化改为不传 `displayName`（此时会因生产代码未改而失败）。

- [ ] **Step 3: 运行定向测试确认失败**

Run:

```bash
swift test --filter iTimeTests.UserPreferencesTests
```

Expected: FAIL（编译或测试失败），错误包含 `displayName` 相关签名不匹配，证明测试先于实现。

- [ ] **Step 4: Commit（仅测试变更）**

```bash
git add Tests/iTimeTests/UserPreferencesTests.swift Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift
git commit -m "test: add legacy custom theme preset compatibility coverage"
```

---

### Task 2: 实现 `CustomThemePreset` 无名称化与兼容解码

**Files:**
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Test: `Tests/iTimeTests/UserPreferencesTests.swift`

- [ ] **Step 1: 在模型中移除 `displayName` 并定义显式编码键**

把 `CustomThemePreset` 改为（关键结构如下）：

```swift
public struct CustomThemePreset: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var imageName: String
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case imageName
        case scale
        case offsetX
        case offsetY
        case createdAt
        case updatedAt
        case displayName
    }
}
```

- [ ] **Step 2: 添加自定义 `init(from:)` / `encode(to:)` 保证兼容旧字段**

```swift
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
```

- [ ] **Step 3: 更新 `saveCustomThemePreset` 签名与构造处**

目标签名：

```swift
@discardableResult
public func saveCustomThemePreset(
    id: UUID? = nil,
    imageName: String,
    scale: Double,
    offsetX: Double,
    offsetY: Double
) -> UUID
```

并删除 `normalizedDisplayName` 与默认 `"我的主题"` 逻辑，同时更新所有 `CustomThemePreset(...)` 构造调用（含旧数据兜底分支）。

- [ ] **Step 4: 运行定向测试确认通过**

Run:

```bash
swift test --filter iTimeTests.UserPreferencesTests
swift test --filter iTimeTests.SyncPersistenceAdapterTests
```

Expected: PASS，且新增旧数据兼容用例通过。

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Support/Persistence/UserPreferences.swift Tests/iTimeTests/UserPreferencesTests.swift Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift
git commit -m "refactor: remove custom theme display name from persistence model"
```

---

### Task 3: 重构 iOS 主题网格容器与交互归位

**Files:**
- Modify: `iTime-iOS/UI/Settings/iOSSettingsView.swift`

- [ ] **Step 1: 移除编辑流中的名称字段依赖**

将编辑目标与结果改为仅保留图片与裁切参数（示例）：

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

private struct CustomThemeEditorResult {
    let presetID: UUID?
    let imageName: String
    let scale: Double
    let offsetX: Double
    let offsetY: Double
}
```

并更新 `presentNewPresetEditor`、`presentEditor`、`saveAndDismiss`、`saveEditorResult` 中的入参与赋值。

- [ ] **Step 2: 引入统一主题方块容器并收敛点击/长按**

新增（或重命名）容器视图，确保容器级裁切与命中一致：

```swift
private struct ThemePresetContainer<Content: View>: View {
    let isSelected: Bool
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
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
}
```

`ThemePresetTile` 内将 `onTapGesture` 与 `contextMenu` 都挂在该容器实例上，context menu 保留“编辑/删除”。

- [ ] **Step 3: 去掉方块文字层，只保留图片铺满裁切**

将 `CustomThemePresetCard` 改为不接收 `preset`，且不渲染 `Text(...)`：

```swift
private struct CustomThemePresetCard: View {
    let image: UIImage?

    var body: some View {
        ZStack {
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 4: 运行 iOS 构建验证**

Run:

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'generic/platform=iOS' build
```

Expected: BUILD SUCCEEDED，`iOSSettingsView.swift` 无类型/布局编译错误。

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/UI/Settings/iOSSettingsView.swift
git commit -m "feat(ios): enforce clipped preset container and container-scoped menu"
```

---

### Task 4: 全量回归与验收清单

**Files:**
- No additional code expected

- [ ] **Step 1: 运行完整测试**

Run:

```bash
swift test
```

Expected: PASS（全部测试通过，无 `displayName` 相关回归）。

- [ ] **Step 2: iOS 手工验收主题网格**

在 iOS 端“设置 -> 主题 -> 自定义”执行：

```text
1) 选择任一自定义主题方块：应立即应用
2) 长按同一方块：弹出“编辑/删除”
3) 检查方块：仅显示图片，无底部文字
4) 检查方块圆角边界：内容不越界、不露底层容器
5) 编辑后保存并重启应用：主题预设仍可读取
```

- [ ] **Step 3: 提交最终验收记录（仅当有修复）**

```bash
git add -A
git commit -m "fix(ios): polish custom theme preset container acceptance issues"
```
