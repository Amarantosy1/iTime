# AI 挂载、历史管理与复盘退出 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 AI 配置升级为可扩展挂载层，支持历史总结彻底删除、未完成复盘放弃退出，以及复盘开始前切换挂载与模型。

**Architecture:** 先把当前按 `AIProviderKind` 分散保存的配置收口为 `AIProviderMount` 与 `ResolvedAIProviderMount`，并完成 `UserPreferences` 与 Keychain 迁移，再让 `AppModel` 和会话模型绑定具体 `mountID + model`。UI 层随后改成“挂载列表 + 详情编辑器”和“复盘窗口开始前选择器”，最后补上删除、丢弃与测试连接动作。

**Tech Stack:** Swift 6, SwiftUI, Observation, Foundation, Keychain, swift-testing, Xcode macOS target

---

### Task 1: 引入 AI 挂载模型与偏好迁移

**Files:**
- Create: `Sources/iTime/Domain/AIProviderMount.swift`
- Modify: `Sources/iTime/Domain/AIProvider.swift`
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Modify: `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`
- Test: `Tests/iTimeTests/UserPreferencesTests.swift`

- [ ] **Step 1: 写失败测试，锁定 mount 持久化与旧配置迁移**

```swift
@Test func aiProviderMountsMigrateFromLegacyProviderPreferences() {
    let first = UserPreferences(storage: .inMemory)
    first.aiAnalysisEnabled = true
    first.defaultAIProvider = .anthropic
    first.setAIProviderEnabled(true, for: .openAI)
    first.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    first.setAIProviderModel("gpt-5", for: .openAI)
    first.setAIProviderEnabled(true, for: .anthropic)
    first.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    first.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: first.debugSuiteName)

    let mounts = second.aiProviderMounts
    #expect(mounts.count == 4)
    #expect(mounts.first(where: { $0.providerType == .openAI })?.defaultModel == "gpt-5")
    #expect(mounts.first(where: { $0.providerType == .anthropic })?.isEnabled == true)
    #expect(second.defaultAIMount?.providerType == .anthropic)
}

@Test func aiProviderMountsAllowAddingAndDeletingCustomMounts() {
    let preferences = UserPreferences(storage: .inMemory)
    let mount = AIProviderMount.custom(
        displayName: "OpenAI Proxy",
        providerType: .openAI,
        baseURL: "https://proxy.example.com/v1"
    )

    preferences.saveAIMount(mount)
    #expect(preferences.aiProviderMounts.contains(where: { $0.id == mount.id }))

    preferences.deleteAIMount(id: mount.id)
    #expect(preferences.aiProviderMounts.contains(where: { $0.id == mount.id }) == false)
}
```

- [ ] **Step 2: 跑测试，确认确实失败**

Run: `swift test --filter aiProviderMounts`

Expected: FAIL，提示 `UserPreferences` 中不存在 `aiProviderMounts`、`defaultAIMount`、`saveAIMount`、`deleteAIMount`

- [ ] **Step 3: 实现 mount 模型与偏好迁移**

```swift
public struct AIProviderMount: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let providerType: AIProviderKind
    public let baseURL: String
    public let models: [String]
    public let defaultModel: String
    public let isEnabled: Bool
    public let isBuiltIn: Bool
}

public extension UserPreferences {
    var aiProviderMounts: [AIProviderMount] { loadOrMigrateAIMounts() }

    var defaultAIMount: AIProviderMount? {
        aiProviderMounts.first(where: { $0.id == defaultAIMountID }) ?? aiProviderMounts.first
    }

    func saveAIMount(_ mount: AIProviderMount) { /* upsert + persist */ }
    func deleteAIMount(id: UUID) { /* remove + adjust default */ }
}
```

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --filter aiProviderMounts`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/Domain/AIProviderMount.swift Sources/iTime/Domain/AIProvider.swift Sources/iTime/Support/Persistence/UserPreferences.swift Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift Tests/iTimeTests/AIProviderSettingsTests.swift Tests/iTimeTests/UserPreferencesTests.swift
git commit -m "feat: add AI provider mounts"
```

### Task 2: 升级会话模型与 AppModel 绑定挂载/模型

**Files:**
- Modify: `Sources/iTime/Domain/AIConversation.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Sources/iTime/Services/AIConversationRoutingService.swift`
- Modify: `Sources/iTime/Services/AIConversationServing.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`
- Test: `Tests/iTimeTests/AIConversationRoutingServiceTests.swift`

- [ ] **Step 1: 写失败测试，锁定开始前选择与会话绑定**

```swift
@MainActor
@Test func startAIConversationBindsSelectedMountAndModel() async {
    let preferences = UserPreferences(storage: .inMemory)
    let customMount = AIProviderMount.custom(
        displayName: "OpenAI Proxy",
        providerType: .openAI,
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-5", "gpt-5-mini"],
        defaultModel: "gpt-5-mini"
    )
    preferences.saveAIMount(customMount)
    preferences.setDefaultAIMountID(customMount.id)

    let model = makeConversationAppModel(preferences: preferences)
    model.selectConversationMount(id: customMount.id)
    model.selectConversationModel("gpt-5")

    await model.refresh()
    await model.startAIConversation()

    guard case .waitingForUser(let session) = model.aiConversationState else {
        Issue.record("Expected waitingForUser")
        return
    }

    #expect(session.mountID == customMount.id)
    #expect(session.mountDisplayName == "OpenAI Proxy")
    #expect(session.model == "gpt-5")
}

@MainActor
@Test func changingDefaultMountDoesNotAffectOngoingConversation() async {
    let model = makeConversationAppModelWithTwoMounts()
    await model.refresh()
    await model.startAIConversation()

    let firstSession = try #require(model.currentConversationSession)
    model.selectConversationMount(id: try #require(model.availableAIMounts.last?.id))
    await model.sendAIConversationReply("补充说明")

    let updatedSession = try #require(model.currentConversationSession)
    #expect(updatedSession.mountID == firstSession.mountID)
    #expect(updatedSession.model == firstSession.model)
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --filter startAIConversationBindsSelectedMountAndModel`

Expected: FAIL，提示缺少 `mountID` / `model` 字段以及 `selectConversationMount` / `selectConversationModel`

- [ ] **Step 3: 最小实现会话绑定与路由入参**

```swift
public struct ResolvedAIProviderMount: Equatable, Sendable {
    public let id: UUID
    public let displayName: String
    public let providerType: AIProviderKind
    public let baseURL: String
    public let apiKey: String
    public let models: [String]
    public let selectedModel: String
    public let isEnabled: Bool
}

public struct AIConversationSession: Equatable, Codable, Sendable {
    public let mountID: UUID?
    public let mountDisplayName: String
    public let providerType: AIProviderKind
    public let model: String
}

@MainActor
public final class AppModel {
    public private(set) var availableAIMounts: [AIProviderMount] = []
    public private(set) var selectedConversationMountID: UUID?
    public private(set) var selectedConversationModel: String = ""
}
```

- [ ] **Step 4: 跑相关测试，确认通过**

Run: `swift test --filter AIConversationAppModelTests`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/Domain/AIConversation.swift Sources/iTime/App/AppModel.swift Sources/iTime/Services/AIConversationRoutingService.swift Sources/iTime/Services/AIConversationServing.swift Tests/iTimeTests/AIConversationAppModelTests.swift Tests/iTimeTests/AIConversationRoutingServiceTests.swift
git commit -m "feat: bind AI conversations to mounts"
```

### Task 3: 归档层支持删除历史总结与丢弃当前会话

**Files:**
- Modify: `Sources/iTime/Support/Persistence/FileAIConversationArchiveStore.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Sources/iTime/Domain/AIConversation.swift`
- Test: `Tests/iTimeTests/AIConversationArchiveStoreTests.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: 写失败测试，锁定删除与丢弃行为**

```swift
@Test func deletingSummaryAlsoDeletesSessionAndInvalidMemory() throws {
    let store = InMemoryAIConversationArchiveStore(
        archive: AIConversationArchive(
            sessions: [sessionA],
            summaries: [summaryA],
            memorySnapshots: [memoryFromSummaryA]
        )
    )

    let model = makeConversationAppModel(archiveStore: store)
    model.deleteAISummary(summaryA.id)

    #expect(model.aiConversationHistory.isEmpty)
    #expect(store.archive.sessions.isEmpty)
    #expect(store.archive.memorySnapshots.isEmpty)
}

@MainActor
@Test func discardCurrentConversationDoesNotCreateSummary() async {
    let model = makeConversationAppModel()
    await model.refresh()
    await model.startAIConversation()

    await model.discardCurrentAIConversation()

    #expect(model.aiConversationHistory.isEmpty)
    #expect(model.aiConversationState == .idle)
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --filter deleteAISummary`

Expected: FAIL，提示 `deleteAISummary` 和 `discardCurrentAIConversation` 不存在

- [ ] **Step 3: 实现 archive 删除与 discard**

```swift
extension AIConversationArchive {
    func deletingSummary(id: UUID) -> AIConversationArchive {
        let deletedSessionIDs = summaries
            .filter { $0.id == id }
            .map(\.sessionID)
        let remainingSummaries = summaries.filter { $0.id != id }
        let remainingSessions = sessions.filter { !deletedSessionIDs.contains($0.id) }
        let remainingSummaryIDs = Set(remainingSummaries.map(\.id))
        let remainingMemories = memorySnapshots.filter {
            Set($0.sourceSummaryIDs).isSubset(of: remainingSummaryIDs)
        }
        return AIConversationArchive(
            sessions: remainingSessions,
            summaries: remainingSummaries,
            memorySnapshots: remainingMemories
        )
    }
}
```

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --filter AIConversationArchiveStoreTests`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/Support/Persistence/FileAIConversationArchiveStore.swift Sources/iTime/App/AppModel.swift Sources/iTime/Domain/AIConversation.swift Tests/iTimeTests/AIConversationArchiveStoreTests.swift Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: support deleting AI summaries"
```

### Task 4: 重构设置页为挂载列表和详情编辑器

**Files:**
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`

- [ ] **Step 1: 写失败测试，锁定设置页文案和挂载行为**

```swift
@Test func aiSettingsCopyUsesMountLanguage() {
    #expect(AISettingsCopy.sectionTitle == "AI 挂载")
    #expect(AISettingsCopy.addCustomMountAction == "新增挂载")
    #expect(AISettingsCopy.testConnectionAction == "测试连接")
    #expect(AISettingsCopy.modelsTitle == "模型列表")
}

@Test func deletingDefaultCustomMountFallsBackToFirstAvailableMount() {
    let preferences = UserPreferences(storage: .inMemory)
    let mount = AIProviderMount.custom(displayName: "Proxy", providerType: .openAI, baseURL: "https://proxy.example.com/v1")
    preferences.saveAIMount(mount)
    preferences.setDefaultAIMountID(mount.id)

    preferences.deleteAIMount(id: mount.id)

    #expect(preferences.defaultAIMount != nil)
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --filter aiSettingsCopyUsesMountLanguage`

Expected: FAIL，提示缺少新的 copy 与 mount 设置方法

- [ ] **Step 3: 实现设置页列表 + 详情编辑器**

```swift
NavigationSplitView {
    List(selection: $selectedMountID) {
        ForEach(model.availableAIMounts) { mount in
            AIProviderMountRow(mount: mount, isDefault: mount.id == model.defaultAIMountID)
        }
    }
    .toolbar {
        Button(AISettingsCopy.addCustomMountAction) {
            model.createCustomAIMount()
        }
    }
} detail: {
    if let mount = selectedMount {
        AIProviderMountEditorView(
            mount: mount,
            apiKey: bindingForAPIKey(mount.id),
            onSave: model.updateAIMount,
            onDelete: model.deleteAIMount,
            onTestConnection: model.testAIMountConnection
        )
    }
}
```

- [ ] **Step 4: 跑设置相关测试，确认通过**

Run: `swift test --filter AIProviderSettingsTests`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/UI/Settings/SettingsView.swift Sources/iTime/App/AppModel.swift Tests/iTimeTests/PresentationTests.swift Tests/iTimeTests/AIProviderSettingsTests.swift
git commit -m "feat: redesign AI mount settings"
```

### Task 5: 升级复盘窗口，支持开始前切换与左上角放弃

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- Modify: `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: 写失败测试，锁定开始前选择与放弃路径**

```swift
@Test func aiConversationWindowCopyUsesDiscardLanguage() {
    #expect(AIConversationWindowCopy.discardConversationAccessibilityLabel == "退出本轮复盘")
    #expect(AIConversationWindowCopy.discardConfirmationTitle == "放弃这轮复盘？")
}

@MainActor
@Test func completedConversationCloseDoesNotDeleteSummary() async {
    let model = makeCompletedConversationAppModel()
    await model.closeOrDiscardAIConversation()
    #expect(model.aiConversationHistory.count == 1)
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --filter aiConversationWindowCopyUsesDiscardLanguage`

Expected: FAIL，提示缺少 discard copy / close-or-discard 行为

- [ ] **Step 3: 最小实现窗口头部选择器和返回图标**

```swift
ToolbarItem(placement: .navigation) {
    Button {
        showsDiscardConfirmation = true
    } label: {
        Image(systemName: "chevron.left")
    }
    .help(AIConversationWindowCopy.discardConversationAccessibilityLabel)
}

if case .idle = model.aiConversationState {
    AIConversationStartOptionsView(
        mounts: model.availableAIMounts,
        selectedMountID: model.selectedConversationMountID,
        selectedModel: model.selectedConversationModel,
        onSelectMount: model.selectConversationMount,
        onSelectModel: model.selectConversationModel
    )
}
```

- [ ] **Step 4: 跑测试，确认通过**

Run: `swift test --filter AIConversationAppModelTests`

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationWindowView.swift Sources/iTime/UI/AIConversation/AIConversationComposerView.swift Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift Sources/iTime/App/AppModel.swift Tests/iTimeTests/PresentationTests.swift Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "feat: add preflight AI mount selection"
```

### Task 6: 加入测试连接与最终回归

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/Services/OpenAIConversationService.swift`
- Modify: `Sources/iTime/Services/AnthropicConversationService.swift`
- Modify: `Sources/iTime/Services/GeminiConversationService.swift`
- Modify: `Sources/iTime/Services/DeepSeekConversationService.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: 写失败测试，锁定测试连接状态**

```swift
@MainActor
@Test func testAIMountConnectionStoresSuccessStatePerMount() async {
    let model = makeConversationAppModel()
    let mount = try #require(model.availableAIMounts.first)

    await model.testAIMountConnection(mount.id)

    #expect(model.aiMountConnectionState(for: mount.id) == .succeeded("连接成功"))
}
```

- [ ] **Step 2: 跑测试，确认失败**

Run: `swift test --filter testAIMountConnectionStoresSuccessStatePerMount`

Expected: FAIL，提示缺少连接测试状态与入口

- [ ] **Step 3: 最小实现连通性测试与状态反馈**

```swift
enum AIMountConnectionState: Equatable {
    case idle
    case testing
    case succeeded(String)
    case failed(String)
}

@MainActor
public func testAIMountConnection(_ mountID: UUID) async {
    aiMountConnectionStates[mountID] = .testing
    do {
        try await aiConversationService.validateConnection(configuration: resolvedMount(for: mountID))
        aiMountConnectionStates[mountID] = .succeeded("连接成功")
    } catch {
        aiMountConnectionStates[mountID] = .failed("连接失败，请检查配置。")
    }
}
```

- [ ] **Step 4: 跑完整验证**

Run: `swift test`
Expected: PASS

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add Sources/iTime/App/AppModel.swift Sources/iTime/UI/Settings/SettingsView.swift Sources/iTime/Services/OpenAIConversationService.swift Sources/iTime/Services/AnthropicConversationService.swift Sources/iTime/Services/GeminiConversationService.swift Sources/iTime/Services/DeepSeekConversationService.swift Tests/iTimeTests/AIProviderSettingsTests.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: add AI mount connection testing"
```
