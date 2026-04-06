# UI 美化（沉浸杂志感）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 iTime 三大界面（MenuBar、概览窗口、AI 复盘对话）重新设计为"沉浸杂志感"风格，使用 macOS 26 Liquid Glass API、文档流对话、杂志报告排版。

**Architecture:** 先在 `AppTheme.swift` 中建立四个共享组件（TagChip、MagazineDivider、QuoteBlock、NumberedCard），再依次改造各界面。所有变更都是纯 UI 层修改，不触及 Domain 层，唯一例外是为 `AppModel` 添加 `updateSummaryText` 方法以支持内联编辑功能。

**Tech Stack:** SwiftUI, Swift Charts, macOS 26 `glassEffect` API, `AttributedString` Markdown 渲染, `NSTextView`（Composer 保持原有实现）

---

## File Map

| 文件 | 操作 |
|------|------|
| `Sources/iTime/UI/Theme/AppTheme.swift` | 修改：新增 TagChip、MagazineDivider、QuoteBlock、NumberedCard；更新动态 MeshGradient |
| `Sources/iTime/UI/MenuBar/MenuBarContentView.swift` | 修改：移除外层卡片，大数字，细进度条，MagazineDivider |
| `Sources/iTime/UI/Overview/OverviewMetricsSection.swift` | 修改：数字放大，添加 SF Symbol 图标 |
| `Sources/iTime/UI/Overview/OverviewChartView.swift` | 修改：环形图 + 竖排图例，删除 OverviewBucketTable 引用 |
| `Sources/iTime/UI/Overview/OverviewBucketTable.swift` | 删除（仅被 OverviewChartView 引用，替换后无用） |
| `Sources/iTime/UI/Overview/OverviewTrendChartView.swift` | 修改：入场动画 |
| `Sources/iTime/UI/Overview/OverviewWindowView.swift` | 修改：动态 MeshGradient accent，AI 分析区 prominent glass |
| `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift` | 修改：Header TagChip，Preflight 清洁化，summaryView 杂志风，longFormSection 重构，新增 updateSummaryText 调用 |
| `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift` | 修改：完整重写为文档流 |
| `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift` | 修改：底线输入框，按钮降级 |
| `Sources/iTime/App/AppModel.swift` | 修改：添加 `updateSummaryText(id:newText:)` 方法 |

---

## Task 1: Theme — 共享组件

**Files:**
- Modify: `Sources/iTime/UI/Theme/AppTheme.swift`

- [ ] **Step 1: 在 AppTheme.swift 末尾添加四个共享组件**

在文件末尾，`extension View` 块之后，追加以下代码：

```swift
// MARK: - Shared Magazine Components

struct TagChip: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MagazineDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundStyle(.primary.opacity(0.12))
    }
}

struct QuoteBlock: View {
    let content: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3)
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NumberedCard: View {
    let number: Int
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", number))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}
```

- [ ] **Step 2: 验证编译通过**

```bash
cd /Users/amarantos/Project/iTime && swift build 2>&1 | tail -5
```

期望输出：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/Theme/AppTheme.swift
git commit -m "feat(theme): add TagChip, MagazineDivider, QuoteBlock, NumberedCard"
```

---

## Task 2: Theme — 动态 MeshGradient accent 色

**Files:**
- Modify: `Sources/iTime/UI/Theme/AppTheme.swift`

- [ ] **Step 1: 更新 `overviewBackgroundPalette` 方法支持外部 accent hex**

将当前的：
```swift
static func overviewBackgroundPalette(for colorScheme: ColorScheme) -> BackgroundPalette {
    switch colorScheme {
    case .dark:
        BackgroundPalette(
            startHex: "#1C1C1E",
            endHex: "#0A0A0B",
            accentHex: "#5E5CE6"
        )
    default:
        BackgroundPalette(
            startHex: "#F2F2F7",
            endHex: "#E5E5EA",
            accentHex: "#007AFF"
        )
    }
}
```

替换为：
```swift
static func overviewBackgroundPalette(for colorScheme: ColorScheme, accentHex: String? = nil) -> BackgroundPalette {
    let defaultAccent = colorScheme == .dark ? "#5E5CE6" : "#007AFF"
    let resolvedAccent = accentHex ?? defaultAccent
    switch colorScheme {
    case .dark:
        return BackgroundPalette(
            startHex: "#1C1C1E",
            endHex: "#0A0A0B",
            accentHex: resolvedAccent
        )
    default:
        return BackgroundPalette(
            startHex: "#F2F2F7",
            endHex: "#E5E5EA",
            accentHex: resolvedAccent
        )
    }
}
```

同时更新 `overviewBackgroundGradient` 方法签名：
```swift
static func overviewBackgroundGradient(for colorScheme: ColorScheme, accentHex: String? = nil) -> some View {
    BackgroundGradient(palette: overviewBackgroundPalette(for: colorScheme, accentHex: accentHex))
}
```

- [ ] **Step 2: 验证编译（`overviewBackgroundGradient` 在 OverviewWindowView 中调用无参数，确认默认参数兼容）**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/Theme/AppTheme.swift
git commit -m "feat(theme): support dynamic accent color in overview background gradient"
```

---

## Task 3: MenuBar 弹出窗口重设计

**Files:**
- Modify: `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`

- [ ] **Step 1: 重写 `authorizedContent` 变量**

将 `MenuBarContentView` 中的 `authorizedContent` 计算属性从当前的 `LiquidGlassCard` 包裹方式改为直接布局：

```swift
@ViewBuilder
private var authorizedContent: some View {
    VStack(alignment: .leading, spacing: 0) {
        // 大数字区
        VStack(alignment: .leading, spacing: 4) {
            Text("已追踪时间")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            Text(model.overview?.totalDuration.formattedDuration ?? "0m")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.bottom, 16)

        if let overview = model.overview, !overview.buckets.isEmpty {
            MagazineDivider()
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 14) {
                Text("按日历分布")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)

                ForEach(MenuBarBucketChartRow.makeRows(from: overview.buckets, limit: 3)) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: row.colorHex))
                                .frame(width: 8, height: 8)

                            Text(row.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(row.shareText)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.quaternary.opacity(0.5))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: row.colorHex), Color(hex: row.colorHex).opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(proxy.size.width * row.fillRatio, row.fillRatio > 0 ? 10 : 0))
                                    .shadow(color: Color(hex: row.colorHex).opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .frame(height: 4)

                        Text(row.durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            MagazineDivider()
                .padding(.vertical, 12)

            Text("当前范围内没有日程。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/MenuBar/MenuBarContentView.swift
git commit -m "feat(menubar): magazine style — large number, slim bars, no card wrapper"
```

---

## Task 4: 概览窗口 — 指标卡片添加图标

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewMetricsSection.swift`

- [ ] **Step 1: 为 `OverviewMetricKind` 添加 `systemImage` 属性，更新卡片布局**

将整个文件替换为：

```swift
import SwiftUI

enum OverviewMetricKind: CaseIterable {
    case totalDuration
    case eventCount
    case averageDailyDuration
    case longestDay

    var title: String {
        switch self {
        case .totalDuration: "总时长"
        case .eventCount: "事件数"
        case .averageDailyDuration: "日均时长"
        case .longestDay: "最长单日"
        }
    }

    var systemImage: String {
        switch self {
        case .totalDuration: "clock.fill"
        case .eventCount: "calendar.badge.clock"
        case .averageDailyDuration: "chart.line.uptrend.xyaxis"
        case .longestDay: "trophy.fill"
        }
    }
}

struct OverviewMetricsSection: View {
    let overview: TimeOverview

    var body: some View {
        LazyVGrid(columns: [.init(.flexible(), spacing: 16), .init(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(OverviewMetricKind.allCases, id: \.self) { metric in
                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: metric.systemImage)
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(value(for: metric))
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(metric.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func value(for metric: OverviewMetricKind) -> String {
        switch metric {
        case .totalDuration:
            overview.totalDuration.formattedDuration
        case .eventCount:
            "\(overview.totalEventCount)"
        case .averageDailyDuration:
            overview.averageDailyDuration.formattedDuration
        case .longestDay:
            overview.longestDayDuration.formattedDuration
        }
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewMetricsSection.swift
git commit -m "feat(overview): metric cards with SF Symbol icons and larger numbers"
```

---

## Task 5: 概览窗口 — 分类图表改为环形图 + 竖排图例

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewChartView.swift`
- Delete: `Sources/iTime/UI/Overview/OverviewBucketTable.swift`

- [ ] **Step 1: 重写 OverviewChartView，内联图例替代 OverviewBucketTable**

将 `OverviewChartView.swift` 整个文件替换为：

```swift
import Charts
import SwiftUI

struct OverviewChartView: View {
    let overview: TimeOverview

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Chart(overview.buckets) { bucket in
                SectorMark(
                    angle: .value("时长", bucket.totalDuration),
                    innerRadius: .ratio(0.58),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: bucket.colorHex))
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(overview.buckets) { bucket in
                    legendRow(bucket)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func legendRow(_ bucket: TimeBucketSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: bucket.colorHex))
                    .frame(width: 12, height: 12)
                Text(bucket.name)
                    .font(.body)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(bucket.totalDuration.formattedDuration)
                    .font(.subheadline.weight(.bold))
                Text(bucket.shareText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 20)
        }
    }
}
```

- [ ] **Step 2: 删除 OverviewBucketTable.swift**

```bash
rm Sources/iTime/UI/Overview/OverviewBucketTable.swift
```

- [ ] **Step 3: 在 iTime.xcodeproj 中移除该文件（避免 Xcode 工程引用悬空）**

```bash
# 检查 pbxproj 中是否仍引用该文件
grep -n "OverviewBucketTable" iTime.xcodeproj/project.pbxproj | head -10
```

如有引用行，需手动在 Xcode 中 Remove Reference，或用以下命令确认文件在 SPM 目标下（SPM 会自动扫描文件，不需要手动维护 pbxproj 引用）：

```bash
grep "OverviewBucketTable" iTime.xcodeproj/project.pbxproj | wc -l
```

若输出为 0，则 SPM 目标自动管理，无需额外操作。

- [ ] **Step 4: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewChartView.swift
git rm Sources/iTime/UI/Overview/OverviewBucketTable.swift
git commit -m "feat(overview): inline legend replaces OverviewBucketTable; remove unused file"
```

---

## Task 6: 概览窗口 — 趋势图入场动画

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewTrendChartView.swift`

- [ ] **Step 1: 添加 `@State private var appeared` 并在 `onAppear` 触发入场动画**

在 `OverviewTrendChartView` struct 内，`body` 之前添加：
```swift
@State private var appeared = false
```

将 `Chart { ... }` 代码块修改为带动画的版本（在 `.frame(height: 280)` 之后追加）：

```swift
Chart {
    ForEach(overview.stackedBuckets) { bucket in
        BarMark(
            x: .value("时间", bucket.label),
            y: .value("时长", 0)
        )
        .opacity(0.001)
    }

    ForEach(overview.stackedBuckets) { bucket in
        ForEach(bucket.segments) { segment in
            BarMark(
                x: .value("时间", bucket.label),
                y: .value("时长", appeared ? segment.duration / 3600 : 0)
            )
            .foregroundStyle(Color(hex: segment.calendarColorHex))
        }
    }
}
.chartXScale(domain: OverviewTrendChartCopy.xDomainLabels(for: overview.stackedBuckets))
.chartLegend(.hidden)
.frame(height: 280)
.onAppear {
    withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
        appeared = true
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewTrendChartView.swift
git commit -m "feat(overview): spring entry animation for trend chart bars"
```

---

## Task 7: 概览窗口 — 动态背景 + AI 分析区强化

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewWindowView.swift`

- [ ] **Step 1: 更新 body 中的背景渐变调用，传入动态 accentHex**

将 `body` 中的：
```swift
AppTheme.overviewBackgroundGradient(for: colorScheme)
```

替换为：
```swift
AppTheme.overviewBackgroundGradient(
    for: colorScheme,
    accentHex: model.overview?.buckets.first?.colorHex
)
.animation(.easeInOut(duration: 0.8), value: model.overview?.buckets.first?.colorHex)
```

- [ ] **Step 2: 找到 `OverviewAIAnalysisSection` 的调用位置，确认其容器是否已有 glass 样式**

在 `overviewContent` 的 `VStack` 中，`OverviewAIAnalysisSection(model: model)` 当前是裸调用。打开 `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift` 检查其顶层背景样式。

如果 `OverviewAIAnalysisSection` 自身没有使用 `.glassEffect(.prominent)`，在 `OverviewWindowView.swift` 的调用处包裹：

```swift
OverviewAIAnalysisSection(model: model)
    .background {
        if #available(macOS 26, *) {
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(.clear)
                .glassEffect(.prominent, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        }
    }
```

若 `OverviewAIAnalysisSection` 已有 `glassCardStyle()`，则在其 `glassCardStyle()` 修改为 `.prominentGlassCardStyle()`，并在 `AppTheme.swift` 中添加：

```swift
extension View {
    func prominentGlassCardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.prominent, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}
```

- [ ] **Step 3: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewWindowView.swift Sources/iTime/UI/Theme/AppTheme.swift
git commit -m "feat(overview): dynamic accent MeshGradient + prominent glass for AI analysis"
```

---

## Task 8: AI 对话窗口 — Header TagChip + Preflight 清洁化

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`

- [ ] **Step 1: 更新 `header` 计算属性，将 Provider/Period Label 改为 TagChip**

找到 `header` 属性中：
```swift
HStack(spacing: 8) {
    Label(providerTitle, systemImage: "sparkles")
    Text("·")
    Label(periodTitle, systemImage: "calendar")
}
.font(.subheadline.weight(.medium))
.foregroundStyle(.secondary)
```

替换为：
```swift
HStack(spacing: 8) {
    TagChip(icon: "sparkles", text: providerTitle)
    TagChip(icon: "calendar", text: periodTitle)
}
```

同时将 `header` 背景从 `.ultraThinMaterial` 改为在 macOS 26 上使用 glass：

```swift
.background {
    if #available(macOS 26, *) {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular, in: Rectangle())
    } else {
        Rectangle()
            .fill(.ultraThinMaterial)
    }
}
```

- [ ] **Step 2: 更新 `preflightOptionsView`，移除背景色，改用 MagazineDivider**

将 `preflightOptionsView` 末尾的：
```swift
.padding(.horizontal, 24)
.padding(.vertical, 16)
.background(Color.secondary.opacity(0.04))
```

替换为：
```swift
.padding(.horizontal, 24)
.padding(.vertical, 12)
```

并在 `preflightOptionsView` 的 `VStack` 上方（`body` 中，`if showsPreflightOptions { preflightOptionsView; Divider() }` 处）移除系统 `Divider()`，改为 `MagazineDivider()`：

原代码：
```swift
if showsPreflightOptions {
    preflightOptionsView
    Divider()
}
```

替换为：
```swift
if showsPreflightOptions {
    MagazineDivider()
    preflightOptionsView
    MagazineDivider()
}
```

同时也将 `conversationBody` 前的 `Divider()` 移除（已被上方 MagazineDivider 覆盖），`header` 后的 `Divider()` 同样替换：

```swift
// header 之后：
header
MagazineDivider()
if showsPreflightOptions {
    preflightOptionsView
    MagazineDivider()
}
conversationBody
if showsComposer {
    MagazineDivider()
    AIConversationComposerView(...)
}
```

- [ ] **Step 3: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationWindowView.swift
git commit -m "feat(ai-window): TagChip header labels, MagazineDivider separators, clean preflight"
```

---

## Task 9: AI 对话消息 — 文档流重写

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift`

- [ ] **Step 1: 完整重写 AIConversationMessagesView 为文档流布局**

将整个文件替换为：

```swift
import SwiftUI

struct AIConversationMessagesView: View {
    let messages: [AIConversationMessage]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages, id: \.id) { message in
                        messageRow(for: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let lastID = messages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(for message: AIConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MagazineDivider()

            VStack(alignment: .leading, spacing: 10) {
                // Role label
                roleLabel(for: message.role)

                // Content
                if message.role == .assistant {
                    Text(message.content)
                        .font(.body)
                        .lineSpacing(8)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    userMessageBlock(content: message.content)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private func roleLabel(for role: AIConversationMessageRole) -> some View {
        HStack(spacing: 4) {
            if role == .assistant {
                Image(systemName: "sparkles")
                Text("AI")
            } else {
                Text("你")
                Image(systemName: "person.fill")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
    }

    private func userMessageBlock(content: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: 3)
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift
git commit -m "feat(ai-messages): document flow layout replaces chat bubbles"
```

---

## Task 10: AI Composer — 底线输入框样式

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`

- [ ] **Step 1: 更新输入框外观和按钮样式**

在 `AIConversationComposerView.body` 中，找到 `ZStack(alignment: .topLeading)` 的外层修饰符：

```swift
.background(Color(NSColor.textBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
)
```

替换为：

```swift
.background(Color.clear)
.overlay(alignment: .bottom) {
    Rectangle()
        .frame(height: 1)
        .foregroundStyle(.primary.opacity(0.15))
}
```

找到 "结束复盘" 按钮：
```swift
Button(AIConversationWindowCopy.finishConversationAction, action: onFinish)
    .buttonStyle(.bordered)
    .disabled(isSending)
```

替换为：
```swift
Button(AIConversationWindowCopy.finishConversationAction, action: onFinish)
    .buttonStyle(.borderless)
    .foregroundStyle(.secondary)
    .disabled(isSending)
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationComposerView.swift
git commit -m "feat(composer): borderless input with bottom line, downgrade finish button"
```

---

## Task 11: AppModel — 添加 updateSummaryText 方法

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`

- [ ] **Step 1: 在 AppModel 中添加 `updateSummaryText(id:newText:)` public 方法**

在 `AppModel` 中，找到 `public func longFormReport(for summaryID: UUID)` 方法附近，添加：

```swift
public func updateSummaryText(id: UUID, newText: String) {
    var summaries = aiConversationArchive.summaries
    guard let index = summaries.firstIndex(where: { $0.id == id }) else { return }
    let old = summaries[index]
    summaries[index] = AIConversationSummary(
        id: old.id,
        sessionID: old.sessionID,
        serviceID: old.serviceID,
        serviceDisplayName: old.serviceDisplayName,
        provider: old.provider,
        model: old.model,
        range: old.range,
        startDate: old.startDate,
        endDate: old.endDate,
        createdAt: old.createdAt,
        headline: old.headline,
        summary: newText,
        findings: old.findings,
        suggestions: old.suggestions,
        overviewSnapshot: old.overviewSnapshot
    )
    let updatedArchive = AIConversationArchive(
        sessions: aiConversationArchive.sessions,
        summaries: summaries,
        memorySnapshots: aiConversationArchive.memorySnapshots,
        longFormReports: aiConversationArchive.longFormReports,
        deletedItemIDs: aiConversationArchive.deletedItemIDs
    )
    try? persistConversationArchive(updatedArchive)
    aiConversationHistory = Self.sortedConversationSummaries(summaries)
    if case .completed(let activeSummary) = aiConversationState, activeSummary.id == id {
        aiConversationState = .completed(summaries[index])
    }
}
```

> 注意：`persistConversationArchive` 是 `AppModel` 的 private 方法，本方法在同一 class 内，可直接调用。

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/App/AppModel.swift
git commit -m "feat(model): add updateSummaryText for inline summary editing"
```

---

## Task 12: AI 总结报告 — 杂志风格重构

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`

- [ ] **Step 1: 在 AIConversationWindowView 中添加编辑状态**

在 `AIConversationWindowView` 的 `@State` 变量区，添加：

```swift
@State private var isEditingSummary = false
@State private var summaryEditText = ""
```

- [ ] **Step 2: 重写 `summaryView` 方法**

将整个 `private func summaryView(_ summary: AIConversationSummary) -> some View` 方法替换为：

```swift
private func summaryView(_ summary: AIConversationSummary) -> some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            // ① 报告封面区
            VStack(alignment: .leading, spacing: 12) {
                MagazineDivider()
                    .padding(.bottom, 8)

                Text(summary.displayPeriodText.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.accentColor)
                    .tracking(1.2)

                Text(summary.headline)
                    .font(.system(size: 34, weight: .black))
                    .lineSpacing(-1)
                    .foregroundStyle(.primary)

                Text("\(summary.startDate.formatted(date: .abbreviated, time: .omitted)) — \(summary.endDate.formatted(date: .abbreviated, time: .omitted))  ·  \(summary.serviceDisplayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MagazineDivider()
                    .padding(.top, 8)
            }
            .padding(.bottom, 24)

            // ② 摘要段落
            Group {
                if isEditingSummary {
                    TextEditor(text: $summaryEditText)
                        .font(.title3)
                        .lineSpacing(8)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 120)
                        .overlay(alignment: .bottomTrailing) {
                            Button(AIConversationWindowCopy.saveEditsAction) {
                                model.updateSummaryText(id: summary.id, newText: summaryEditText)
                                isEditingSummary = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(8)
                        }
                } else {
                    Text(summary.summary)
                        .font(.title3)
                        .lineSpacing(8)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            summaryEditText = summary.summary
                            isEditingSummary = true
                        }
                        .overlay(alignment: .topTrailing) {
                            Button(AIConversationWindowCopy.editSummaryAction) {
                                summaryEditText = summary.summary
                                isEditingSummary = true
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                }
            }
            .padding(.bottom, 32)

            // ③ 主要发现
            if !summary.findings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Label(AIConversationWindowCopy.findingsTitle, systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(summary.findings.enumerated()), id: \.offset) { _, finding in
                            QuoteBlock(
                                content: finding,
                                accentColor: summary.overviewSnapshot.buckets.first.map { Color(hex: $0.colorHex) } ?? .accentColor
                            )
                        }
                    }
                }
                .padding(.bottom, 32)
            }

            // ④ 改进建议
            if !summary.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Label(AIConversationWindowCopy.suggestionsTitle, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(summary.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            NumberedCard(number: index + 1, content: suggestion)
                        }
                    }
                }
                .padding(.bottom, 32)
            }

            // ⑤ 流水账
            longFormSection(summaryID: summary.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}
```

> 注意：`summary.overviewSnapshot.buckets` 需要确认 `AIOverviewSnapshot` 是否有 `buckets` 属性。若无，将 QuoteBlock accentColor 参数改为 `.accentColor`。执行 `grep -n "AIOverviewSnapshot\|overviewSnapshot" Sources/iTime/Domain/AIConversation.swift | head -10` 确认。

- [ ] **Step 3: 验证编译，注意 overviewSnapshot 属性名**

```bash
swift build 2>&1 | grep -E "error:|Build complete"
```

若有 `overviewSnapshot.buckets` 编译错误，将相关行改为：
```swift
accentColor: .accentColor
```

然后重新：
```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationWindowView.swift
git commit -m "feat(summary): magazine headline, QuoteBlock findings, NumberedCard suggestions, inline edit"
```

---

## Task 13: AI 总结报告 — 流水账卡片重构

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`

- [ ] **Step 1: 重写 `longFormSection` 方法**

将整个 `@ViewBuilder private func longFormSection(summaryID: UUID)` 方法替换为：

```swift
@ViewBuilder
private func longFormSection(summaryID: UUID) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        if let report = model.longFormReport(for: summaryID) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AIConversationWindowCopy.longFormTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(report.title)
                            .font(.headline)
                    }
                    Spacer()
                    Button(AIConversationWindowCopy.regenerateLongFormAction) {
                        Task { await model.generateLongFormReport(for: summaryID) }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                ScrollView {
                    longFormText(report.content)
                        .font(.body)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 180, maxHeight: 320)
            }
            .padding(AppTheme.cardPadding)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.prominent, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AIConversationWindowCopy.longFormTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("生成一份详细的流水账复盘报告")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(AIConversationWindowCopy.generateLongFormAction) {
                    Task { await model.generateLongFormReport(for: summaryID) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(AppTheme.cardPadding)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }

        switch model.aiLongFormState {
        case .generating(let currentSummaryID) where currentSummaryID == summaryID:
            ProgressView(AIConversationWindowCopy.longFormGeneratingText)
                .padding(.top, 12)
        case .failed(let currentSummaryID, let message) where currentSummaryID == summaryID:
            Text(message)
                .foregroundStyle(.red)
                .font(.caption)
                .padding(.top, 8)
        default:
            EmptyView()
        }
    }
}

private func longFormText(_ content: String) -> Text {
    if let attributed = try? AttributedString(
        markdown: content,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    ) {
        return Text(attributed)
    }
    return Text(content)
}
```

- [ ] **Step 2: 验证编译**

```bash
swift build 2>&1 | tail -5
```

期望：`Build complete!`

- [ ] **Step 3: 运行测试，确认无回归**

```bash
swift test 2>&1 | tail -10
```

期望：所有测试通过，无 failures。

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationWindowView.swift
git commit -m "feat(longform): prominent glass card, Markdown text, compact action button"
```

---

## Self-Review

**Spec coverage check:**

| Spec Section | Task |
|---|---|
| 全局 TagChip, MagazineDivider, QuoteBlock, NumberedCard | Task 1 |
| 动态 MeshGradient accent 色 | Task 2, Task 7 |
| MenuBar 大数字、细进度条、移除卡片 | Task 3 |
| 指标卡片 SF Symbol 图标 + 大数字 | Task 4 |
| 分类图表内联图例、删除 OverviewBucketTable | Task 5 |
| 趋势图入场动画 | Task 6 |
| AI 分析区 prominent glass | Task 7 |
| Header TagChip, Preflight MagazineDivider | Task 8 |
| 文档流对话消息 | Task 9 |
| Composer 底线输入框、按钮降级 | Task 10 |
| updateSummaryText AppModel 方法 | Task 11 |
| 报告封面、摘要 title3、QuoteBlock findings、NumberedCard suggestions、内联编辑 | Task 12 |
| 流水账 prominent glass 卡片、Markdown 渲染、按钮移至右上角 | Task 13 |

**Placeholder scan:** 无 TBD/TODO。Task 12 Step 2 有一个编译后确认步骤（overviewSnapshot.buckets），提供了明确的备选代码，不是 placeholder。

**Type consistency:** `QuoteBlock(content:accentColor:)` 在 Task 1 定义，Task 12 使用，参数名一致。`NumberedCard(number:content:)` 同理。`updateSummaryText(id:newText:)` 在 Task 11 定义，Task 12 调用，方法签名一致。`MagazineDivider` 无参数，Tasks 3/8/9 均直接 `MagazineDivider()` 调用，一致。
