# AI Provider And Chat Window Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-provider AI configuration for `OpenAI / Anthropic / Gemini / DeepSeek` and move AI chat from the overview card into a stable dedicated window.

**Architecture:** Split AI into two product surfaces: provider management in settings and a dedicated AI conversation window. Keep `AppModel` as the shared state coordinator, but replace the single global AI config assumption with provider-aware runtime resolution and route chat calls through per-provider service implementations.

**Tech Stack:** Swift 6, SwiftUI, Observation, URLSession, UserDefaults, Keychain, XCTest via `swift test` and `xcodebuild`

---

## File Map

### Existing files to modify

- `Sources/iTime/App/AppModel.swift`
  - Add provider-aware state resolution, active conversation provider binding, and window-driven chat entry points.
- `Sources/iTime/iTimeApp.swift`
  - Register the new AI conversation window scene.
- `Sources/iTime/Support/Persistence/UserPreferences.swift`
  - Persist `defaultProvider` plus per-provider `baseURL / model / isEnabled`.
- `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
  - Expand key storage to read/write keys per provider.
- `Sources/iTime/Domain/AIConversation.swift`
  - Bind sessions to a provider and expose any additional runtime context needed by the new window.
- `Sources/iTime/UI/Settings/SettingsView.swift`
  - Replace the single AI config form with per-provider sections and default provider selection.
- `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`
  - Remove inline chat UI and turn the section into an entry card with summary/history/open-window actions.
- `Tests/iTimeTests/UserPreferencesTests.swift`
  - Cover provider configuration persistence.
- `Tests/iTimeTests/AIConversationAppModelTests.swift`
  - Cover provider selection and conversation binding behavior.
- `Tests/iTimeTests/PresentationTests.swift`
  - Cover new settings and overview copy.
- `iTime.xcodeproj/project.pbxproj`
  - Add new source and test files to the Xcode project.

### New files to create

- `Sources/iTime/Domain/AIProvider.swift`
  - Define provider enum and provider configuration value types.
- `Sources/iTime/Services/AIConversationRoutingService.swift`
  - Route `AIConversationServing` calls to the active provider-specific client.
- `Sources/iTime/Services/OpenAIConversationService.swift`
  - OpenAI-specific request/response mapping.
- `Sources/iTime/Services/AnthropicConversationService.swift`
  - Anthropic-specific request/response mapping.
- `Sources/iTime/Services/GeminiConversationService.swift`
  - Gemini-specific request/response mapping.
- `Sources/iTime/Services/DeepSeekConversationService.swift`
  - DeepSeek-specific request/response mapping.
- `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
  - Dedicated AI chat window shell.
- `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift`
  - Scrollable messages area.
- `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`
  - Fixed bottom input bar with `@FocusState`.
- `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`
  - History list/detail view used from the chat window.
- `Tests/iTimeTests/AIProviderSettingsTests.swift`
  - Settings persistence and provider selection tests.
- `Tests/iTimeTests/AIConversationRoutingServiceTests.swift`
  - Provider routing and HTTP request shape tests.

---

### Task 1: Add Provider Domain And Persistence

**Files:**
- Create: `Sources/iTime/Domain/AIProvider.swift`
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Modify: `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
- Test: `Tests/iTimeTests/UserPreferencesTests.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`

- [ ] **Step 1: Write the failing provider persistence tests**

```swift
@Test func aiProviderPreferencesPersistSeparately() {
    let preferences = UserPreferences(storage: .inMemory)

    preferences.defaultAIProvider = .anthropic
    preferences.setAIProviderEnabled(true, for: .openAI)
    preferences.setAIProviderBaseURL("https://api.openai.com/v1", for: .openAI)
    preferences.setAIProviderModel("gpt-5", for: .openAI)
    preferences.setAIProviderEnabled(true, for: .anthropic)
    preferences.setAIProviderBaseURL("https://api.anthropic.com/v1", for: .anthropic)
    preferences.setAIProviderModel("claude-sonnet-4-5", for: .anthropic)

    let restored = UserPreferences(
        storage: .inMemory,
        suiteNameOverride: preferences.debugSuiteName
    )

    #expect(restored.defaultAIProvider == .anthropic)
    #expect(restored.aiProviderConfiguration(for: .openAI).model == "gpt-5")
    #expect(restored.aiProviderConfiguration(for: .anthropic).model == "claude-sonnet-4-5")
}

@Test func aiAPIKeyStoreReadsAndWritesKeysPerProvider() throws {
    let store = InMemoryScopedAIKeyStore()

    try store.saveAPIKey("openai-key", for: .openAI)
    try store.saveAPIKey("anthropic-key", for: .anthropic)

    #expect(try store.loadAPIKey(for: .openAI) == "openai-key")
    #expect(try store.loadAPIKey(for: .anthropic) == "anthropic-key")
}
```

- [ ] **Step 2: Run the provider persistence tests to verify they fail**

Run: `swift test --filter aiProvider`

Expected: FAIL with missing `AIProviderKind`, missing provider-specific preference APIs, and missing provider-scoped key storage methods.

- [ ] **Step 3: Add the provider domain types**

```swift
import Foundation

public enum AIProviderKind: String, CaseIterable, Codable, Sendable {
    case openAI
    case anthropic
    case gemini
    case deepSeek

    public var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        }
    }
}

public struct AIProviderConfiguration: Equatable, Codable, Sendable {
    public let provider: AIProviderKind
    public let baseURL: String
    public let model: String
    public let isEnabled: Bool
}
```

- [ ] **Step 4: Extend `UserPreferences` for provider-specific config**

```swift
public var defaultAIProvider: AIProviderKind {
    didSet { defaults.set(defaultAIProvider.rawValue, forKey: Keys.defaultAIProvider) }
}

public func aiProviderConfiguration(for provider: AIProviderKind) -> AIProviderConfiguration {
    AIProviderConfiguration(
        provider: provider,
        baseURL: defaults.string(forKey: Keys.providerBaseURL(provider)) ?? provider.defaultBaseURL,
        model: defaults.string(forKey: Keys.providerModel(provider)) ?? "",
        isEnabled: defaults.object(forKey: Keys.providerEnabled(provider)) as? Bool ?? false
    )
}

public func setAIProviderBaseURL(_ value: String, for provider: AIProviderKind) {
    defaults.set(value, forKey: Keys.providerBaseURL(provider))
}
```

- [ ] **Step 5: Scope API keys by provider**

```swift
public protocol AIAPIKeyStoring: Sendable {
    func loadAPIKey(for provider: AIProviderKind) throws -> String
    func saveAPIKey(_ apiKey: String, for provider: AIProviderKind) throws
}

private func account(for provider: AIProviderKind) -> String {
    "iTime.ai.\(provider.rawValue)"
}
```

- [ ] **Step 6: Re-run the provider persistence tests**

Run: `swift test --filter aiProvider`

Expected: PASS with provider config and provider-scoped key tests green.

- [ ] **Step 7: Commit the provider domain and persistence changes**

```bash
git add Sources/iTime/Domain/AIProvider.swift \
  Sources/iTime/Support/Persistence/UserPreferences.swift \
  Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift \
  Tests/iTimeTests/UserPreferencesTests.swift \
  Tests/iTimeTests/AIProviderSettingsTests.swift
git commit -m "feat: add AI provider preferences"
```

---

### Task 2: Route Conversations Through Provider-Specific Services

**Files:**
- Create: `Sources/iTime/Services/AIConversationRoutingService.swift`
- Create: `Sources/iTime/Services/OpenAIConversationService.swift`
- Create: `Sources/iTime/Services/AnthropicConversationService.swift`
- Create: `Sources/iTime/Services/GeminiConversationService.swift`
- Create: `Sources/iTime/Services/DeepSeekConversationService.swift`
- Modify: `Sources/iTime/Services/AIConversationServing.swift`
- Test: `Tests/iTimeTests/AIConversationRoutingServiceTests.swift`

- [ ] **Step 1: Write the failing routing tests**

```swift
@Test func conversationRouterUsesSelectedProvider() async throws {
    let openAI = RecordingConversationService()
    let anthropic = RecordingConversationService()
    let router = AIConversationRoutingService(
        services: [.openAI: openAI, .anthropic: anthropic]
    )

    _ = try await router.askQuestion(
        context: sampleContext,
        history: [],
        configuration: .resolved(provider: .anthropic)
    )

    #expect(openAI.askCount == 0)
    #expect(anthropic.askCount == 1)
}

@Test func anthropicServiceBuildsAnthropicRequestShape() async throws {
    let sender = RecordingAnthropicHTTPSender(...)
    let service = AnthropicConversationService(httpSender: sender)

    _ = try await service.askQuestion(
        context: sampleContext,
        history: [],
        configuration: sampleAnthropicConfiguration
    )

    let body = try #require(sender.lastRequestBodyString)
    #expect(body.contains("\"model\":\"claude-sonnet-4-5\""))
    #expect(body.contains("\"messages\""))
}
```

- [ ] **Step 2: Run the routing tests to verify they fail**

Run: `swift test --filter conversationRouter`

Expected: FAIL with missing router type and missing provider-specific service implementations.

- [ ] **Step 3: Extend runtime configuration to include provider**

```swift
public struct ResolvedAIProviderConfiguration: Equatable, Sendable {
    public let provider: AIProviderKind
    public let baseURL: String
    public let model: String
    public let apiKey: String
    public let isEnabled: Bool
}
```

- [ ] **Step 4: Add the routing service**

```swift
public struct AIConversationRoutingService: AIConversationServing, Sendable {
    private let services: [AIProviderKind: any AIConversationServing]

    public func askQuestion(
        context: AIConversationContext,
        history: [AIConversationMessage],
        configuration: ResolvedAIProviderConfiguration
    ) async throws -> AIConversationMessage {
        guard let service = services[configuration.provider] else {
            throw AIAnalysisServiceError.invalidConfiguration
        }
        return try await service.askQuestion(
            context: context,
            history: history,
            configuration: configuration
        )
    }
}
```

- [ ] **Step 5: Implement one service file per provider**

```swift
public struct AnthropicConversationService: AIConversationServing, Sendable {
    public func askQuestion(...) async throws -> AIConversationMessage {
        var request = URLRequest(url: configuration.messagesURL)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(AnthropicMessagesRequest(...))
        ...
    }
}
```

- [ ] **Step 6: Re-run the routing and provider request tests**

Run: `swift test --filter conversation`

Expected: PASS for routing and provider-specific request-shape coverage.

- [ ] **Step 7: Commit the provider routing layer**

```bash
git add Sources/iTime/Services/AIConversationServing.swift \
  Sources/iTime/Services/AIConversationRoutingService.swift \
  Sources/iTime/Services/OpenAIConversationService.swift \
  Sources/iTime/Services/AnthropicConversationService.swift \
  Sources/iTime/Services/GeminiConversationService.swift \
  Sources/iTime/Services/DeepSeekConversationService.swift \
  Tests/iTimeTests/AIConversationRoutingServiceTests.swift
git commit -m "feat: route AI conversations by provider"
```

---

### Task 3: Rebuild Settings For Multi-Provider Configuration

**Files:**
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`

- [ ] **Step 1: Write the failing settings copy and model tests**

```swift
@Test func settingsCopyListsSupportedProviders() {
    #expect(AIProviderKind.allCases.map(\.title) == ["OpenAI", "Anthropic", "Gemini", "DeepSeek"])
}

@Test func appModelResolvesDefaultProviderConfiguration() {
    let model = makeProviderConfiguredModel(defaultProvider: .gemini)
    let configuration = model.debugCurrentResolvedProviderConfiguration()
    #expect(configuration?.provider == .gemini)
}
```

- [ ] **Step 2: Run the settings tests to verify they fail**

Run: `swift test --filter provider`

Expected: FAIL with missing provider copy exposure and missing default-provider resolution path in `AppModel`.

- [ ] **Step 3: Add provider-aware resolution APIs to `AppModel`**

```swift
func currentAIProviderConfiguration() -> ResolvedAIProviderConfiguration? {
    let provider = preferences.defaultAIProvider
    let config = preferences.aiProviderConfiguration(for: provider)
    return ResolvedAIProviderConfiguration(
        provider: provider,
        baseURL: config.baseURL,
        model: config.model,
        apiKey: (try? aiKeyStore.loadAPIKey(for: provider)) ?? "",
        isEnabled: config.isEnabled && preferences.aiAnalysisEnabled
    )
}
```

- [ ] **Step 4: Replace the single AI form with provider sections**

```swift
Picker(
    "默认 AI",
    selection: Binding(
        get: { model.preferences.defaultAIProvider },
        set: { model.updateDefaultAIProvider($0) }
    )
) {
    ForEach(AIProviderKind.allCases, id: \.self) { provider in
        Text(provider.title).tag(provider)
    }
}

ForEach(AIProviderKind.allCases, id: \.self) { provider in
    Section(provider.title) {
        Toggle("启用 \(provider.title)", isOn: model.bindingForAIProviderEnabled(provider))
        TextField("Base URL", text: model.bindingForAIProviderBaseURL(provider))
        TextField("Model", text: model.bindingForAIProviderModel(provider))
        SecureField("API Key", text: bindingForAPIKey(provider))
    }
}
```

- [ ] **Step 5: Re-run the provider/settings tests**

Run: `swift test --filter provider`

Expected: PASS for copy, persistence, and `AppModel` resolution behavior.

- [ ] **Step 6: Commit the settings redesign**

```bash
git add Sources/iTime/UI/Settings/SettingsView.swift \
  Sources/iTime/App/AppModel.swift \
  Tests/iTimeTests/PresentationTests.swift \
  Tests/iTimeTests/AIProviderSettingsTests.swift
git commit -m "feat: add multi-provider AI settings"
```

---

### Task 4: Move Chat Into A Dedicated Window

**Files:**
- Create: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- Create: `Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift`
- Create: `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`
- Create: `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`
- Modify: `Sources/iTime/iTimeApp.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing presentation tests for the new entry flow**

```swift
@Test func aiAnalysisCopyUsesWindowEntryStrings() {
    #expect(AIAnalysisCopy.openWindowAction == "打开 AI 复盘")
    #expect(AIAnalysisCopy.historyAction == "查看历史总结")
}

@Test func overviewAICardNoLongerOwnsInputCopy() {
    #expect(AIAnalysisCopy.inlineComposerRemoved == true)
}
```

- [ ] **Step 2: Run the presentation tests to verify they fail**

Run: `swift test --filter aiAnalysisCopyUsesWindowEntryStrings`

Expected: FAIL with missing new window-entry copy.

- [ ] **Step 3: Add the AI conversation window scene**

```swift
Window("AI 复盘", id: "ai-conversation") {
    AIConversationWindowView(model: model)
}
.defaultSize(width: 720, height: 760)
```

- [ ] **Step 4: Build the chat window shell**

```swift
struct AIConversationWindowView: View {
    @Bindable var model: AppModel
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            AIConversationMessagesView(state: model.aiConversationState)
            Divider()
            AIConversationComposerView(
                draft: $draft,
                isFocused: $isComposerFocused,
                onSend: { Task { await model.sendAIConversationReply(draft) } },
                onFinish: { Task { await model.finishAIConversation() } }
            )
        }
    }
}
```

- [ ] **Step 5: Simplify the overview AI card into an entry card**

```swift
Button(AIAnalysisCopy.openWindowAction) {
    openWindow(id: "ai-conversation")
}

if let summary = model.aiConversationHistory.first {
    Text(summary.headline)
    Text(summary.summary).lineLimit(3)
}
```

- [ ] **Step 6: Re-run the presentation tests and the app-model chat tests**

Run: `swift test --filter AIConversation`

Expected: PASS with the overview card no longer owning the inline text field.

- [ ] **Step 7: Commit the window migration**

```bash
git add Sources/iTime/iTimeApp.swift \
  Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift \
  Sources/iTime/UI/AIConversation/AIConversationWindowView.swift \
  Sources/iTime/UI/AIConversation/AIConversationMessagesView.swift \
  Sources/iTime/UI/AIConversation/AIConversationComposerView.swift \
  Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift \
  Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: move AI chat into dedicated window"
```

---

### Task 5: Bind Conversations To The Selected Provider And Stabilize UX

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Sources/iTime/Domain/AIConversation.swift`
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- Modify: `Sources/iTime/UI/AIConversation/AIConversationComposerView.swift`
- Test: `Tests/iTimeTests/AIConversationAppModelTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing provider-binding and stability tests**

```swift
@Test func conversationBindsProviderAtStartTime() async {
    let model = makeProviderConfiguredModel(defaultProvider: .openAI)
    await model.startAIConversation()
    model.updateDefaultAIProvider(.anthropic)

    let activeSession = try #require(model.activeAIConversationSession)
    #expect(activeSession.provider == .openAI)
}

@Test func endingConversationDoesNotClearComposerStatePrematurely() async {
    let model = makeStartedConversationModel()
    model.aiConversationDraft = "补充说明"
    await model.finishAIConversation()
    #expect(model.aiConversationState.isCompleted)
}
```

- [ ] **Step 2: Run the targeted chat stability tests to verify they fail**

Run: `swift test --filter conversationBindsProviderAtStartTime`

Expected: FAIL with missing provider binding on `AIConversationSession` and missing draft/focus coordination.

- [ ] **Step 3: Persist provider identity on sessions and summaries**

```swift
public struct AIConversationSession: Equatable, Codable, Sendable {
    public let provider: AIProviderKind
    ...
}

public struct AIConversationSummary: Equatable, Codable, Sendable {
    public let provider: AIProviderKind
    ...
}
```

- [ ] **Step 4: Keep composer state window-local and focus-driven**

```swift
@State private var draft = ""
@FocusState private var composerFocused: Bool

.onAppear {
    composerFocused = true
}
```

- [ ] **Step 5: Re-run targeted chat stability tests**

Run: `swift test --filter conversation`

Expected: PASS for provider-binding and no inline composer regression.

- [ ] **Step 6: Commit the session-binding and stability work**

```bash
git add Sources/iTime/App/AppModel.swift \
  Sources/iTime/Domain/AIConversation.swift \
  Sources/iTime/UI/AIConversation/AIConversationWindowView.swift \
  Sources/iTime/UI/AIConversation/AIConversationComposerView.swift \
  Tests/iTimeTests/AIConversationAppModelTests.swift \
  Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: bind AI sessions to selected provider"
```

---

### Task 6: Final Verification And Project Wiring

**Files:**
- Modify: `iTime.xcodeproj/project.pbxproj`
- Optional: `README.md` if behavior or setup instructions changed materially

- [ ] **Step 1: Add all new source and test files to the Xcode project**

```pbxproj
A000... /* AIProvider.swift in Sources */ = {isa = PBXBuildFile; ... };
A000... /* AIConversationWindowView.swift in Sources */ = {isa = PBXBuildFile; ... };
A000... /* AIConversationRoutingServiceTests.swift in Sources */ = {isa = PBXBuildFile; ... };
```

- [ ] **Step 2: Run SwiftPM tests**

Run: `swift test`

Expected: PASS with all provider, routing, app-model, and presentation tests green.

- [ ] **Step 3: Run Xcode tests**

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: Update README only if setup instructions changed**

```md
## AI 评估

- 支持 OpenAI、Anthropic、Gemini、DeepSeek
- 在设置中分别配置 Base URL、Model、API Key
- 从详情页打开独立 AI 复盘窗口
```

- [ ] **Step 5: Commit project wiring and docs**

```bash
git add iTime.xcodeproj/project.pbxproj README.md
git commit -m "docs: update AI provider and chat setup"
```

---

## Self-Review

- Spec coverage:
  - 多 provider 设置: Task 1 + Task 3
  - 独立聊天窗口: Task 4
  - 会话绑定 provider: Task 5
  - 稳定输入区: Task 4 + Task 5
  - 路由到不同 provider client: Task 2
- Placeholder scan:
  - No `TODO`, `TBD`, or “implement later” placeholders remain.
- Type consistency:
  - `AIProviderKind`, `AIProviderConfiguration`, `ResolvedAIProviderConfiguration`, `AIConversationRoutingService`, and window view names are used consistently across tasks.

