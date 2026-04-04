# AI Memory 落地设计

**日期：** 2026-04-04  
**状态：** 待实现

---

## 背景

当前 memory 机制存在三个核心问题：

1. **快照只在长文复盘后生成** — `performLongFormGeneration` 里才创建 `AIMemorySnapshot`，普通对话结束不更新记忆
2. **快照内容不是 AI 生成的** — 只是把 `computeContextMemory` 拼出的字符串直接存储，没有提炼或事实提取
3. **Token 无预算** — 注入 prompt 的记忆文本无长度上限，可能挤占日历事件的上下文空间

---

## 设计目标

- A：每次对话结束后，自动触发 memory 更新（同步，在 `finishAIConversation` 末尾，静默后台）
- B：实现分层压缩——当一周的日复盘积累到 ≥5 条时，或一月的周复盘 ≥3 条时，在同一 AI 调用里生成层级更高的记忆概要
- C：用 AI 提炼结构化要点（bullet facts），以自由文本形式写入 snapshot，不新增数据结构

---

## 数据流（改造后）

```
finishAIConversation()
  └→ summarizeConversation()          [AI call 1 — 不变]
  └→ saveConversationArchive()        [不变]
  └→ aiConversationState = .completed [UI 解锁]
  └→ performMemoryUpdate()            [AI call 2 — 新增，静默]
       ├→ 收集相关 summaries（context-aware，复用 computeContextMemory 选择逻辑）
       ├→ 检查分层压缩触发条件
       └→ compactMemory()             [新协议方法，返回 bullet facts 文本]
  └→ performLongFormGeneration()      [AI call 3 — 不变，移除原有快照逻辑]
```

---

## 组件设计

### 1. 新增协议方法：`AIConversationServing.compactMemory`

```swift
func compactMemory(
    recentSummaries: [AIConversationSummary],
    existingMemory: String?,
    configuration: ResolvedAIProviderConfiguration
) async throws -> String
```

**System prompt：**
> 你在帮助整理一位用户的时间记忆档案。根据提供的历史复盘摘要，提炼出这位用户最典型的时间习惯、重复模式和近期值得关注的变化。
> 要求：不超过 400 字，2-4 条要点，每条以 • 开头，聚焦于时间管理与任务执行的规律性观察，不输出 JSON，只输出纯文本。

**User prompt 结构：**
```
历史记忆（如有）：{existingMemory ?? "无"}

近期复盘摘要：
{recentSummaries 的 headline + summary，按时间倒序}

{如触发分层压缩，追加一段：}
注意：以上摘要已覆盖完整的[一周/一月]，请在要点末尾额外加一条 • 本[周/月]总体记忆：...
```

**返回：** 纯文本，直接存入 `AIMemorySnapshot.summary`

---

### 2. `OpenAICompatibleAIConversationService` 实现

实现 `compactMemory`，构造 prompt 并调用 `sendRequest`，直接返回文本（不解析 JSON）。

其他 service（`AnthropicConversationService`、`GeminiConversationService`、`DeepSeekConversationService`）通过各自的 `sendRequest` 调用相同的 prompt 实现，与现有 `summarizeConversation` 的委托模式一致。

---

### 3. `AppModel.performMemoryUpdate`

```swift
private func performMemoryUpdate(
    newSummary: AIConversationSummary,
    configuration: ResolvedAIProviderConfiguration
) async
```

**步骤：**
1. 使用与 `computeContextMemory` 相同的时间范围匹配逻辑，收集相关 summaries（包含 newSummary）
2. 检查分层压缩触发条件（见下节）
3. 调用 `aiConversationService.compactMemory(recentSummaries:existingMemory:configuration:)`
4. 构造新 `AIMemorySnapshot`，`sourceSummaryIDs` 包含所有参与压缩的 summary ID
5. 调用 `persistConversationArchive`（自动保留最新 3 条快照）

错误处理：失败时静默忽略（`try? await`），不影响主流程。

---

### 4. 分层压缩触发逻辑

在 `performMemoryUpdate` 内，调用 `compactMemory` 前检查：

| 条件 | 行为 |
|------|------|
| `newSummary.range == .today` 且本周 `.today` summaries ≥ 5 条 | 收集本周所有 `.today` summaries 加入 prompt，追加"本周总体记忆"指令 |
| `newSummary.range == .week` 且本月 `.week` summaries ≥ 3 条 | 收集本月所有 `.week` summaries 加入 prompt，追加"本月总体记忆"指令 |
| 其他情况 | 正常流程，只收集 `computeContextMemory` 选出的 summaries |

**注意：** 不新增 AI 调用，分层仅通过扩大输入和追加指令实现。

---

### 5. Token 预算（`currentAIConversationContext`）

```swift
let memoryBudget = 800
if let text = memoryText, text.count > memoryBudget {
    memoryText = String(text.prefix(memoryBudget)) + "…"
}
```

---

### 6. `performLongFormGeneration` 清理

移除原有的快照创建逻辑（约 780-800 行）：

```swift
// 删除：
let compactedText = computeContextMemory(...)
let newMemorySnapshot = AIMemorySnapshot(...)
var memorySnapshots = aiConversationArchive.memorySnapshots
memorySnapshots.append(newMemorySnapshot)
```

`updatedArchive` 中 `memorySnapshots` 直接使用 `aiConversationArchive.memorySnapshots`（memory 更新职责已迁移到 `performMemoryUpdate`）。

---

## 影响文件

| 文件 | 变更类型 |
|------|---------|
| `Sources/iTime/Services/AIConversationServing.swift` | 新增 `compactMemory` 方法签名 |
| `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` | 实现 `compactMemory` |
| `Sources/iTime/Services/AnthropicConversationService.swift` | 实现 `compactMemory` |
| `Sources/iTime/Services/GeminiConversationService.swift` | 实现 `compactMemory` |
| `Sources/iTime/Services/DeepSeekConversationService.swift` | 实现 `compactMemory` |
| `Sources/iTime/Services/OpenAICompatibleAIAnalysisService.swift` | 实现 `compactMemory`（如适用） |
| `Sources/iTime/App/AppModel.swift` | 新增 `performMemoryUpdate`，修改 `finishAIConversation`，修改 `performLongFormGeneration`，token budget |
| `Tests/` | 更新 stub/mock，更新受影响测试 |

---

## 约束与边界

- `performMemoryUpdate` 失败时静默忽略，不向用户暴露错误
- 手动从历史视图触发长文复盘时，不触发 `performMemoryUpdate`（仅 `finishAIConversation` 路径触发）
- `AIMemorySnapshot` 数据结构不变，仍保留最新 3 条
- 不新增 UI 状态变量（memory 更新对用户透明）
