# 流程图与流水账联合生成 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在生成流水账复盘时同时生成节点式流程图，两端（macOS + iOS）均渲染展示。

**Architecture:** 扩展现有 `AIConversationLongFormReport`，增加可选 `flowchart` 字段；AI prompt 扩展要求同时输出流程图 JSON；新增共享 `FlowchartView`，macOS 和 iOS 的复盘详情页各自插入。

**Tech Stack:** Swift 6, SwiftUI (Canvas + PreferenceKey for arrow layout), macOS 14+, iOS 17+

---

## File Map

| 操作 | 文件 | 职责 |
|------|------|------|
| 修改 | `Sources/iTime/Domain/AIConversation.swift` | 新增 `AIConversationFlowchart` / `FlowchartNode` / `FlowchartEdge`；扩展 `AIConversationLongFormReport` |
| 修改 | `Sources/iTime/Services/AIConversationServing.swift` | 扩展 `AIConversationLongFormReportDraft` |
| 修改 | `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` | 更新 prompt、`LongFormPayload`、`generateLongFormReport` |
| 修改 | `Sources/iTime/Services/GeminiConversationService.swift` | 更新 `GeminiLongFormPayload`、`generateLongFormReport` |
| 修改 | `Sources/iTime/App/AppModel.swift` | `performLongFormGeneration` 存储 flowchart |
| 新建 | `Sources/iTime/UI/AIConversation/FlowchartView.swift` | 共享 SwiftUI 流程图组件 |
| 修改 | `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift` | macOS 复盘详情页插入 FlowchartView |
| 修改 | `iTime-iOS/UI/Conversation/iOSConversationView.swift` | iOS 复盘详情页插入 FlowchartView |
| 修改 | `Tests/iTimeTests/AIConversationServiceTests.swift` | 更新 longForm 测试，覆盖 flowchart |
| 修改 | `Tests/iTimeTests/AIConversationAppModelTests.swift` | 更新 longForm 测试，覆盖 flowchart |

---

## Task 1: 添加 Domain Model — Flowchart 类型 + 扩展 LongFormReport

**Files:**
- Modify: `Sources/iTime/Domain/AIConversation.swift`
- Test: `Tests/iTimeTests/AIConversationArchiveStoreTests.swift`（已有文件，追加一个新测试）

### 步骤

- [ ] **Step 1: 在 `AIConversation.swift` 添加三个新类型**

在 `AIConversationLongFormReport` 定义的**前面**插入：

```swift
public struct AIConversationFlowchart: Equatable, Codable, Sendable {
    public let nodes: [FlowchartNode]
    public let edges: [FlowchartEdge]

    public init(nodes: [FlowchartNode], edges: [FlowchartEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

public struct FlowchartNode: Equatable, Codable, Sendable {
    public let id: String
    public let timeRange: String
    public let title: String
    public let calendarName: String?

    public init(id: String, timeRange: String, title: String, calendarName: String? = nil) {
        self.id = id
        self.timeRange = timeRange
        self.title = title
        self.calendarName = calendarName
    }
}

public struct FlowchartEdge: Equatable, Codable, Sendable {
    public let from: String
    public let to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}
```

- [ ] **Step 2: 扩展 `AIConversationLongFormReport`**

找到现有定义：
```swift
public struct AIConversationLongFormReport: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let summaryID: UUID
    public let createdAt: Date
    public let updatedAt: Date
    public let title: String
    public let content: String
```

将属性列表改为（追加 `flowchart`）：
```swift
public struct AIConversationLongFormReport: Equatable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public let summaryID: UUID
    public let createdAt: Date
    public let updatedAt: Date
    public let title: String
    public let content: String
    public let flowchart: AIConversationFlowchart?
```

找到现有 `init`：
```swift
    public init(
        id: UUID,
        sessionID: UUID,
        summaryID: UUID,
        createdAt: Date,
        updatedAt: Date,
        title: String,
        content: String
    ) {
        self.id = id
        self.sessionID = sessionID
        self.summaryID = summaryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.content = content
    }
```

替换为：
```swift
    public init(
        id: UUID,
        sessionID: UUID,
        summaryID: UUID,
        createdAt: Date,
        updatedAt: Date,
        title: String,
        content: String,
        flowchart: AIConversationFlowchart? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.summaryID = summaryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.content = content
        self.flowchart = flowchart
    }
```

找到 `updating` 方法：
```swift
    public func updating(title: String, content: String, updatedAt: Date) -> AIConversationLongFormReport {
        AIConversationLongFormReport(
            id: id,
            sessionID: sessionID,
            summaryID: summaryID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            content: content,
        )
    }
```

替换为（保留 flowchart）：
```swift
    public func updating(title: String, content: String, updatedAt: Date) -> AIConversationLongFormReport {
        AIConversationLongFormReport(
            id: id,
            sessionID: sessionID,
            summaryID: summaryID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            content: content,
            flowchart: flowchart
        )
    }
```

还需要为 `AIConversationLongFormReport` 添加 `Codable` 支持（使用 `decodeIfPresent` 保证旧数据兼容）。找到 `AIConversationLongFormReport` 的 `encode` 和 `init(from:)`（如果没有自定义 Codable，则添加）：

```swift
    private enum CodingKeys: String, CodingKey {
        case id, sessionID, summaryID, createdAt, updatedAt, title, content, flowchart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        summaryID = try container.decode(UUID.self, forKey: .summaryID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        flowchart = try container.decodeIfPresent(AIConversationFlowchart.self, forKey: .flowchart)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(summaryID, forKey: .summaryID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(flowchart, forKey: .flowchart)
    }
```

> **注意**：如果 `AIConversationLongFormReport` 目前依赖 synthesized Codable（没有自定义 `init(from:)` 和 `encode(to:)`），直接添加上述自定义实现即可替换合成版本。

- [ ] **Step 3: 写测试 — Codable 向后兼容**

在 `Tests/iTimeTests/AIConversationArchiveStoreTests.swift` 末尾追加：

```swift
@Test func longFormReportDecodesWithoutFlowchartForBackwardCompatibility() throws {
    let json = """
    {
      "id": "11111111-0000-0000-0000-000000000000",
      "sessionID": "22222222-0000-0000-0000-000000000000",
      "summaryID": "33333333-0000-0000-0000-000000000000",
      "createdAt": 0,
      "updatedAt": 0,
      "title": "旧报告",
      "content": "旧内容"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let report = try decoder.decode(AIConversationLongFormReport.self, from: Data(json.utf8))
    #expect(report.title == "旧报告")
    #expect(report.flowchart == nil)
}

@Test func longFormReportEncodesAndDecodesFlowchart() throws {
    let flowchart = AIConversationFlowchart(
        nodes: [
            FlowchartNode(id: "n1", timeRange: "09:00-09:30", title: "早会", calendarName: "工作"),
            FlowchartNode(id: "n2", timeRange: "09:30-11:00", title: "写代码", calendarName: nil),
        ],
        edges: [FlowchartEdge(from: "n1", to: "n2")]
    )
    let original = AIConversationLongFormReport(
        id: UUID(),
        sessionID: UUID(),
        summaryID: UUID(),
        createdAt: .init(timeIntervalSince1970: 0),
        updatedAt: .init(timeIntervalSince1970: 0),
        title: "标题",
        content: "内容",
        flowchart: flowchart
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let data = try encoder.encode(original)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(AIConversationLongFormReport.self, from: data)
    #expect(decoded.flowchart == flowchart)
    #expect(decoded.flowchart?.nodes.count == 2)
    #expect(decoded.flowchart?.edges.count == 1)
}
```

- [ ] **Step 4: Run tests**

```bash
swift test --filter iTimeTests.AIConversationArchiveStoreTests
```

Expected: 两个新测试 PASS，现有测试不回归。

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Domain/AIConversation.swift Tests/iTimeTests/AIConversationArchiveStoreTests.swift
git commit -m "feat: add AIConversationFlowchart domain model and extend LongFormReport"
```

---

## Task 2: 扩展 Draft Model

**Files:**
- Modify: `Sources/iTime/Services/AIConversationServing.swift`

- [ ] **Step 1: 扩展 `AIConversationLongFormReportDraft`**

找到：
```swift
public struct AIConversationLongFormReportDraft: Equatable, Sendable {
    public let title: String
    public let content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}
```

替换为：
```swift
public struct AIConversationLongFormReportDraft: Equatable, Sendable {
    public let title: String
    public let content: String
    public let flowchart: AIConversationFlowchart?

    public init(title: String, content: String, flowchart: AIConversationFlowchart? = nil) {
        self.title = title
        self.content = content
        self.flowchart = flowchart
    }
}
```

- [ ] **Step 2: Build — 确认编译通过**

```bash
swift build 2>&1 | head -30
```

Expected: 仅现有使用 `AIConversationLongFormReportDraft(title:content:)` 的地方因 `flowchart` 有默认值而无需修改，编译通过。

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/Services/AIConversationServing.swift
git commit -m "feat: add flowchart field to AIConversationLongFormReportDraft"
```

---

## Task 3: 更新 AI 服务层 Prompt 和 Payload

**Files:**
- Modify: `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift`
- Modify: `Sources/iTime/Services/GeminiConversationService.swift`
- Test: `Tests/iTimeTests/AIConversationServiceTests.swift`

### OpenAICompatible 服务

- [ ] **Step 1: 先写两个失败测试**

在 `Tests/iTimeTests/AIConversationServiceTests.swift` 末尾（`@Test func geminiConversationServiceIncludesJsonMimeTypeInRequest` 之前）追加：

```swift
@Test func openAICompatibleLongFormReportIncludesFlowchartWhenPresentInResponse() async throws {
    let responseJSON = """
    {
      "choices": [{
        "message": {
          "content": "{\\"title\\":\\"当日复盘\\",\\"content\\":\\"流水账正文。\\",\\"flowchart\\":{\\"nodes\\":[{\\"id\\":\\"n1\\",\\"timeRange\\":\\"09:00-09:30\\",\\"title\\":\\"早会\\",\\"calendarName\\":\\"工作\\"},{\\"id\\":\\"n2\\",\\"timeRange\\":\\"09:30-11:00\\",\\"title\\":\\"写代码\\",\\"calendarName\\":null}],\\"edges\\":[{\\"from\\":\\"n1\\",\\"to\\":\\"n2\\"}]}}"
        }
      }]
    }
    """
    let sender = ConversationRecordingAIHTTPSender(responseData: Data(responseJSON.utf8))
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let session = AIConversationSession(
        id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
        model: "gpt-5-mini", range: .today,
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: 86_400),
        startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(rangeTitle: "今天", totalDurationText: "3h", totalEventCount: 2, topCalendarNames: ["工作"]),
        messages: []
    )
    let summary = AIConversationSummary(
        id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "OpenAI",
        provider: .openAI, model: "gpt-5-mini", range: .today,
        startDate: session.startDate, endDate: session.endDate,
        createdAt: session.endDate, headline: "标题",
        summary: "摘要", findings: [], suggestions: [],
        overviewSnapshot: session.overviewSnapshot
    )
    let draft = try await service.generateLongFormReport(
        session: session, summary: summary,
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI, baseURL: "https://example.com/v1",
            model: "gpt-5-mini", apiKey: "key", isEnabled: true
        )
    )
    #expect(draft.flowchart?.nodes.count == 2)
    #expect(draft.flowchart?.nodes.first?.id == "n1")
    #expect(draft.flowchart?.nodes.first?.title == "早会")
    #expect(draft.flowchart?.edges.count == 1)
    #expect(draft.flowchart?.edges.first?.from == "n1")
    #expect(draft.flowchart?.edges.first?.to == "n2")
}

@Test func openAICompatibleLongFormReportFlowchartIsNilWhenAbsentFromResponse() async throws {
    let responseJSON = """
    {
      "choices": [{
        "message": {
          "content": "{\\"title\\":\\"当日复盘\\",\\"content\\":\\"流水账正文。\\"}"
        }
      }]
    }
    """
    let sender = ConversationRecordingAIHTTPSender(responseData: Data(responseJSON.utf8))
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let session = AIConversationSession(
        id: UUID(), serviceID: nil, serviceDisplayName: "OpenAI", provider: .openAI,
        model: "gpt-5-mini", range: .today,
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: 86_400),
        startedAt: Date(timeIntervalSince1970: 0), completedAt: nil,
        status: .completed,
        overviewSnapshot: AIOverviewSnapshot(rangeTitle: "今天", totalDurationText: "3h", totalEventCount: 2, topCalendarNames: ["工作"]),
        messages: []
    )
    let summary = AIConversationSummary(
        id: UUID(), sessionID: session.id, serviceID: nil, serviceDisplayName: "OpenAI",
        provider: .openAI, model: "gpt-5-mini", range: .today,
        startDate: session.startDate, endDate: session.endDate,
        createdAt: session.endDate, headline: "标题",
        summary: "摘要", findings: [], suggestions: [],
        overviewSnapshot: session.overviewSnapshot
    )
    let draft = try await service.generateLongFormReport(
        session: session, summary: summary,
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAI, baseURL: "https://example.com/v1",
            model: "gpt-5-mini", apiKey: "key", isEnabled: true
        )
    )
    #expect(draft.flowchart == nil)
}
```

- [ ] **Step 2: Run tests — 确认新测试失败（flowchart 尚未实现）**

```bash
swift test --filter iTimeTests.AIConversationServiceTests 2>&1 | tail -20
```

Expected: 两个新测试 FAIL（`draft.flowchart` 为 nil），其余测试 PASS。

- [ ] **Step 3: 更新 `longFormSystemPrompt`**

找到：
```swift
    static let longFormSystemPrompt = """
    你是用户的一位朋友，帮他/她写一篇流水账复盘，使用平实的语言，不要渲染感情，不要升华，不要堆砌辞藻，不要洞察内心，只需要用平实的语言记录好这一天。
    """
```

替换为：
```swift
    static let longFormSystemPrompt = """
    你是用户的一位朋友，帮他/她写一篇流水账复盘，使用平实的语言，不要渲染感情，不要升华，不要堆砌辞藻，不要洞察内心，只需要用平实的语言记录好这一天。
    同时输出一份当天的节点式流程图。把时间相近、性质相同的事件合并为节点，允许并行分支。每个节点有唯一 id（如 "n1"）、时间段（timeRange，格式 "HH:mm-HH:mm"）、标题（title）、主要日历名（calendarName，若无则为 null）。edges 描述节点间的流转关系，每条 edge 有 from 和 to（均为 node id）。
    """
```

- [ ] **Step 4: 更新 `LongFormPayload`**

找到：
```swift
private struct LongFormPayload: Decodable {
    let title: String
    let content: String
}
```

替换为：
```swift
private struct LongFormPayload: Decodable {
    let title: String
    let content: String
    let flowchart: AIConversationFlowchart?
}
```

- [ ] **Step 5: 更新 `generateLongFormReport` 返回值**

找到：
```swift
        return AIConversationLongFormReportDraft(
            title: payload.title,
            content: payload.content
        )
```

替换为：
```swift
        return AIConversationLongFormReportDraft(
            title: payload.title,
            content: payload.content,
            flowchart: payload.flowchart
        )
```

- [ ] **Step 6: Run tests**

```bash
swift test --filter iTimeTests.AIConversationServiceTests 2>&1 | tail -20
```

Expected: 所有测试 PASS，包括两个新测试。

- [ ] **Step 7: 更新 Gemini 服务**

在 `GeminiConversationService.swift` 找到：
```swift
private struct GeminiLongFormPayload: Decodable {
    let title: String
    let content: String
}
```

替换为：
```swift
private struct GeminiLongFormPayload: Decodable {
    let title: String
    let content: String
    let flowchart: AIConversationFlowchart?
}
```

找到：
```swift
        return AIConversationLongFormReportDraft(title: payload.title, content: payload.content)
```

替换为：
```swift
        return AIConversationLongFormReportDraft(title: payload.title, content: payload.content, flowchart: payload.flowchart)
```

- [ ] **Step 8: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: 全部 PASS。

- [ ] **Step 9: Commit**

```bash
git add Sources/iTime/Services/OpenAICompatibleAIConversationService.swift Sources/iTime/Services/GeminiConversationService.swift Tests/iTimeTests/AIConversationServiceTests.swift
git commit -m "feat: extend long-form AI prompt and payload to include flowchart"
```

---

## Task 4: AppModel — 存储 flowchart

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: 先更新 `RecordingAIConversationService` 的 mock 和测试**

在 `Tests/iTimeTests/AIConversationAppModelTests.swift` 找到 `RecordingAIConversationService` 中：
```swift
        longFormDraft: AIConversationLongFormReportDraft = AIConversationLongFormReportDraft(
            title: "本周流水账复盘",
            content: "这是一篇基于原始对话生成的流水账复盘。"
        ),
```

以及 `generatingLongFormReportPersistsReportFromConversationSession` 测试中：
```swift
    let conversationService = RecordingAIConversationService(
        longFormDraft: AIConversationLongFormReportDraft(
            title: "本周复盘流水账",
            content: "这是一篇基于原始对话生成的流水账复盘。"
        )
    )
```

将该测试的 draft 改为包含 flowchart：
```swift
    let conversationService = RecordingAIConversationService(
        longFormDraft: AIConversationLongFormReportDraft(
            title: "本周复盘流水账",
            content: "这是一篇基于原始对话生成的流水账复盘。",
            flowchart: AIConversationFlowchart(
                nodes: [
                    FlowchartNode(id: "n1", timeRange: "09:00-10:00", title: "需求评审", calendarName: "工作"),
                ],
                edges: []
            )
        )
    )
```

在测试末尾追加断言：
```swift
    #expect(report.flowchart?.nodes.count == 1)
    #expect(report.flowchart?.nodes.first?.id == "n1")
```

- [ ] **Step 2: Run test — 确认失败（AppModel 尚未透传 flowchart）**

```bash
swift test --filter "iTimeTests.AIConversationAppModelTests/generatingLongFormReportPersistsReportFromConversationSession" 2>&1 | tail -10
```

Expected: FAIL（`report.flowchart` 为 nil）。

- [ ] **Step 3: 更新 `performLongFormGeneration` in AppModel.swift**

找到：
```swift
            let report = AIConversationLongFormReport(
                id: existingID,
                sessionID: summary.sessionID,
                summaryID: summaryID,
                createdAt: createdAt,
                updatedAt: nowDate,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
```

替换为：
```swift
            let report = AIConversationLongFormReport(
                id: existingID,
                sessionID: summary.sessionID,
                summaryID: summaryID,
                createdAt: createdAt,
                updatedAt: nowDate,
                title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines),
                flowchart: draft.flowchart
            )
```

- [ ] **Step 4: Run all tests**

```bash
swift test 2>&1 | tail -20
```

Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/App/AppModel.swift Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: persist flowchart from long-form draft to stored report"
```

---

## Task 5: 新建共享 `FlowchartView`

**Files:**
- Create: `Sources/iTime/UI/AIConversation/FlowchartView.swift`

- [ ] **Step 1: 创建文件并实现拓扑排序辅助函数**

创建 `Sources/iTime/UI/AIConversation/FlowchartView.swift`：

```swift
import SwiftUI

// MARK: - Layout Algorithm

/// Assigns a display level (0-based) to each node using topological BFS.
/// Nodes at the same level are rendered in the same row.
/// Isolated nodes (not in any edge) are appended after connected nodes.
func flowchartAssignLevels(
    nodes: [FlowchartNode],
    edges: [FlowchartEdge]
) -> [String: Int] {
    let validIDs = Set(nodes.map(\.id))
    var successors: [String: [String]] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, []) })
    var predecessorCount: [String: Int] = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, 0) })

    for edge in edges where validIDs.contains(edge.from) && validIDs.contains(edge.to) {
        successors[edge.from, default: []].append(edge.to)
        predecessorCount[edge.to, default: 0] += 1
    }

    var levels: [String: Int] = [:]
    var queue: [String] = predecessorCount.filter { $0.value == 0 }.map(\.key).sorted()
    queue.forEach { levels[$0] = 0 }

    var head = 0
    while head < queue.count {
        let id = queue[head]; head += 1
        let currentLevel = levels[id] ?? 0
        for successor in successors[id, default: []] {
            let proposed = currentLevel + 1
            if proposed > (levels[successor] ?? 0) {
                levels[successor] = proposed
            }
            predecessorCount[successor, default: 1] -= 1
            if predecessorCount[successor, default: 0] <= 0 {
                queue.append(successor)
            }
        }
    }

    // Isolated nodes: not referenced in any edge
    let connectedIDs = Set(edges.flatMap { [$0.from, $0.to] })
    let isolated = nodes.filter { !connectedIDs.contains($0.id) }
        .sorted { $0.timeRange < $1.timeRange }
    let maxLevel = levels.values.max() ?? -1
    for (offset, node) in isolated.enumerated() {
        levels[node.id] = maxLevel + 1 + offset
    }

    // Any remaining nodes not reached by BFS (e.g. in a cycle) get appended
    let finalMax = levels.values.max() ?? 0
    for node in nodes where levels[node.id] == nil {
        levels[node.id] = finalMax + 1
    }

    return levels
}

// MARK: - Preference Key for Node Frames

private struct NodeFrameValue: Equatable {
    let id: String
    let frame: CGRect
}

private struct NodeFrameKey: PreferenceKey {
    static let defaultValue: [NodeFrameValue] = []
    static func reduce(value: inout [NodeFrameValue], nextValue: () -> [NodeFrameValue]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - FlowchartView

struct FlowchartView: View {
    let flowchart: AIConversationFlowchart

    @State private var nodeFrames: [String: CGRect] = [:]

    private let nodeWidth: CGFloat = 140
    private let horizontalSpacing: CGFloat = 16
    private let verticalSpacing: CGFloat = 48

    private var leveledRows: [[FlowchartNode]] {
        let levels = flowchartAssignLevels(nodes: flowchart.nodes, edges: flowchart.edges)
        guard !levels.isEmpty else { return [] }
        let maxLevel = levels.values.max() ?? 0
        return (0...maxLevel).map { level in
            flowchart.nodes
                .filter { levels[$0.id] == level }
                .sorted { $0.timeRange < $1.timeRange }
        }
    }

    var body: some View {
        if flowchart.nodes.isEmpty {
            Text("暂无流程数据")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    nodeGrid
                        .coordinateSpace(name: "flowchart")

                    Canvas { ctx, _ in
                        drawEdges(ctx: ctx)
                    }
                    .allowsHitTesting(false)
                }
                .padding()
            }
            .onPreferenceChange(NodeFrameKey.self) { values in
                nodeFrames = Dictionary(values.map { ($0.id, $0.frame) }, uniquingKeysWith: { _, last in last })
            }
        }
    }

    private var nodeGrid: some View {
        VStack(alignment: .center, spacing: verticalSpacing) {
            ForEach(Array(leveledRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: horizontalSpacing) {
                    ForEach(row, id: \.id) { node in
                        FlowchartNodeView(node: node)
                            .frame(width: nodeWidth)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: NodeFrameKey.self,
                                        value: [NodeFrameValue(
                                            id: node.id,
                                            frame: geo.frame(in: .named("flowchart"))
                                        )]
                                    )
                                }
                            )
                    }
                }
            }
        }
    }

    private func drawEdges(ctx: GraphicsContext) {
        for edge in flowchart.edges {
            guard
                let fromFrame = nodeFrames[edge.from],
                let toFrame = nodeFrames[edge.to]
            else { continue }

            let start = CGPoint(x: fromFrame.midX, y: fromFrame.maxY)
            let end = CGPoint(x: toFrame.midX, y: toFrame.minY)

            var path = Path()
            // Curved line
            let midY = (start.y + end.y) / 2
            path.move(to: start)
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: midY),
                control2: CGPoint(x: end.x, y: midY)
            )
            ctx.stroke(path, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5))

            // Arrowhead
            let arrowSize: CGFloat = 6
            let angle = atan2(end.y - midY, end.x - toFrame.midX)
            let leftWing = CGPoint(
                x: end.x - arrowSize * cos(angle - .pi / 6),
                y: end.y - arrowSize * sin(angle - .pi / 6)
            )
            let rightWing = CGPoint(
                x: end.x - arrowSize * cos(angle + .pi / 6),
                y: end.y - arrowSize * sin(angle + .pi / 6)
            )
            var arrowPath = Path()
            arrowPath.move(to: end)
            arrowPath.addLine(to: leftWing)
            arrowPath.move(to: end)
            arrowPath.addLine(to: rightWing)
            ctx.stroke(arrowPath, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}

// MARK: - Node View

private struct FlowchartNodeView: View {
    let node: FlowchartNode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.timeRange)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(node.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let calendarName = node.calendarName {
                Text(calendarName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | grep -E "error:|warning:" | head -20
```

Expected: 0 errors。

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/AIConversation/FlowchartView.swift
git commit -m "feat: add shared FlowchartView with topological layout and Canvas arrows"
```

---

## Task 6: macOS — 在复盘详情页插入 FlowchartView

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`

- [ ] **Step 1: 在 `longFormSection` 中插入 `FlowchartView`**

在 `AIConversationHistoryView.swift` 找到 `longFormSection` 里展示报告内容的代码段：

```swift
            if let report = model.longFormReport(for: summary.id) {
                if isEditingLongForm {
                    TextField("流水账标题", text: $longFormTitleDraft)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $longFormContentDraft)
                        .frame(minHeight: 220)
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Text(report.title)
                        .font(.headline)

                    styledMarkdown(report.content)
                }
```

替换 `else` 分支（只读展示部分）为：
```swift
                } else {
                    Text(report.title)
                        .font(.headline)

                    styledMarkdown(report.content)

                    if let flowchart = report.flowchart {
                        Text("当日流程图")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)

                        FlowchartView(flowchart: flowchart)
                            .frame(minHeight: 200)
                    }
                }
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | grep "error:" | head -10
```

Expected: 0 errors。

- [ ] **Step 3: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift
git commit -m "feat: show FlowchartView in macOS long-form detail section"
```

---

## Task 7: iOS — 在复盘详情页插入 FlowchartView

**Files:**
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`

- [ ] **Step 1: 在 iOS `longFormSection` 中插入 `FlowchartView`**

在 `iOSConversationView.swift` 找到 `longFormSection(summaryID:)` 里展示报告的代码段：

```swift
            if let report = model.longFormReport(for: summaryID) {
                Text(report.title)
                    .font(.subheadline.weight(.semibold))
                Markdown(report.content)
```

替换为：
```swift
            if let report = model.longFormReport(for: summaryID) {
                Text(report.title)
                    .font(.subheadline.weight(.semibold))
                Markdown(report.content)

                if let flowchart = report.flowchart {
                    Text("当日流程图")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)

                    FlowchartView(flowchart: flowchart)
                        .frame(minHeight: 180)
                }
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | grep "error:" | head -10
```

Expected: 0 errors。

- [ ] **Step 3: Run all tests — final check**

```bash
swift test 2>&1 | tail -20
```

Expected: 全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/UI/Conversation/iOSConversationView.swift
git commit -m "feat: show FlowchartView in iOS long-form detail section"
```

---

## 自检（Spec Coverage）

| 设计要求 | 覆盖任务 |
|----------|---------|
| 新增 `AIConversationFlowchart` / `FlowchartNode` / `FlowchartEdge` | Task 1 |
| 旧数据向后兼容（`decodeIfPresent`） | Task 1 Step 2 + 测试 |
| AI prompt 扩展 | Task 3 Step 3 |
| 一次调用联合输出 | Task 3（`LongFormPayload` 扩展） |
| Gemini 自动复用 | Task 3 Step 7 |
| AppModel 存储 flowchart | Task 4 |
| 共享 `FlowchartView` | Task 5 |
| 拓扑排序 + 分层布局 | Task 5（`flowchartAssignLevels`） |
| Canvas 画有向箭头 | Task 5（`drawEdges`） |
| 孤立节点处理 | Task 5（`flowchartAssignLevels` 末尾） |
| 节点为空时占位文字 | Task 5（`if flowchart.nodes.isEmpty`） |
| macOS 插入 | Task 6 |
| iOS 插入 | Task 7 |
| `updating()` 保留 flowchart | Task 1 Step 2 |
