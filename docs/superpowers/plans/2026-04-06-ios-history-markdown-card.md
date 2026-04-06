# iOS 历史详情 Markdown 与段落卡片增强 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 iOS 复盘历史详情页所有 Markdown 文本区块统一支持高亮/代码块渲染，并将客观总结降级为小字号且每段落带半透明底卡。

**Architecture:** 在现有 `iOSConversationSummaryDetailView`（位于 `iOSConversationView.swift`）内收敛为统一 Markdown 渲染入口，所有历史详情读态文本都复用同一套样式。保留编辑态与数据模型不变，仅修改展示层。段落底卡参数与流程图容器保持一致（`fill 0.08 + stroke 0.15`）以统一视觉语言。

**Tech Stack:** Swift 6, SwiftUI, MarkdownUI, iOS target in `iTime.xcodeproj`

---

## File Map

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `iTime-iOS/UI/Conversation/iOSConversationView.swift` | 统一历史详情页 Markdown 渲染与段落卡片样式，应用到总结/发现/建议/流水账 |
| （可选同步）修改 | `iTime-iOS/UI/Conversation/iOSConversationSummaryDetailView.swift` | 与主实现保持一致，避免同名历史文件逻辑漂移 |

---

### Task 1: 在详情页建立统一 Markdown 渲染入口

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 写一个失败场景（人工回归用例）**

在历史详情准备一条包含以下内容的 summary 数据（可通过已有 AI 记录或本地 mock）：

````markdown
客观总结：
今天完成了 `syncNow()` 的串联。

主观评价：
==节奏不错==，但代码块可读性还需优化。

```swift
func demo() { print("hello") }
```
````

预期当前（改动前）失败表现：部分区块显示原始 Markdown 语法、客观总结字号与正文接近、段落卡片透明感过强。

- [ ] **Step 2: 在 `iOSConversationSummaryDetailView` 新增统一渲染函数**

在该结构体内新增（或整合）以下函数签名，并让所有读态文本调用它：

```swift
@ViewBuilder
private func styledMarkdown(_ content: String, compact: Bool = false) -> some View

private func markdownView(_ content: String, compact: Bool = false) -> some View

private func normalizedMarkdown(_ rawText: String) -> String

private func splitSummarySections(from rawText: String) -> (objective: String, subjective: String?)
```

- [ ] **Step 3: 让总结/发现/建议/流水账都走统一 Markdown 渲染**

将以下读态分支替换为 `styledMarkdown(...)`：

```swift
summarySection(_:)
findingsSection(_:)
suggestionsSection(_:)
longFormSection(summaryID:)
```

并保持编辑态 (`TextEditor`) 分支不变。

- [ ] **Step 4: 运行 iOS 编译验证**

Run:

```bash
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'generic/platform=iOS' build
```

Expected: BUILD SUCCEEDED，且 `iOSConversationView.swift` 无语法/类型错误。

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios): unify markdown rendering in history detail"
```

---

### Task 2: 落地三项视觉规则（高亮/小字号/半透明段落卡片）

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 实现 Markdown 文本样式规则**

在 `markdownView` 中配置：

```swift
.markdownTextStyle {
    BackgroundColor(nil)
    ForegroundColor(compact ? .secondary : .primary)
    if compact {
        FontSize(.em(0.9))
    }
}
.markdownTextStyle(\.code) {
    FontFamilyVariant(.monospaced)
    FontSize(.em(0.88))
    BackgroundColor(.blue.opacity(0.16))
}
.markdownTextStyle(\.strong) {
    FontWeight(.bold)
    ForegroundColor(.primary)
    BackgroundColor(.yellow.opacity(0.4))
}
```

并确保 `compact == true` 时字号下调（用于“客观总结”）。

- [ ] **Step 2: 实现段落与代码块容器样式**

在 `markdownView` 中配置：

```swift
.markdownBlockStyle(\.paragraph) { configuration in
    configuration.label
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
}

.markdownBlockStyle(\.codeBlock) { configuration in
    ScrollView(.horizontal, showsIndicators: true) {
        configuration.label
            .relativeLineSpacing(.em(0.2))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
}
```

- [ ] **Step 3: 在 summarySection 中明确“客观总结”使用 compact 模式**

确保如下调用存在：

```swift
styledMarkdown(sections.objective, compact: true)
```

并保持“主观评价”为默认字号：

```swift
styledMarkdown(subjective)
```

- [ ] **Step 4: 运行构建与单测回归**

Run:

```bash
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'generic/platform=iOS' build
```

Expected:
- `swift test` 通过（共享模块无回归）
- iOS build 成功

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat(ios): add compact objective text and translucent markdown cards"
```

---

### Task 3: 手工验收历史详情页

**Files:**
- No code changes expected

- [ ] **Step 1: 启动 iOS 端并打开复盘历史详情**

使用 Xcode 运行 iOS 目标，在“复盘历史 -> 复盘详情”中打开包含 Markdown 的记录。

- [ ] **Step 2: 按验收清单逐项检查**

检查项：

```text
1) 总结/发现/建议/流水账都能渲染 Markdown
2) ==高亮==（经归一化）和 **加粗** 可见
3) fenced code block 以代码块卡片显示，可横向滚动
4) 客观总结字号明显小于主观评价
5) 每个段落都有半透明底卡（非全透明）
```

- [ ] **Step 3: 记录结果并提交（仅当有修复）**

若发现问题并修复后执行：

```bash
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'generic/platform=iOS' build
git add -A
git commit -m "fix(ios): polish history markdown rendering acceptance issues"
```
