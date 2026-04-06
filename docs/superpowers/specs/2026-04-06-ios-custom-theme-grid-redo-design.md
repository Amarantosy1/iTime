# iOS 自定义主题网格重做 — 设计文档

**日期：** 2026-04-06  
**范围：** `iOSSettingsView.swift`（UI 层）、`UserPreferences.swift`（持久化层）、相关测试文件

---

## 背景与问题

现有自定义主题网格存在三个问题：

1. **容器未裁切**：`SquareThemeTile` 缺少 `.clipShape`，仅有 `.contentShape`（仅影响命中区域）。图片使用 `scaledToFill()` 会溢出圆角边界，渐变层同样不受约束。
2. **长按菜单归属错误**：自定义主题网格嵌套在 `List` 的 `Section` 里，iOS 的 `.contextMenu` 以整个 List row 作为预览容器，弹出的是底层 row 而非方块本身。
3. **displayName 残留**：`CustomThemePresetCard` 仍渲染 `Text(preset.displayName)`；`CustomThemeEditorTarget`/`CustomThemeEditorResult` 仍携带 `displayName: String` 字段；持久化模型 `CustomThemePreset` 仍有该字段。

---

## 方案选择

采用**条件切换**方案：内置主题保持现有 `List` 结构不变；切换到自定义选项卡时，整体替换为 `ScrollView + LazyVGrid`，彻底脱离 List row 的 gesture/contextMenu 系统。

---

## 设计

### 1. 整体结构（`iOSThemeSettingsDetailView`）

```
ZStack {
    iOSThemeBackground(...)           // 背景不变

    VStack(spacing: 0) {
        // 分段选择器从 List Section 里提出，放顶部统一可见
        Picker("主题类型", selection: $selectedTab) { ... }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

        if selectedTab == .builtIn {
            // 完全不变，保留现有 List { builtInThemeSection }
            List { builtInThemeSection }.magazineGlassList(...)
        } else {
            // 新增
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    AddThemeTile { presentNewPresetEditor() }  // 第一格固定
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
}
```

### 2. 方块视图（`CustomThemePresetTile`）

替换现有 `ThemePresetTile` + `SquareThemeTile` + `CustomThemePresetCard` 三层结构，合并为单一视图：

```swift
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
        // clipShape 在 overlay 之前，裁切图片与渐变，不影响描边
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
            // 显式 preview，彻底脱离 List row preview 逻辑
            ZStack {
                Color.secondary.opacity(0.12)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        })
    }
}
```

关键点：
- `.clipShape` 确保所有内容裁切到圆角内
- `.overlay` 的选中描边在 clipShape 之外，不被裁切
- `.contextMenu(menuItems:preview:)` 显式声明 160pt 方块预览，不依赖 List row
- 无任何文字层

### 3. 新增方块（`AddThemeTile`）

独立 View，固定在网格第一格：

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
                            .stroke(Color.secondary.opacity(0.28),
                                    style: StrokeStyle(lineWidth: 1, dash: [5]))
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
```

### 4. 数据模型清理

**`CustomThemePreset`（`UserPreferences.swift`）：**
- 移除 `displayName` 属性
- 添加显式 `CodingKeys`（含 `displayName` key）
- 自定义 `init(from:)` 使用 `decodeIfPresent` 读取并丢弃旧 `displayName` 字段，保持旧 JSON 数据可正常解码
- 自定义 `encode(to:)` 不写入 `displayName`
- `saveCustomThemePreset` 签名移除 `displayName:` 参数

**`CustomThemeEditorTarget` / `CustomThemeEditorResult`（UI 层）：**
- 移除 `displayName: String`
- `presentNewPresetEditor()` 移除 `displayName:` 传参
- `presentEditor(for:)` 移除 `displayName:` 传参（`preset.displayName` 不再存在）
- `saveEditorResult(_:)` 移除 `displayName:` 传参
- 移除 `defaultThemeName` 计算属性

**`CustomThemeFullscreenEditorView`（编辑器）：**
- `saveAndDismiss()` 构造 `CustomThemeEditorResult` 时移除 `displayName:` 参数

### 5. 移除的视图

以下视图在重做后不再需要，可删除：
- `ThemeSquareGridLayout`（自定义 Layout，改用 `LazyVGrid`）
- `SquareThemeTile`（合并进 `CustomThemePresetTile`）
- `ThemePresetTile`（合并进 `CustomThemePresetTile`）
- `CustomThemePresetCard`（合并进 `CustomThemePresetTile`）
- `AddCustomThemeCard`（替换为 `AddThemeTile`）

---

## 测试范围

- `UserPreferencesTests`：更新 `saveCustomThemePreset` 调用（移除 `displayName` 参数）；保留"旧 JSON 含 displayName 仍可解码"回归用例（已在上一版计划中添加）
- `SyncPersistenceAdapterTests`：更新 `CustomThemePreset` 构造调用（移除 `displayName` 参数）
- iOS 构建：`xcodebuild` 验证无编译错误

---

## 不在范围内

- 编辑器（`CustomThemeFullscreenEditorView`）的功能逻辑不变，仅移除 `displayName` 数据传递
- 内置主题 Picker 的展示逻辑完全不变
- macOS 端代码不涉及
