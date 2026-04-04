# AI Memory 落地 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 memory 在每次对话结束后自动 AI 更新、支持分层压缩，并注入 token 预算截断。

**Architecture:** 在 `AIConversationServing` 协议上新增 `compactMemory` 方法；`AppModel` 新增 `performMemoryUpdate` 在 `finishAIConversation` 末尾静默调用；分层压缩通过向同一 AI 调用传入更多 summaries 触发；`performLongFormGeneration` 不再负责创建 snapshot。

**Tech Stack:** Swift 6, Swift Testing framework (`@Test`), `@MainActor` AppModel, `AIAnalysisHTTPSending` protocol for HTTP stubbing.

---

## File Map

| 文件 | 变更类型 |
|------|---------|
| `Sources/iTime/Services/AIConversationServing.swift` | 新增 `compactMemory` 方法到协议 |
| `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` | 实现 `compactMemory`，新增 prompt，`sendRequest` 增加 `responseFormatType` 参数 |
| `Sources/iTime/Services/AnthropicConversationService.swift` | 实现 `compactMemory` |
| `Sources/iTime/Services/GeminiConversationService.swift` | 实现 `compactMemory`，`sendRequest` 增加 `responseMimeType` 参数 |
| `Sources/iTime/Services/DeepSeekConversationService.swift` | 实现 `compactMemory`（委托） |
| `Sources/iTime/Services/AIConversationRoutingService.swift` | 实现 `compactMemory`（路由） |
| `Sources/iTime/App/AppModel.swift` | 新增 `performMemoryUpdate`，修改 `finishAIConversation`，修改 `performLongFormGeneration`，token budget |
| `Tests/iTimeTests/AIConversationServiceTests.swift` | 新增 `compactMemory` 服务测试 |
| `Tests/iTimeTests/AIConversationAppModelTests.swift` | 更新 `RecordingAIConversationService`，新增 AppModel memory 测试 |

---

### Task 1: 协议新增方法 + 所有实现的编译占位

**Files:**
- Modify: `Sources/iTime/Services/AIConversationServing.swift`
- Modify: `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift`
- Modify: `Sources/iTime/Services/AnthropicConversationService.swift`
- Modify: `Sources/iTime/Services/GeminiConversationService.swift`
- Modify: `Sources/iTime/Services/DeepSeekConversationService.swift`
- Modify: `Sources/iTime/Services/AIConversationRoutingService.swift`
- Modify: `Tests/iTimeTests/AIConversationAppModelTests.swift` (RecordingAIConversationService)

- [ ] **Step 1: 在协议中新增 `compactMemory`**

在 `Sources/iTime/Services/AIConversationServing.swift` 的 `generateLongFormReport` 后追加：

```swift
    func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String
```

- [ ] **Step 2: 在 `OpenAICompatibleAIConversationService` 中添加占位实现**

在 `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` 的 `generateLongFormReport` 方法后面添加：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        throw AIAnalysisServiceError.invalidConfiguration
    }
```

- [ ] **Step 3: 在 `AnthropicConversationService` 中添加占位实现**

在 `Sources/iTime/Services/AnthropicConversationService.swift` 的 `generateLongFormReport` 方法后面添加：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        throw AIAnalysisServiceError.invalidConfiguration
    }
```

- [ ] **Step 4: 在 `GeminiConversationService` 中添加占位实现**

在 `Sources/iTime/Services/GeminiConversationService.swift` 的 `generateLongFormReport` 方法后面添加：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        throw AIAnalysisServiceError.invalidConfiguration
    }
```

- [ ] **Step 5: 在 `DeepSeekConversationService` 中添加占位实现**

在 `Sources/iTime/Services/DeepSeekConversationService.swift` 的 `generateLongFormReport` 方法后面添加：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        throw AIAnalysisServiceError.invalidConfiguration
    }
```

- [ ] **Step 6: 在 `AIConversationRoutingService` 中添加占位实现**

在 `Sources/iTime/Services/AIConversationRoutingService.swift` 的 `generateLongFormReport` 方法后面添加：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        return try await service.compactMemory(
            recentSummaries: recentSummaries,
            existingMemory: existingMemory,
            configuration: configuration
        )
    }
```

- [ ] **Step 7: 在 `RecordingAIConversationService`（测试文件）中添加占位实现**

在 `Tests/iTimeTests/AIConversationAppModelTests.swift` 的 `RecordingAIConversationService` class 中，在 `generatedLongFormConfigurations` 属性后添加新属性，并在 `generateLongFormReport` 后添加实现：

新属性（与其他 recording 属性放在一起）：

```swift
    var compactedMemoryText: String = "• 最近几轮复盘显示会议偏多\n• 用户有意识地保护早晨时间"
    private(set) var compactMemoryCallCount = 0
    private(set) var compactedSummaries: [[AIConversationSummary]] = []
    private(set) var compactedExistingMemories: [String?] = []
```

新方法（在 `generateLongFormReport` 之后）：

```swift
    func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        compactMemoryCallCount += 1
        compactedSummaries.append(recentSummaries)
        compactedExistingMemories.append(existingMemory)
        return compactedMemoryText
    }
```

- [ ] **Step 8: 编译验证**

```bash
swift build 2>&1 | tail -20
```

期望输出：`Build complete!`（无编译错误）

- [ ] **Step 9: 运行全部测试确认无回归**

```bash
swift test 2>&1 | tail -20
```

期望：所有原有测试通过。

- [ ] **Step 10: Commit**

```bash
git add Sources/iTime/Services/AIConversationServing.swift \
  Sources/iTime/Services/OpenAICompatibleAIConversationService.swift \
  Sources/iTime/Services/AnthropicConversationService.swift \
  Sources/iTime/Services/GeminiConversationService.swift \
  Sources/iTime/Services/DeepSeekConversationService.swift \
  Sources/iTime/Services/AIConversationRoutingService.swift \
  Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: add compactMemory to AIConversationServing protocol with stub implementations"
```

---

### Task 2: 实现 `OpenAICompatibleAIConversationService.compactMemory`

**Files:**
- Modify: `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift`
- Test: `Tests/iTimeTests/AIConversationServiceTests.swift`

- [ ] **Step 1: 写失败的测试**

在 `Tests/iTimeTests/AIConversationServiceTests.swift` 末尾添加：

```swift
@Test func openAICompatibleConversationServiceCompactsMemoryAndReturnsPlainText() async throws {
    let sender = ConversationRecordingAIHTTPSender(
        responseData: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "• 会议占用大量时间\\n• 用户有意识地保护早晨深度工作"
                  }
                }
              ]
            }
            """.utf8
        )
    )
    let service = OpenAICompatibleAIConversationService(httpSender: sender)
    let summaries = [
        AIConversationSummary(
            id: UUID(),
            sessionID: UUID(),
            serviceID: nil,
            serviceDisplayName: "OpenAI",
            provider: .openAI,
            model: "gpt-5-mini",
            range: .today,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86_400),
            createdAt: Date(timeIntervalSince1970: 7_200),
            headline: "今天以沟通为主",
            summary: "今天大部分时间花在需求同步上。",
            findings: [],
            suggestions: [],
            overviewSnapshot: AIOverviewSnapshot(
                rangeTitle: "今天",
                totalDurationText: "1小时",
                totalEventCount: 1,
                topCalendarNames: ["工作"]
            )
        )
    ]
    let configuration = ResolvedAIProviderConfiguration(
        provider: .openAI,
        baseURL: "https://example.com/v1",
        model: "gpt-5-mini",
        apiKey: "test-key",
        isEnabled: true
    )

    let result = try await service.compactMemory(
        recentSummaries: summaries,
        existingMemory: "过去几轮都显示会议偏多。",
        configuration: configuration
    )

    #expect(result == "• 会议占用大量时间\n• 用户有意识地保护早晨深度工作")
    let body = try #require(sender.lastRequest?.httpBody)
    let decoded = try JSONDecoder().decode(RequestBodyForInspection.self, from: body)
    #expect(decoded.messages.contains { $0.role == "system" && $0.content.contains("时间记忆") })
    #expect(decoded.messages.contains { $0.role == "user" && $0.content.contains("过去几轮都显示会议偏多") })
    #expect(decoded.messages.contains { $0.role == "user" && $0.content.contains("今天以沟通为主") })
    #expect(decoded.responseFormat.type == "text")
}

private struct RequestBodyForInspection: Decodable {
    struct Message: Decodable {
        let role: String
        let content: String
    }
    struct ResponseFormat: Decodable {
        let type: String
        enum CodingKeys: String, CodingKey { case type = "type" }
    }
    let messages: [Message]
    let responseFormat: ResponseFormat
    enum CodingKeys: String, CodingKey {
        case messages
        case responseFormat = "response_format"
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter AIConversationServiceTests 2>&1 | tail -20
```

期望：`openAICompatibleConversationServiceCompactsMemoryAndReturnsPlainText` 失败（当前 stub 抛出 `invalidConfiguration`）。

- [ ] **Step 3: 更新 `sendRequest` 以支持 responseFormatType 参数**

将 `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` 中的 `sendRequest` 方法签名从：

```swift
    private func sendRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
```

改为：

```swift
    private func sendRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: ResolvedAIProviderConfiguration,
        responseFormatType: String = "json_object"
    ) async throws -> String {
```

并将方法体中的：

```swift
                responseFormat: .init(type: "json_object")
```

改为：

```swift
                responseFormat: .init(type: responseFormatType)
```

- [ ] **Step 4: 在 `OpenAICompatibleAIConversationService` 中新增 static prompts 和实现**

将 `Sources/iTime/Services/OpenAICompatibleAIConversationService.swift` 中 `compactMemory` 的占位实现替换为：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        let content = try await sendRequest(
            systemPrompt: Self.compactMemorySystemPrompt,
            userPrompt: Self.compactMemoryUserPrompt(
                recentSummaries: recentSummaries,
                existingMemory: existingMemory
            ),
            configuration: configuration,
            responseFormatType: "text"
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
```

在 `longFormSystemPrompt` 静态属性之后，新增以下两个静态属性（紧靠在 `longFormSystemPrompt` 后面）：

```swift
    static let compactMemorySystemPrompt = """
    你在帮助整理一位用户的时间记忆档案。根据提供的历史复盘摘要，提炼出这位用户最典型的时间习惯、重复模式和近期值得关注的变化。
    要求：不超过 400 字，2-4 条要点，每条以 • 开头，聚焦于时间管理与任务执行的规律性观察，只输出纯文本，不要输出 JSON。
    """

    static func compactMemoryUserPrompt(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?
    ) -> String {
        let dailyCount = recentSummaries.filter { $0.range == .today }.count
        let weeklyCount = recentSummaries.filter { $0.range == .week }.count

        var hierarchicalNote = ""
        if dailyCount >= 5 {
            hierarchicalNote = "\n注意：以上摘要已覆盖本周完整的工作日复盘，请在要点末尾额外加一条 • 本周总体记忆：…（一句话概括本周整体状态）"
        } else if weeklyCount >= 3 {
            hierarchicalNote = "\n注意：以上摘要已覆盖本月完整的周复盘，请在要点末尾额外加一条 • 本月总体记忆：…（一句话概括本月整体趋势）"
        }

        let summaryLines = recentSummaries
            .sorted { $0.createdAt > $1.createdAt }
            .map { "- \($0.displayPeriodText)【\($0.range.title)】：\($0.headline)。\($0.summary)" }
            .joined(separator: "\n")

        return """
        历史记忆（如有）：\(existingMemory ?? "无")

        近期复盘摘要：
        \(summaryLines.isEmpty ? "（无）" : summaryLines)
        \(hierarchicalNote)
        请提炼这位用户的时间使用规律。
        """
    }
```

- [ ] **Step 5: 运行测试确认通过**

```bash
swift test --filter AIConversationServiceTests 2>&1 | tail -20
```

期望：所有 `AIConversationServiceTests` 测试通过。

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/Services/OpenAICompatibleAIConversationService.swift \
  Tests/iTimeTests/AIConversationServiceTests.swift
git commit -m "feat: implement compactMemory in OpenAICompatibleAIConversationService with plain-text response"
```

---

### Task 3: 实现其余服务的 `compactMemory`

**Files:**
- Modify: `Sources/iTime/Services/AnthropicConversationService.swift`
- Modify: `Sources/iTime/Services/GeminiConversationService.swift`
- Modify: `Sources/iTime/Services/DeepSeekConversationService.swift`

- [ ] **Step 1: 实现 `AnthropicConversationService.compactMemory`**

将 `Sources/iTime/Services/AnthropicConversationService.swift` 中的 `compactMemory` 占位实现替换为：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.compactMemoryUserPrompt(
                recentSummaries: recentSummaries,
                existingMemory: existingMemory
            ),
            systemPrompt: OpenAICompatibleAIConversationService.compactMemorySystemPrompt,
            configuration: configuration
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
```

- [ ] **Step 2: 更新 `GeminiConversationService.sendRequest` 支持 `responseMimeType` 参数**

将 `Sources/iTime/Services/GeminiConversationService.swift` 中的 `sendRequest` 方法签名从：

```swift
    private func sendRequest(
        userPrompt: String,
        systemPrompt: String,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
```

改为：

```swift
    private func sendRequest(
        userPrompt: String,
        systemPrompt: String,
        configuration: ResolvedAIProviderConfiguration,
        responseMimeType: String = "application/json"
    ) async throws -> String {
```

并将方法体中的：

```swift
                generationConfig: .init(responseMimeType: "application/json")
```

改为：

```swift
                generationConfig: .init(responseMimeType: responseMimeType)
```

- [ ] **Step 3: 实现 `GeminiConversationService.compactMemory`**

将 `Sources/iTime/Services/GeminiConversationService.swift` 中的 `compactMemory` 占位实现替换为：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        let content = try await sendRequest(
            userPrompt: OpenAICompatibleAIConversationService.compactMemoryUserPrompt(
                recentSummaries: recentSummaries,
                existingMemory: existingMemory
            ),
            systemPrompt: OpenAICompatibleAIConversationService.compactMemorySystemPrompt,
            configuration: configuration,
            responseMimeType: "text/plain"
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
```

- [ ] **Step 4: 实现 `DeepSeekConversationService.compactMemory`**

将 `Sources/iTime/Services/DeepSeekConversationService.swift` 中的 `compactMemory` 占位实现替换为：

```swift
    public func compactMemory(
        recentSummaries: [AIConversationSummary],
        existingMemory: String?,
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> String {
        try await implementation.compactMemory(
            recentSummaries: recentSummaries,
            existingMemory: existingMemory,
            configuration: configuration
        )
    }
```

- [ ] **Step 5: 运行全部测试**

```bash
swift test 2>&1 | tail -20
```

期望：所有测试通过，Build complete。

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/Services/AnthropicConversationService.swift \
  Sources/iTime/Services/GeminiConversationService.swift \
  Sources/iTime/Services/DeepSeekConversationService.swift
git commit -m "feat: implement compactMemory in Anthropic, Gemini, and DeepSeek conversation services"
```

---

### Task 4: AppModel 新增 `performMemoryUpdate` 并接入 `finishAIConversation`

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: 写失败的测试**

在 `Tests/iTimeTests/AIConversationAppModelTests.swift` 的 `finishAIConversationArchivesSummaryAndLoadsHistory` 测试之后添加：

```swift
@MainActor
@Test func finishAIConversationCreatesMemorySnapshotAfterSummary() async {
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "需求评审",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService()
    conversationService.compactedMemoryText = "• 会议偏多\n• 执行时间不足"
    let archiveStore = InMemoryAIConversationArchiveStore()
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()
    await model.sendAIConversationReply("主要在对齐需求变更。")
    await model.finishAIConversation()

    #expect(conversationService.compactMemoryCallCount == 1)
    #expect(conversationService.compactedSummaries.first?.count == 1)
    #expect(model.latestAIMemorySnapshot?.summary == "• 会议偏多\n• 执行时间不足")
    #expect(archiveStore.archive.memorySnapshots.count == 1)
    #expect(archiveStore.archive.memorySnapshots.first?.summary == "• 会议偏多\n• 执行时间不足")
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter "finishAIConversationCreatesMemorySnapshotAfterSummary" 2>&1 | tail -20
```

期望：测试失败（`compactMemoryCallCount == 0`）。

- [ ] **Step 3: 在 `AppModel` 中实现 `performMemoryUpdate`**

在 `Sources/iTime/App/AppModel.swift` 的 `performLongFormGeneration` 方法之前（约第 748 行）插入以下新方法：

```swift
    private func performMemoryUpdate(
        newSummary: AIConversationSummary,
        configuration: ResolvedAIProviderConfiguration
    ) async {
        // newSummary is already in aiConversationHistory at this point
        let allSummaries = aiConversationHistory
        var summariesForCompaction: [AIConversationSummary] = []

        // Collect context-aware summaries based on range
        switch newSummary.range {
        case .today:
            // Yesterday's daily summary
            if let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: newSummary.startDate),
               let yesterday = allSummaries.first(where: {
                   $0.range == .today && calendar.isDate($0.startDate, inSameDayAs: yesterdayStart)
               }) {
                summariesForCompaction.append(yesterday)
            }
            // This week's weekly summary (if exists)
            if let thisWeek = allSummaries.first(where: {
                $0.range == .week && calendar.isDate($0.startDate, equalTo: newSummary.startDate, toGranularity: .weekOfYear)
            }) {
                summariesForCompaction.append(thisWeek)
            }
            // Hierarchical: if 5+ daily summaries this week, include them all
            let weekDailies = allSummaries.filter {
                $0.range == .today && $0.id != newSummary.id &&
                calendar.isDate($0.startDate, equalTo: newSummary.startDate, toGranularity: .weekOfYear)
            }
            if weekDailies.count >= 5 {
                for s in weekDailies where !summariesForCompaction.contains(where: { $0.id == s.id }) {
                    summariesForCompaction.append(s)
                }
            }

        case .week:
            // Last week's weekly summary
            if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: newSummary.startDate),
               let lastWeek = allSummaries.first(where: {
                   $0.range == .week && calendar.isDate($0.startDate, equalTo: lastWeekStart, toGranularity: .weekOfYear)
               }) {
                summariesForCompaction.append(lastWeek)
            }
            // Hierarchical: if 3+ weekly summaries this month, include them all
            let monthWeeklies = allSummaries.filter {
                $0.range == .week && $0.id != newSummary.id &&
                calendar.isDate($0.startDate, equalTo: newSummary.startDate, toGranularity: .month)
            }
            if monthWeeklies.count >= 3 {
                for s in monthWeeklies where !summariesForCompaction.contains(where: { $0.id == s.id }) {
                    summariesForCompaction.append(s)
                }
            }

        case .month:
            if let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: newSummary.startDate),
               let lastMonth = allSummaries.first(where: {
                   $0.range == .month && calendar.isDate($0.startDate, equalTo: lastMonthStart, toGranularity: .month)
               }) {
                summariesForCompaction.append(lastMonth)
            }

        case .custom:
            break
        }

        // Always include the new summary itself
        if !summariesForCompaction.contains(where: { $0.id == newSummary.id }) {
            summariesForCompaction.insert(newSummary, at: 0)
        }

        let existingMemory = latestAIMemorySnapshot?.summary
        guard let compactedText = try? await aiConversationService.compactMemory(
            recentSummaries: summariesForCompaction,
            existingMemory: existingMemory,
            configuration: configuration
        ), !compactedText.isEmpty else { return }

        let newSnapshot = AIMemorySnapshot(
            id: UUID(),
            createdAt: now(),
            sourceSummaryIDs: summariesForCompaction.map(\.id),
            summary: compactedText
        )
        var snapshots = aiConversationArchive.memorySnapshots
        snapshots.append(newSnapshot)
        let updatedArchive = AIConversationArchive(
            sessions: aiConversationArchive.sessions,
            summaries: aiConversationArchive.summaries,
            memorySnapshots: snapshots,
            longFormReports: aiConversationArchive.longFormReports
        )
        try? persistConversationArchive(updatedArchive)
    }
```

- [ ] **Step 4: 在 `finishAIConversation` 中调用 `performMemoryUpdate`**

在 `Sources/iTime/App/AppModel.swift` 中找到 `finishAIConversation` 里的：

```swift
            try saveConversationArchive(upserting: completedSession, appending: summary)
            aiConversationState = .completed(summary)
            await performLongFormGeneration(session: completedSession, summary: summary, configuration: configuration)
```

改为：

```swift
            try saveConversationArchive(upserting: completedSession, appending: summary)
            aiConversationState = .completed(summary)
            await performMemoryUpdate(newSummary: summary, configuration: configuration)
            await performLongFormGeneration(session: completedSession, summary: summary, configuration: configuration)
```

- [ ] **Step 5: 运行新测试**

```bash
swift test --filter "finishAIConversationCreatesMemorySnapshotAfterSummary" 2>&1 | tail -20
```

期望：测试通过。

- [ ] **Step 6: 运行全部测试检查回归**

```bash
swift test 2>&1 | tail -30
```

期望：所有测试通过。

- [ ] **Step 7: Commit**

```bash
git add Sources/iTime/App/AppModel.swift \
  Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: add performMemoryUpdate to AppModel, trigger after every conversation finishes"
```

---

### Task 5: Token 预算截断

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: 写失败的测试**

在 `Tests/iTimeTests/AIConversationAppModelTests.swift` 末尾添加：

```swift
@MainActor
@Test func contextMemoryIsTruncatedToTokenBudgetWhenTooLong() async {
    let longMemory = String(repeating: "记忆内容", count: 250) // > 800 chars
    let calendarService = ConversationStubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "深度工作",
                calendarID: "work",
                startDate: .init(timeIntervalSince1970: 0),
                endDate: .init(timeIntervalSince1970: 3_600),
                isAllDay: false
            ),
        ]
    )
    let conversationService = RecordingAIConversationService()
    let archiveStore = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [],
            summaries: [],
            memorySnapshots: [
                AIMemorySnapshot(
                    id: UUID(),
                    createdAt: .init(timeIntervalSince1970: 100),
                    sourceSummaryIDs: [],
                    summary: longMemory
                ),
            ],
            longFormReports: []
        )
    )
    let preferences = UserPreferences(storage: .inMemory)
    preferences.aiAnalysisEnabled = true
    preferences.aiBaseURL = "https://example.com/v1"
    preferences.aiModel = "gpt-5-mini"
    let model = AppModel(
        service: calendarService,
        preferences: preferences,
        aiConversationService: conversationService,
        aiKeyStore: ConversationInMemoryAIKeyStore(value: "secret-key"),
        aiConversationArchiveStore: archiveStore
    )

    await model.refresh()
    await model.startAIConversation()

    let injectedMemory = conversationService.askedContexts.first?.latestMemorySummary
    let memoryLength = injectedMemory?.count ?? 0
    #expect(memoryLength <= 801) // 800 chars + "…"
    #expect(injectedMemory?.hasSuffix("…") == true)
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter "contextMemoryIsTruncatedToTokenBudgetWhenTooLong" 2>&1 | tail -20
```

期望：测试失败（内存长度 > 801）。

- [ ] **Step 3: 在 `currentAIConversationContext` 中添加截断**

在 `Sources/iTime/App/AppModel.swift` 中找到 `currentAIConversationContext` 函数内的：

```swift
        var memoryText = computeContextMemory(
            range: overview.range,
            interval: overview.interval,
            summaries: aiConversationHistory
        )
        
        if memoryText == nil {
            memoryText = latestAIMemorySnapshot?.summary
        }
```

改为：

```swift
        var memoryText = computeContextMemory(
            range: overview.range,
            interval: overview.interval,
            summaries: aiConversationHistory
        )

        if memoryText == nil {
            memoryText = latestAIMemorySnapshot?.summary
        }

        let memoryBudget = 800
        if let text = memoryText, text.count > memoryBudget {
            memoryText = String(text.prefix(memoryBudget)) + "…"
        }
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter "contextMemoryIsTruncatedToTokenBudgetWhenTooLong" 2>&1 | tail -20
```

期望：测试通过。

- [ ] **Step 5: 运行全部测试**

```bash
swift test 2>&1 | tail -20
```

期望：所有测试通过。

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/App/AppModel.swift \
  Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: enforce 800-char token budget on memory injected into AI context"
```

---

### Task 6: 从 `performLongFormGeneration` 移除 snapshot 创建

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`

- [ ] **Step 1: 确认没有测试检查长文复盘后创建 snapshot**

```bash
grep -n "memorySnapshot" Tests/iTimeTests/AIConversationAppModelTests.swift
```

确认 `generatingLongFormReportPersistsReportFromConversationSession` 测试不检查 `memorySnapshots.count`（查看第 838-943 行的测试代码确认）。

- [ ] **Step 2: 移除 `performLongFormGeneration` 中的 snapshot 创建逻辑**

在 `Sources/iTime/App/AppModel.swift` 中，找到 `performLongFormGeneration` 内的以下代码块（约第 778-801 行）：

```swift
            // Compact / update memory file after generating the essay
            let compactedText = computeContextMemory(
                range: summary.range,
                interval: DateInterval(start: summary.startDate, end: summary.endDate),
                summaries: aiConversationArchive.summaries
            ) ?? summary.summary

            let newMemorySnapshot = AIMemorySnapshot(
                id: UUID(),
                createdAt: nowDate,
                sourceSummaryIDs: [summaryID],
                summary: compactedText
            )

            var memorySnapshots = aiConversationArchive.memorySnapshots
            memorySnapshots.append(newMemorySnapshot)

            let updatedArchive = AIConversationArchive(
                sessions: aiConversationArchive.sessions,
                summaries: aiConversationArchive.summaries,
                memorySnapshots: memorySnapshots,
                longFormReports: aiConversationArchive.longFormReports
                    .filter { $0.summaryID != summaryID } + [report]
            )
```

替换为（删去 snapshot 相关代码，直接使用现有 snapshots）：

```swift
            let updatedArchive = AIConversationArchive(
                sessions: aiConversationArchive.sessions,
                summaries: aiConversationArchive.summaries,
                memorySnapshots: aiConversationArchive.memorySnapshots,
                longFormReports: aiConversationArchive.longFormReports
                    .filter { $0.summaryID != summaryID } + [report]
            )
```

同时删除不再使用的 `nowDate` 变量（如果它只在 snapshot 代码里用到）。检查 `nowDate` 是否还被其他代码使用：在 `performLongFormGeneration` 内搜索 `nowDate` 的用法，只保留 `report` 创建处用到的部分（`createdAt` 和 `updatedAt`），确认是否还有其他引用。如果 `nowDate` 只在 snapshot 和 report 创建中使用，则保留（report 仍然需要）。

- [ ] **Step 3: 运行全部测试**

```bash
swift test 2>&1 | tail -20
```

期望：所有测试通过（删除 snapshot 逻辑不会让现有测试失败）。

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/App/AppModel.swift
git commit -m "refactor: remove memory snapshot creation from performLongFormGeneration, handled by performMemoryUpdate"
```

---

## 自检

**Spec coverage:**
- A（每次对话结束自动触发）→ Task 4 ✓
- B（分层压缩，日→周≥5条触发，周→月≥3条触发）→ Task 4（`performMemoryUpdate` 中的分支逻辑）✓
- C（bullet facts 自由文本）→ Task 2（`compactMemorySystemPrompt` 要求 • 格式）✓
- Token 预算 800 字截断 → Task 5 ✓
- 移除 `performLongFormGeneration` 中的旧 snapshot 创建 → Task 6 ✓
- 所有服务实现 → Task 1-3 ✓

**Placeholder scan:** 无 TBD。所有步骤均含具体代码。

**Type consistency:**
- `AIMemorySnapshot` 无变化，`sourceSummaryIDs: [UUID]` 用法一致
- `compactMemory` 方法签名在协议、所有服务、RecordingAIConversationService 中完全一致
- `performMemoryUpdate(newSummary:configuration:)` 与调用处参数一致
