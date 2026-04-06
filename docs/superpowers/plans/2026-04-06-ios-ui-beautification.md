# iOS UI 美化（沉浸杂志感）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 iTime iOS 端三大界面（统计、AI 复盘、设置/设备互传）改造为“沉浸杂志感”风格，统一视觉语言并保持现有功能路径不变。

**Architecture:** 先在 iOS 侧建立共享 UI 组件（TagChip、MagazineDivider、QuoteBlock、NumberedCard、MagazineGlassCard），再分模块改造 Overview、Conversation、History/Detail、Settings/Sync。核心原则是 **UI 层优先改造**，尽量不修改 Domain；如涉及轻量状态字段，仅在 View 内通过 `@State` 承接。

**Tech Stack:** SwiftUI, Swift Charts, MarkdownUI, iOS 26 `glassEffect`（带 iOS 17+ fallback）, xcodebuild, swift test.

---

## 重要约束

1. 所有 `glassEffect` 必须使用 `#available(iOS 26, *)` 包裹，并提供 `.ultraThinMaterial` / `.thinMaterial` 回退。
2. 优先使用 `.glassEffect(.regular, ...)`，仅在 iOS 目标验证通过后再考虑 `.prominent`。
3. 视觉改造不得改变现有数据流、权限逻辑、AI 交互状态机语义。
4. 每个任务完成后至少执行一次 iOS 构建验证；关键任务后补一轮 `swift test` 防回归。

---

## File Map

| 文件 | 操作 |
|------|------|
| `iTime-iOS/UI/Theme/iOSMagazineTheme.swift` | 新增：iOS 杂志风共享组件与卡片样式 |
| `iTime-iOS/UI/Overview/iOSOverviewView.swift` | 修改：背景、指标排版、图表布局与入场动画 |
| `iTime-iOS/UI/Conversation/iOSConversationView.swift` | 修改：入口页、会话页、历史与详情文档流重构 |
| `iTime-iOS/UI/Settings/iOSSettingsView.swift` | 修改：设置页结构与玻璃卡容器 |
| `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift` | 修改：设备互传区视觉层级与操作区布局 |
| `iTime-iOS/UI/Root/iTimeIOSRootView.swift` | 修改：Tab 视觉与统一背景承载 |
| `iTime.xcodeproj/project.pbxproj` | 可能修改：如新增文件未自动纳入目标，需补 target membership |

---

## Task 1: iOS Theme — 建立共享杂志组件

**Files:**
- Create: `iTime-iOS/UI/Theme/iOSMagazineTheme.swift`

- [ ] **Step 1: 新增 iOS 侧共享组件与样式**

在新文件中定义：
- `TagChip(icon:text:)`
- `MagazineDivider`
- `QuoteBlock(content:accentColor:)`
- `NumberedCard(number:content:)`
- `MagazineGlassCard<Content: View>`（封装 iOS 26 glass + fallback）
- `Color` hex 转换 helper（若 iOS 端已有 helper，可复用避免重复）

组件设计要求：
- TagChip 使用小号中等字重，轻玻璃/材质背景。
- QuoteBlock 使用左侧 3pt 色条与弱色块底。
- NumberedCard 使用两位数字大号字（如 01/02）。
- MagazineGlassCard 统一圆角、描边、阴影参数，避免页面各自实现。

- [ ] **Step 2: 确认 target membership**

若 iOS target 未自动收录，补到 iOS target：
- 打开 Xcode 检查新文件是否在 `iTime-iOS` target 的 Compile Sources 中。

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

期望输出包含：`** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Theme/iOSMagazineTheme.swift iTime.xcodeproj/project.pbxproj
git commit -m "feat(ios-theme): add magazine shared components and glass card wrapper"
```

---

## Task 2: Overview — 沉浸背景与杂志分区骨架

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`

- [ ] **Step 1: 为页面增加动态氛围背景**

在 `NavigationStack` 外层或 `ScrollView` 背层添加：
- iOS 26：渐变 + 柔和形状（可结合 Mesh-like 视觉）
- iOS 17 fallback：线性渐变 + 模糊圆形高光

accent 建议来源：
- `model.overview?.buckets.first?.colorHex`，无数据时回落 `.accentColor`

- [ ] **Step 2: 将 range/metrics/trend/distribution 四块改为统一杂志节奏**

统一策略：
- 一级标题用全大写小字重（或 tracking 扩展）
- 各区块之间用 `MagazineDivider`
- 原 `card(title:)` 改为 `MagazineGlassCard` 包裹，减少重复背景代码

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift
git commit -m "feat(ios-overview): immersive background and magazine section scaffolding"
```

---

## Task 3: Overview — 指标区改为“大数字 + 图标”

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`

- [ ] **Step 1: 重写 metricsSection**

将 `LabeledContent` 列表改为 2x2 网格卡片，每张卡包含：
- SF Symbol（clock, calendar, trend, trophy）
- 大号数字（rounded, heavy）
- 小号标题（uppercase + tertiary）

可抽离 `OverviewMetricKind` 与 `metricValue(_:)` 辅助函数，降低 body 嵌套复杂度。

- [ ] **Step 2: 增加数字切换动画**

对总时长/日均等数值文本添加：
- `.contentTransition(.numericText())`
- 配合轻量 `.animation(.easeInOut(duration: 0.25), value: ...)`

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift
git commit -m "feat(ios-overview): metric cards with icons and large numeric hierarchy"
```

---

## Task 4: Overview — 趋势图入场动画与可读性提升

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`

- [ ] **Step 1: 为 trend chart 添加 appeared 状态**

新增 `@State private var chartAppeared = false`，并在趋势图使用：
- 初始高度/值为 0
- `onAppear` 时 spring 动画拉起

- [ ] **Step 2: 优化 X 轴标签密度与摘要文案位置**

沿用已有 `visibleXAxisLabels` 逻辑，进一步：
- 降低拥挤时字号或旋转
- 将“最忙时段”摘要放到图后并与图例风格一致

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift
git commit -m "feat(ios-overview): spring entry animation and refined trend readability"
```

---

## Task 5: Overview — 分类分布改为“环形图 + 竖排图例”杂志版

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`

- [ ] **Step 1: 调整 distributionSection 布局结构**

将当前上下结构改为：
- 上：Sector ring（保留）
- 下：竖排 legend，每行包含色块、名称、占比、时长

重点：
- 统一色块尺寸/行高
- 占比使用中等字重，时长次级色
- 保留无障碍朗读标签

- [ ] **Step 2: 无数据兜底文案和空态视觉统一**

当 buckets 为空时，显示与总体风格一致的空态段落，不出现突兀系统样式。

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift
git commit -m "feat(ios-overview): magazine donut+legend distribution layout"
```

---

## Task 6: Conversation 入口页 — TagChip Header + Preflight 清洁化

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 入口页顶部信息改为 TagChip 组**

将服务与模型信息从普通文本/stateCard 改为：
- `TagChip(icon: "sparkles", text: selectedServiceDisplayName)`
- `TagChip(icon: "cpu", text: selectedModelDisplayText)`
- `TagChip(icon: "calendar", text: model.liveSelectedRange.title)`

- [ ] **Step 2: preflight 区域背景去重，改用分隔节奏**

- 模型选择块、范围块使用 `MagazineGlassCard`
- 区块之间用 `MagazineDivider`
- 删除多层重复圆角背景与 overlay 描边

- [ ] **Step 3: “进入对话/继续对话”操作层级重排**

主按钮突出，危险动作“退出不保存”降级为次按钮并靠后。

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios-conversation): chip header and cleaner preflight layout"
```

---

## Task 7: Conversation 会话页 — 聊天气泡改为文档流

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 重写 session message row 为文档流**

替换 `messageBubble` 风格：
- 每条消息前后使用 `MagazineDivider`
- 角色标签置于段首（AI/我）
- AI 文本为正文排版
- 用户文本用左色条块（参考 QuoteBlock 风格）

- [ ] **Step 2: 保留自动滚动逻辑，更新锚点策略**

保持已有 `ScrollViewReader` 自动滚动行为；新增消息时滚到底部，防止改造后失效。

- [ ] **Step 3: 状态行简化为 TagChip + 消息统计**

把 `conversationStatusRow` 从普通 `Label` 改成 chip + 计数，减少视觉噪音。

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios-chat): document-flow conversation replaces bubble layout"
```

---

## Task 8: Conversation Composer — 底线输入框与按钮降噪

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 输入区外观从 rounded box 改为 bottom-line**

对回复输入区域应用：
- 透明背景
- 底部 1px 分隔线
- 减少边框重量，保留可点击区域

- [ ] **Step 2: 操作按钮层级调整**

- “发送”保持主要按钮
- “结束复盘”降级为次要按钮（borderless 或 tinted）
- `isSending` 时保持禁用状态一致

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios-composer): bottom-line input style and secondary finish action"
```

---

## Task 9: History + Summary Detail — 杂志报告化

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 历史列表条目视觉升级**

在 `iOSConversationHistoryView`：
- 每个条目使用更清晰的信息层级（标题、期间、服务）
- 按区间分组保留，组内条目统一间距

- [ ] **Step 2: 重构 `iOSConversationSummaryDetailView` 报告结构**

结构目标：
1. 报告封面区（period/service/date）
2. 摘要正文（可点击进入编辑）
3. 发现（QuoteBlock 列表）
4. 建议（NumberedCard 列表）
5. 流水账（Markdown 渲染）

- [ ] **Step 3: 保留现有编辑能力并简化交互**

继续复用 `model.updateAIConversationSummary(...)`，避免引入新 Domain API；
仅在 UI 中增加“编辑摘要/保存摘要”轻流程。

- [ ] **Step 4: 长文流水账卡片化**

`longFormSection` 改为玻璃卡片容器，按钮置右上，加载/失败状态放在卡片下方。

- [ ] **Step 5: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 6: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios-summary): magazine report layout with quote and numbered cards"
```

---

## Task 10: Settings + Sync — 与主视觉统一

**Files:**
- Modify: `iTime-iOS/UI/Settings/iOSSettingsView.swift`
- Modify: `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift`

- [ ] **Step 1: 统一 Section 视觉容器**

在不改变 List 交互的前提下：
- AI 服务项更清晰的分组节奏
- 设备互传状态文本弱化、主操作按钮层级强化

- [ ] **Step 2: 同步状态区风格升级**

将 `lastSyncStatus` 语义映射到更明确的视觉反馈：
- syncing：中性色 + ProgressView
- succeeded：次要色成功提示
- failed：红色文案与可重试入口

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Settings/iOSSettingsView.swift iTime-iOS/UI/Sync/iOSDeviceSyncView.swift
git commit -m "feat(ios-settings): align settings and sync sections with magazine visual language"
```

---

## Task 11: Root — Tab 与全局视觉收口

**Files:**
- Modify: `iTime-iOS/UI/Root/iTimeIOSRootView.swift`

- [ ] **Step 1: Tab 视觉语言一致化**

保留三 Tab 信息架构，优化：
- 图标与文案权重
- 切换时轻动画
- 页面背景承载与各页风格一致

- [ ] **Step 2: 首次权限请求体验不突兀**

`requestAccessIfNeeded` 保持原逻辑，避免与新背景/动画冲突导致闪烁。

- [ ] **Step 3: 构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -8
```

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Root/iTimeIOSRootView.swift
git commit -m "feat(ios-root): polish tab shell and global visual consistency"
```

---

## Task 12: 回归验证与风险收口

**Files:**
- Verify only

- [ ] **Step 1: iOS 全量构建验证**

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'generic/platform=iOS Simulator' build
```

期望：`** BUILD SUCCEEDED **`

- [ ] **Step 2: 共享逻辑回归测试**

```bash
swift test 2>&1 | tail -20
```

期望：无 failures。

- [ ] **Step 3: 手动验收清单**

- 统计页：大数字、图表动画、图例可读性。
- 对话页：文档流消息、输入体验、自动滚动。
- 历史详情：摘要/发现/建议/流水账阅读节奏。
- 设置互传：状态反馈清晰，操作路径不变。
- 深浅色与动态字体下无明显布局破碎。

- [ ] **Step 4: Commit（若前面按任务分批提交，可跳过）**

```bash
git status
```

确保工作区干净或仅保留预期变更。

---

## Self-Review

**Spec coverage check:**

| Spec Section | Task |
|---|---|
| 共享 TagChip / MagazineDivider / QuoteBlock / NumberedCard | Task 1 |
| iOS 背景沉浸感 + 动态 accent | Task 2 |
| 指标卡片图标 + 大数字 | Task 3 |
| 趋势图入场动画 | Task 4 |
| 分类分布环形图 + 竖排图例 | Task 5 |
| 对话入口 Header Chip + Preflight 清洁化 | Task 6 |
| 会话消息文档流 | Task 7 |
| Composer 底线输入 + 按钮降级 | Task 8 |
| 历史详情杂志报告化 | Task 9 |
| 设置/互传视觉统一 | Task 10 |
| Root 壳层视觉收口 | Task 11 |
| 构建与测试回归 | Task 12 |

**Compatibility check:**
- 所有 glass API 均需 iOS 26 条件编译与回退。
- 若 `.prominent` 在当前工具链不可用，统一退回 `.regular` 并通过描边/阴影增强层级。

**Out-of-scope:**
- 不改 AI 协议、统计口径、同步协议。
- 不新增后端或网络能力。
