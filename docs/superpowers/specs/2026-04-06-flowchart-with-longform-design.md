# 流程图与流水账联合生成 — 设计文档

**日期**：2026-04-06  
**状态**：已批准  
**范围**：macOS + iOS 双端适配

---

## 背景

现有"流水账复盘"功能（`AIConversationLongFormReport`）生成一篇叙述性文章。用户希望在同一次 AI 调用中同时生成一份节点式流程图，直观展示当天日程的流转关系，并在两端的复盘详情页中展示。

---

## 目标

- AI 一次调用同时输出流水账文字 + 流程图数据
- 流程图为节点式（圆角矩形节点 + 有向连线），支持并行分支
- macOS 和 iOS 共用同一个 `FlowchartView` 组件
- 旧数据（无流程图字段）向后兼容，不崩溃，不显示流程图区域

---

## Domain Model

### 新增结构（`AIConversation.swift`）

```swift
public struct AIConversationFlowchart: Equatable, Codable, Sendable {
    public let nodes: [FlowchartNode]
    public let edges: [FlowchartEdge]
}

public struct FlowchartNode: Equatable, Codable, Sendable {
    public let id: String           // AI 分配的稳定 ID，供 edge 引用
    public let timeRange: String    // 例："09:00-10:30"
    public let title: String        // 合并后的事件名称
    public let calendarName: String? // 主要日历名（可选）
}

public struct FlowchartEdge: Equatable, Codable, Sendable {
    public let from: String  // node.id
    public let to: String    // node.id
}
```

### 修改 `AIConversationLongFormReport`

增加可选字段：

```swift
public let flowchart: AIConversationFlowchart?
```

- `init` 新增 `flowchart: AIConversationFlowchart? = nil` 参数
- `encode` 用 `encodeIfPresent`
- `decode` 用 `decodeIfPresent`（保证旧数据兼容）
- `updating(title:content:updatedAt:)` 增加 `flowchart` 参数透传

---

## AI Prompt 变更

### 修改位置

`Sources/iTime/Services/OpenAICompatibleAIConversationService.swift`

### `longFormSystemPrompt` 追加

```
同时输出一份当天的节点式流程图。把时间相近、性质相同的事件合并为节点，允许并行分支。
每个节点有唯一 id（如 "n1"）、时间段（timeRange）、标题（title）、主要日历名（calendarName，可为 null）。
edges 描述节点间的流转关系（from → to）。
```

### JSON 响应格式

从：
```json
{"title":"...","content":"..."}
```

变为：
```json
{
  "title": "...",
  "content": "...",
  "flowchart": {
    "nodes": [
      {"id":"n1","timeRange":"09:00-09:30","title":"早会","calendarName":"工作"},
      {"id":"n2","timeRange":"09:30-11:00","title":"写代码","calendarName":"工作"},
      {"id":"n3","timeRange":"09:30-10:00","title":"处理消息","calendarName":"沟通"}
    ],
    "edges": [
      {"from":"n1","to":"n2"},
      {"from":"n1","to":"n3"},
      {"from":"n3","to":"n2"}
    ]
  }
}
```

### `LongFormPayload`（服务层内部解码结构）

增加 `flowchart: AIConversationFlowchart?`（`decodeIfPresent`），解码失败不影响文字部分。

### Gemini

`GeminiConversationService` 已复用 `OpenAICompatibleAIConversationService.longFormSystemPrompt` 和 `longFormUserPrompt`，prompt 更新后自动生效，无需额外改动。

---

## 渲染层 — `FlowchartView`

### 文件位置

`Sources/iTime/UI/AIConversation/FlowchartView.swift`

### 布局算法

1. 从 `edges` 构建有向图
2. BFS 拓扑排序，给每个 node 分配 `level`（整数层号）
3. 孤立节点（不在任何 edge 中）按 `timeRange` 字符串排序，追加在所有有连接节点之后
4. 每个 `level` 为一横行，同行节点水平排列
5. `Canvas` overlay 绘制有向箭头：上层节点底部中心 → 下层节点顶部中心

### 节点视觉

- 圆角矩形，风格参考 `LiquidGlassCard`
- 内容从上到下：`timeRange`（caption，次要色）→ `title`（body weight semibold）→ `calendarName`（caption，次要色，可选）
- 固定宽度（约 140pt），高度自适应
- 节点间水平间距 16pt，行间竖向间距 40pt（为箭头留空间）

### 整体布局

- 外层 `ScrollView`（水平 + 竖向），节点多时不截断
- iOS 窄屏：节点宽度收窄至约屏幕宽度 40%（最小 120pt）

### 边界情况

| 情况 | 处理 |
|------|------|
| `flowchart == nil` | 不显示流程图区域 |
| `nodes` 为空 | 显示"暂无流程数据" |
| edge 引用了不存在的 node id | 忽略该 edge，不崩溃 |
| 存在环（理论上 AI 不会输出，但防御） | BFS 检测已访问节点，跳过形成环的 edge |

---

## macOS 适配

**文件**：`Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`

在 `AIConversationSummaryDetailView.longFormSection` 中，流水账正文下方插入：

```
[流水账标题]
[流水账正文 Markdown]
──── 当日流程图 ────   ← 新增分隔标题
FlowchartView(flowchart: report.flowchart)  ← 新增，flowchart 为 nil 时隐藏
```

生成/重新生成按钮无需变更，一次触发同时生成文字与流程图。

---

## iOS 适配

**文件**：`iTime-iOS/UI/Conversation/iOSConversationView.swift`（内的 `iOSConversationSummaryDetailView`）

`longFormSection` 同样在流水账正文后插入 `FlowchartView`，布局与 macOS 一致。

---

## 不在范围内

- 流程图的独立重新生成（总是与流水账一起生成）
- 节点点击交互（仅展示）
- 流程图导出到 Markdown（导出内容不变，仍为文字部分）
