# iOS 功能修复设计文档

**日期：** 2026-04-06  
**范围：** 设备互传双向同步修复、iOS 统计图表补全、iOS AI 服务设置、iOS 应用图标

---

## 背景

iOS 目标存在四个已知缺陷：

1. 设备互传显示"同步失败"，Mac 端"开始发现设备"按钮无响应
2. iOS 统计界面过于简单，缺少与 Mac 一致的图表
3. iOS 设置无法开启 AI 服务
4. iOS 应用无图标

---

## Issue 1 — 设备互传双向协议修复

### 根因

| 层级 | 问题 |
|------|------|
| 权限 | iOS Info.plist 缺 `NSLocalNetworkUsageDescription` 和 `NSBonjourServices`，MultipeerConnectivity 无法运行 |
| 权限 | Mac `iTime.entitlements` 为空，缺 `com.apple.security.network.client/server` |
| 协议 | `SyncCoordinator` 只有发起方 `syncNow()`，无响应方实现；对端收到消息后无人处理，直接超时 |

### 设计

#### 权限修复

**iOS（project.pbxproj INFOPLIST keys）：**
```
INFOPLIST_KEY_NSLocalNetworkUsageDescription = "iTime 需要访问局域网以发现附近设备并同步数据。"
INFOPLIST_KEY_NSBonjourServices = ("_itime-sync._tcp", "_itime-sync._udp")
```
两个 build configuration（Debug/Release）都需要加。

**Mac（iTime.entitlements）：**
```xml
<key>com.apple.security.network.client</key><true/>
<key>com.apple.security.network.server</key><true/>
```

#### 协议修复：`SyncCoordinator.startResponding()`

新增方法，在后台持续监听入站消息并承担响应方职责：

```
func startResponding() -> Task<Void, Never>
  loop over transport.incomingMessages()
    on .hello(hello) from peerID:
      send .hello(localHello) back          // 握手回应
      localManifest = adapter.makeManifest()
      send .manifest(localManifest) to peerID
    on .manifest(remoteManifest) from peerID:
      patch = adapter.buildPatch(since: remoteManifest)
      send .patch(patch) to peerID
    on .patch(remotePatch) from peerID:
      adapter.apply(patch: remotePatch)
    on .result(_) from peerID:
      // 同步完成，responder 侧无需额外操作
```

发起方 `syncNow()` 流程不变（已有实现），两端对称运行 responder loop，谁点"立即同步"谁成为发起方。

#### AppModel 修改

- `startDeviceDiscovery()` 内同时启动 `syncCoordinator.startResponding()`，将返回的 Task 存为 `respondingTask`
- `stopDeviceDiscovery()` 取消 `respondingTask`
- `DeviceSyncStatus` 增加 `.responding` case，供 UI 展示"等待同步中"状态
- responder 完成后更新 `lastSyncStatus`（`.succeeded` 或 `.failed`）

#### iOS Sync UI 调整

`iOSDeviceSyncView` 改为双按钮（开始发现 / 停止发现），与 Mac 的 `DeviceSyncSettingsSection` 一致；"立即同步"按钮在 `isSyncing || isResponding` 时禁用。

---

## Issue 2 — iOS 统计图表

### 设计

`iOSOverviewView` 改为 `ScrollView + VStack`，直接复用已有 Mac 组件：

```
NavigationStack
  ScrollView
    RangePicker(selection: rangeBinding, ranges: TimeRangePreset.overviewCases)
    
    if authorizationState == .authorized
      if let overview, !overview.buckets.isEmpty
        OverviewMetricsSection(overview: overview)
        OverviewTrendChartView(overview: overview)
        LiquidGlassCard { OverviewChartView(overview: overview) }
      else
        Text("当前时间范围内没有可统计的日程。")
    else
      AuthorizationStateView(state: authorizationState) { ... }
  .task { await model.refresh() }
  .refreshable { await model.refresh() }
  .navigationTitle("统计")
```

- 所有复用组件（`OverviewMetricsSection`、`OverviewTrendChartView`、`OverviewChartView`、`OverviewBucketTable`、`RangePicker`）已是平台无关 SwiftUI，Charts framework 在 iOS 16+ 可用
- `LiquidGlassCard` 已有 `#available(macOS 26, *)` / `#available(iOS 26, *)` 分支，低版本用 `.ultraThinMaterial`，无需修改
- 删除原有 `formattedHours` 扩展（已有 `TimeInterval+Formatting.swift` 提供 `formattedDuration`）

---

## Issue 3 — iOS AI 服务设置

### 根因

`iOSSettingsView` 中的 AI 服务 Section 只有 Picker 选择当前会话服务，无法启用/禁用服务、无法为未启用服务配置 API Key。

### 设计

AI 服务 Section 改为扁平服务列表：

```
Section("AI 服务")
  ForEach(model.availableAIServices) { service in
    VStack(alignment: .leading, spacing: 8)
      Toggle(service.displayName, isOn: enableBinding(for: service))
      if service.isEnabled
        SecureField("API Key", text: apiKeyBinding(for: service))
          .textContentType(.password)
          .autocorrectionDisabled()
```

绑定实现：
- `enableBinding(for:)` → `get: service.isEnabled`，`set: model.updateAIService(service.updating(isEnabled:))`
- `apiKeyBinding(for:)` → `get: model.loadAIAPIKey(for: service.id)`，`set: model.updateAIAPIKey(_:for:)`（用 `@State var apiKeys: [UUID: String]` 本地缓存，`.onAppear` 时从 model 加载）

去掉原有 Picker 和单独的 SecureField。

---

## Issue 4 — iOS 应用图标

### 根因

`iTime-iOS/Assets.xcassets/AppIcon.appiconset/Contents.json` 有尺寸声明但无 `filename` 引用，图标为空。

### 设计

1. 将根目录 `logo.png` 复制到 `iTime-iOS/Assets.xcassets/AppIcon.appiconset/logo.png`
2. `Contents.json` 改为 Xcode 14+ 单图格式：

```json
{
  "images": [
    {
      "filename": "logo.png",
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

Xcode 14+ 会从 1024×1024 图自动生成所有所需尺寸，无需手动生成多张图。

---

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `iTime.xcodeproj/project.pbxproj` | 加 iOS NSLocalNetworkUsageDescription + NSBonjourServices（Debug/Release 两处） |
| `iTime.entitlements` | 加 network.client + network.server |
| `Sources/iTime/Services/Sync/SyncCoordinator.swift` | 新增 `startResponding()` 方法 |
| `Sources/iTime/App/AppModel.swift` | `DeviceSyncStatus` 加 `.responding`；`startDeviceDiscovery` 启动 responder；`stopDeviceDiscovery` 取消 |
| `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift` | 双按钮 + `.responding` 状态处理 |
| `iTime-iOS/UI/Overview/iOSOverviewView.swift` | 复用 Mac 图表组件，完整重写 |
| `iTime-iOS/UI/Settings/iOSSettingsView.swift` | AI 服务 Section 改为 Toggle 列表 |
| `iTime-iOS/Assets.xcassets/AppIcon.appiconset/Contents.json` | 单图格式 |
| `iTime-iOS/Assets.xcassets/AppIcon.appiconset/logo.png` | 新增（复制自根目录） |
