# iTime UI 美化设计规范

**日期：** 2026-04-06  
**范围：** MenuBar 弹出窗口、概览窗口、AI 复盘对话窗口（含总结报告 + 流水账）  
**方向：** 沉浸杂志感 — 强对比排版、专题感标题、Liquid Glass 全面升级  
**优先级：** 视觉精致度 > 信息密度优化 > 动效体验  
**macOS API 策略：** 激进拥抱 macOS 26 — 大量使用 `glassEffect`，旧版本降级处理

---

## 1. 全局 Theme 变更

### 1.1 Liquid Glass 升级

- 所有 `LiquidGlassCard` / `glassCardStyle()` 在 macOS 26+ 升级为 `.glassEffect(.regular)`
- AI 分析区、流水账卡片等强调区域用 `.glassEffect(.prominent)`
- macOS 14/15 降级继续使用 `.ultraThinMaterial`，行为不变

### 1.2 新增共享组件

**`TagChip`** — 小圆角 pill 标签，用于 Provider / Period 标签展示：
- 背景：`accentColor.opacity(0.12)` 或 `.thinMaterial`
- 字体：`.caption.weight(.medium)`
- 圆角：8pt

**`MagazineDivider`** — 全宽 0.5pt 细线，替代系统 `Divider`：
- `Rectangle().frame(height: 0.5).foregroundStyle(.primary.opacity(0.12))`

**`QuoteBlock`** — 高亮引用块，用于 findings：
- 左侧 3pt 竖条，颜色由外部传入（取分类 colorHex）
- 背景：`accentColor.opacity(0.06)`，圆角 10pt
- 内容：`.body`，`lineSpacing(6)`

**`NumberedCard`** — 编号卡片行，用于 suggestions：
- 左侧大号编号：`.system(size: 28, weight: .black, design: .rounded)`，`.secondary` 色
- 内容：`.body`，右侧占满

### 1.3 MeshGradient 动态染色

概览窗口背景的 `MeshGradient` 颜色从固定 `#5E5CE6` 改为动态：
- 取 `overview.buckets.first?.colorHex` 作为主 accent 色
- 无数据时降级为原有固定配色
- 颜色变化时用 `withAnimation(.easeInOut(duration: 0.8))` 平滑过渡

---

## 2. MenuBar 弹出窗口

**文件：** `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`

### 2.1 布局结构

```
RangePicker（保持）
─────────────────────
大数字区：总时长 size:48 .black .rounded
          "已追踪时间" .caption.secondary 全大写
─────────────────────（MagazineDivider）
类别列表（最多3条）：
  圆点(8pt) + 名称 + 进度条(4pt高) + 百分比
─────────────────────
[设置]        [查看详情 →]
```

### 2.2 关键改动

- **移除** 外层 `LiquidGlassCard` 包裹，弹出窗口背景整体用 `.glassEffect(.regular)`（macOS 26+）
- 总时长数字：`font(.system(size: 48, weight: .black, design: .rounded))`
- 进度条高度：6pt → **4pt**，保留 `LinearGradient` 填充和阴影
- 类别显示上限：4条 → **3条**
- 用 `MagazineDivider` 替代卡片边界

---

## 3. 概览窗口

**文件：** `Sources/iTime/UI/Overview/OverviewWindowView.swift`，`OverviewMetricsSection.swift`，`OverviewChartView.swift`

### 3.1 Hero 区

- 标题 `GlassHeadlineText` 保持，`glassEffect` 保持
- 副标题字体升级：`.subheadline` → `.callout`，`lineSpacing(4)`

### 3.2 指标卡片（OverviewMetricsSection）

- 数字字号：26 → **34**，字重 `.black`
- 每张卡片增加对应 SF Symbol 图标（`.secondary` 色，`size: 20`）：
  - 总时长：`clock.fill`
  - 事件数：`calendar.badge.clock`
  - 日均：`chart.line.uptrend.xyaxis`
  - 最长单日：`trophy.fill`
- 图标左上角放置，数字和标签保持左下布局
- 所有卡片升级为 `.glassEffect(.regular)`

### 3.3 分类分布区（OverviewChartView）

- 环形图（innerRadius 保持 0.58）+ **右侧竖排图例**，替代当前 `OverviewBucketTable`
- 图例每行布局：`色块(12pt圆角矩形) + 名称(.body) + Spacer + 时长(.subheadline.bold) + 百分比(.caption.secondary)`
- 环形图和图例用 `HStack` 并排，图表占 60%，图例占 40%

### 3.4 趋势图（OverviewTrendChartView）

- 入场动画：数据加载后用 `withAnimation(.spring(duration: 0.6))` 触发图表描绘
- `.chartXAxis` 样式：字体 `.caption2`，颜色 `.secondary`

### 3.5 背景

- `MeshGradient` 接入动态 accent 色（见 1.3）
- `OverviewAIAnalysisSection` 卡片升级为 `.glassEffect(.prominent)`

---

## 4. AI 复盘对话窗口 — 对话过程

**文件：** `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`，`AIConversationMessagesView.swift`，`AIConversationComposerView.swift`

### 4.1 Header 区

- 背景：`.ultraThinMaterial` → `.glassEffect(.regular)`（macOS 26+）
- Provider / Period 改用 `TagChip` 组件展示，替代当前 `Label` 纯文字

### 4.2 Preflight 区（服务/模型选择）

- 背景色块 `Color.secondary.opacity(0.04)` 移除，改为透明 + 顶底 `MagazineDivider`
- 标签和 Picker 垂直间距从 8pt → 6pt

### 4.3 对话正文（AIConversationMessagesView）核心重构

**废弃气泡布局，改为文档流：**

AI 消息：
- 顶部 `MagazineDivider`
- 角色标签 pill：`Image(systemName: "sparkles") + Text("AI")`，`.caption.weight(.medium)`，`.secondary` 色
- 消息文本：`.body`，`lineSpacing(8)`，无背景，全宽
- 底部 8pt 间距

用户消息：
- 顶部 `MagazineDivider`
- 角色标签 pill：`Image(systemName: "person.fill") + Text("你")`，`.caption.weight(.medium)`，`.secondary` 色，右对齐
- 消息文本：左侧 3pt `accentColor` 竖条 + `accentColor.opacity(0.06)` 背景，圆角 10pt，全宽
- 内边距：12pt，`lineSpacing(6)`

全局间距：消息间 20pt，页面 padding 24pt → **32pt**

### 4.4 Composer 区（AIConversationComposerView）

- 输入框：移除边框，改为底部单线样式（`Rectangle().frame(height: 1).foregroundStyle(.primary.opacity(0.15))`）
- "发送" 按钮：`.borderedProminent`（保持）
- "结束复盘" 按钮：降级为 `.borderless`，放在发送按钮左侧

---

## 5. AI 复盘对话窗口 — 总结报告

**文件：** `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`（`summaryView` 方法）

### 5.1 报告封面区

```
MagazineDivider
[期号/时间]  .caption 全大写  accent色
[headline]  size:34  .black  多行，行距收紧（lineSpacing: -1）
[日期区间] · [服务名]  .caption.secondary
MagazineDivider
```

- 取消当前 `.title2.weight(.bold)` 样式，改用 `font(.system(size: 34, weight: .black, design: .default))`
- 期号格式：`"第 X 周复盘"` 或按 `summary.displayPeriodText` 生成

### 5.2 摘要段落

- `summary.summary` 字号：`.body` → `.title3`
- `lineSpacing(8)`，无卡片背景，直接裸文字
- 与封面区间距 24pt

### 5.3 主要发现（findings）

- 废弃 bullet 列表
- 每条 finding 改用 `QuoteBlock` 组件（见 1.2）
- 竖条颜色：`overview.buckets.first?.colorHex`，无数据时用 `accentColor`
- Section 标题 `Label("主要发现", systemImage: "lightbulb.fill")` 保持，颜色保持 `.yellow`

### 5.4 改进建议（suggestions）

- 每条 suggestion 改用 `NumberedCard` 组件（见 1.2）
- 编号从 `01` 开始，`String(format: "%02d", index + 1)`
- Section 标题 `Label("改进建议", systemImage: "checkmark.circle.fill")` 保持，颜色保持 `.green`

### 5.5 编辑功能

- "编辑总结" 点击后，`summary.summary` 原地切换为 `TextEditor`
- `TextEditor` 继承同款 `.title3` 字体和 `lineSpacing`，背景透明
- "保存修改" 按钮在 `TextEditor` 右下角以 `.borderedProminent` 显示

---

## 6. AI 复盘对话窗口 — 流水账复盘

**文件：** `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`（`longFormSection` 方法）

### 6.1 布局

- 整体用 `.glassEffect(.prominent)` 全宽卡片包裹
- 卡片内布局：
  - `AIConversationWindowCopy.longFormTitle`：`.subheadline.semibold`（保持）
  - `report.title`：`.headline`，`.secondary` 色
  - `report.content`：`Text` 改用 `AttributedString` 解析基础 Markdown（`**bold**`、`# 标题`、`- 列表`）
  - 内容区 `minHeight: 180, maxHeight: 320`（从 280 略微放大）

### 6.2 操作按钮

- "重新生成" / "生成流水账" 按钮移至卡片**右上角**，样式 `.borderless`，`.caption` 字号
- 生成中状态 `ProgressView` 保持在卡片底部

---

## 7. 不在本次范围内

- Settings 视图（功能性为主，风格跟随系统即可）
- iOS 端 `iOSConversationView`（独立平台，不在本次范围）
- `AIConversationHistoryView` 历史列表（结构复杂，单独规划）
- 无障碍（Accessibility）专项优化

---

## 8. 新增/修改文件清单

| 文件 | 操作 |
|------|------|
| `Sources/iTime/UI/Theme/AppTheme.swift` | 新增 `TagChip`、`MagazineDivider`、`QuoteBlock`、`NumberedCard` 组件 |
| `Sources/iTime/UI/MenuBar/MenuBarContentView.swift` | 移除外层卡片，大数字，细进度条 |
| `Sources/iTime/UI/Overview/OverviewWindowView.swift` | 动态 MeshGradient，AI 分析区 prominent glass |
| `Sources/iTime/UI/Overview/OverviewMetricsSection.swift` | 大数字 + 图标 |
| `Sources/iTime/UI/Overview/OverviewChartView.swift` | 环形图 + 竖排图例替代 OverviewBucketTable |
| `Sources/iTime/UI/Overview/OverviewTrendChartView.swift` | 入场动画 |
| `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift` | Header TagChip，summaryView 重构，longFormSection 重构 |
| `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift` | 完整重写为文档流布局 |
| `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift` | 底线输入框，按钮降级 |
