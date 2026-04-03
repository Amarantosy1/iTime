# AI 服务层重做 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除现有 AI 挂载体系，重做为“内置 provider + 自定义 OpenAI-compatible 服务”的 AI 服务层，并完成设置页、对话窗口和持久化迁移。

**Architecture:** 这次重构以“Provider Catalog + Service Endpoint”替换现有 `AIProviderMount` 抽象。持久化层先完成旧 mount 到新 service endpoint 的迁移，然后 `AppModel`、设置页和对话窗口一起切换到新的 `serviceID + model` 绑定方式；网络层继续使用系统默认网络栈，不新增代理 UI。

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, UserDefaults, Keychain, URLSession, Xcode project + SwiftPM tests

---

## File Map

### Delete

- `Sources/iTime/Domain/AIProviderMount.swift`

### Create

- `Sources/iTime/Domain/AIServiceEndpoint.swift`
- `Sources/iTime/Domain/AIProviderCatalog.swift`
- `Tests/iTimeTests/AIServiceEndpointMigrationTests.swift`

### Modify

- `Sources/iTime/Domain/AIProvider.swift`
- `Sources/iTime/Support/Persistence/UserPreferences.swift`
- `Sources/iTime/App/AppModel.swift`
- `Sources/iTime/Services/AIConversationRoutingService.swift`
- `Sources/iTime/UI/Settings/SettingsView.swift`
- `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`
- `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
- `Sources/iTime/Services/OpenAICompatibleAIAnalysisService.swift`
- `Tests/iTimeTests/AIProviderSettingsTests.swift`
- `Tests/iTimeTests/AIConversationAppModelTests.swift`
- `Tests/iTimeTests/PresentationTests.swift`
- `iTime.xcodeproj/project.pbxproj`
- `README.md`

### Keep but adapt

- `Sources/iTime/Services/OpenAIConversationService.swift`
- `Sources/iTime/Services/DeepSeekConversationService.swift`
- `Sources/iTime/Services/AnthropicConversationService.swift`
- `Sources/iTime/Services/GeminiConversationService.swift`

---

### Task 1: Replace Mount Model With Service Endpoint Model

**Files:**
- Create: `Sources/iTime/Domain/AIServiceEndpoint.swift`
- Create: `Sources/iTime/Domain/AIProviderCatalog.swift`
- Modify: `Sources/iTime/Domain/AIProvider.swift`
- Delete: `Sources/iTime/Domain/AIProviderMount.swift`
- Test: `Tests/iTimeTests/AIProviderSettingsTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing tests for new service model names and provider kind**

Add assertions to `Tests/iTimeTests/AIProviderSettingsTests.swift` and `Tests/iTimeTests/PresentationTests.swift` for:

```swift
@Test func builtInAIServicesExistByDefault() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.aiServiceEndpoints.count == 4)
    #expect(preferences.aiServiceEndpoints.map(\.providerKind) == [.openAI, .anthropic, .gemini, .deepSeek])
}

@Test func customAIServiceUsesOpenAICompatibleProvider() {
    let service = AIServiceEndpoint.custom(
        displayName: "公司网关",
        providerKind: .openAICompatible,
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-4.1-mini"],
        defaultModel: "gpt-4.1-mini"
    )

    #expect(service.providerKind == .openAICompatible)
    #expect(service.isBuiltIn == false)
}

@Test func aiSettingsCopyUsesServiceLanguage() {
    #expect(SettingsCopy.aiMountSectionTitle == "AI 服务")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter builtInAIServicesExistByDefault
swift test --filter customAIServiceUsesOpenAICompatibleProvider
swift test --filter aiSettingsCopyUsesServiceLanguage
```

Expected:
- compile errors for missing `aiServiceEndpoints` and `AIServiceEndpoint`
- old “挂载” naming assertions fail

- [ ] **Step 3: Implement the new domain types**

Create `Sources/iTime/Domain/AIServiceEndpoint.swift`:

```swift
import Foundation

public struct AIServiceEndpoint: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let displayName: String
    public let providerKind: AIProviderKind
    public let baseURL: String
    public let models: [String]
    public let defaultModel: String
    public let isEnabled: Bool
    public let isBuiltIn: Bool

    public init(
        id: UUID,
        displayName: String,
        providerKind: AIProviderKind,
        baseURL: String,
        models: [String],
        defaultModel: String,
        isEnabled: Bool,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.providerKind = providerKind
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        self.models = models.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.defaultModel = defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
    }

    public static func builtIn(
        providerKind: AIProviderKind,
        baseURL: String? = nil,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIServiceEndpoint {
        AIServiceEndpoint(
            id: providerKind.builtInServiceID,
            displayName: providerKind.title,
            providerKind: providerKind,
            baseURL: baseURL ?? providerKind.defaultBaseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: true
        )
    }

    public static func custom(
        displayName: String,
        providerKind: AIProviderKind = .openAICompatible,
        baseURL: String,
        models: [String] = [],
        defaultModel: String = "",
        isEnabled: Bool = false
    ) -> AIServiceEndpoint {
        AIServiceEndpoint(
            id: UUID(),
            displayName: displayName,
            providerKind: providerKind,
            baseURL: baseURL,
            models: models,
            defaultModel: defaultModel,
            isEnabled: isEnabled,
            isBuiltIn: false
        )
    }
}
```

Create `Sources/iTime/Domain/AIProviderCatalog.swift`:

```swift
import Foundation

public struct AIProviderCatalogItem: Equatable, Sendable, Identifiable {
    public let id: AIProviderKind
    public let kind: AIProviderKind
    public let title: String
    public let defaultBaseURL: String
    public let supportsCustomEndpoint: Bool
    public let isBuiltIn: Bool
}

public enum AIProviderCatalog {
    public static let builtInItems: [AIProviderCatalogItem] = [
        .init(id: .openAI, kind: .openAI, title: AIProviderKind.openAI.title, defaultBaseURL: AIProviderKind.openAI.defaultBaseURL, supportsCustomEndpoint: false, isBuiltIn: true),
        .init(id: .anthropic, kind: .anthropic, title: AIProviderKind.anthropic.title, defaultBaseURL: AIProviderKind.anthropic.defaultBaseURL, supportsCustomEndpoint: false, isBuiltIn: true),
        .init(id: .gemini, kind: .gemini, title: AIProviderKind.gemini.title, defaultBaseURL: AIProviderKind.gemini.defaultBaseURL, supportsCustomEndpoint: false, isBuiltIn: true),
        .init(id: .deepSeek, kind: .deepSeek, title: AIProviderKind.deepSeek.title, defaultBaseURL: AIProviderKind.deepSeek.defaultBaseURL, supportsCustomEndpoint: false, isBuiltIn: true),
        .init(id: .openAICompatible, kind: .openAICompatible, title: AIProviderKind.openAICompatible.title, defaultBaseURL: "", supportsCustomEndpoint: true, isBuiltIn: false),
    ]
}
```

Modify `Sources/iTime/Domain/AIProvider.swift`:

```swift
public enum AIProviderKind: String, CaseIterable, Codable, Sendable {
    case openAI
    case anthropic
    case gemini
    case deepSeek
    case openAICompatible

    public var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        case .openAICompatible: "OpenAI Compatible"
        }
    }

    public var builtInServiceID: UUID {
        switch self {
        case .openAI: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        case .anthropic: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        case .gemini: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        case .deepSeek: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        case .openAICompatible: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter builtInAIServicesExistByDefault
swift test --filter customAIServiceUsesOpenAICompatibleProvider
swift test --filter aiSettingsCopyUsesServiceLanguage
```

Expected:
- all three tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Domain/AIProvider.swift Sources/iTime/Domain/AIServiceEndpoint.swift Sources/iTime/Domain/AIProviderCatalog.swift Sources/iTime/Domain/AIProviderMount.swift Tests/iTimeTests/AIProviderSettingsTests.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "refactor: replace AI mounts with services"
```

### Task 2: Migrate Preferences From Mounts To Services

**Files:**
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Create: `Tests/iTimeTests/AIServiceEndpointMigrationTests.swift`
- Modify: `Tests/iTimeTests/AIProviderSettingsTests.swift`

- [ ] **Step 1: Write the failing migration tests**

Create `Tests/iTimeTests/AIServiceEndpointMigrationTests.swift` with:

```swift
import Foundation
import Testing
@testable import iTime

@Test func legacyMountsMigrateToServiceEndpoints() {
    let suite = "iTime.tests.ai-services-migration"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    let legacyMounts = [
        AIServiceEndpoint.builtIn(providerKind: .openAI, baseURL: "https://api.openai.com/v1", models: ["gpt-4.1"], defaultModel: "gpt-4.1", isEnabled: true),
        AIServiceEndpoint.custom(displayName: "代理", baseURL: "https://proxy.example.com/v1", models: ["gpt-4.1-mini"], defaultModel: "gpt-4.1-mini", isEnabled: true),
    ]

    let legacyData = try! JSONEncoder().encode(legacyMounts)
    defaults.set(legacyData, forKey: "aiProviderMounts")
    defaults.set(legacyMounts[1].id.uuidString.lowercased(), forKey: "defaultAIMountID")

    let preferences = UserPreferences(storage: .inMemory, suiteNameOverride: suite)

    #expect(preferences.aiServiceEndpoints.count >= 4)
    #expect(preferences.aiServiceEndpoints.contains(where: { $0.displayName == "代理" && $0.providerKind == .openAICompatible }))
    #expect(preferences.defaultAIServiceID == legacyMounts[1].id)
}
```

Update `Tests/iTimeTests/AIProviderSettingsTests.swift` to assert:

```swift
#expect(preferences.defaultAIServiceID != nil)
#expect(preferences.aiServiceEndpoints.contains(where: { $0.id == custom.id }))
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter legacyMountsMigrateToServiceEndpoints
swift test --filter aiProviderMountsMigrateFromLegacyProviderPreferences
```

Expected:
- missing `aiServiceEndpoints`
- missing `defaultAIServiceID`
- old mount-centric assumptions fail

- [ ] **Step 3: Implement migration and new preference storage**

Modify `Sources/iTime/Support/Persistence/UserPreferences.swift`:

```swift
private enum Keys {
    static let aiServiceEndpoints = "aiServiceEndpoints"
    static let defaultAIServiceID = "defaultAIServiceID"
}

public private(set) var aiServiceEndpoints: [AIServiceEndpoint] {
    didSet { persistAIServices() }
}

public private(set) var defaultAIServiceID: UUID? {
    didSet { defaults.set(defaultAIServiceID?.uuidString.lowercased(), forKey: Keys.defaultAIServiceID) }
}

public var defaultAIService: AIServiceEndpoint? {
    let services = Self.normalizedBuiltInServices(aiServiceEndpoints)
    guard let defaultAIServiceID else { return services.first }
    return services.first(where: { $0.id == defaultAIServiceID }) ?? services.first
}
```

Add migration helpers:

```swift
private static func decodeAIServices(from defaults: UserDefaults) -> [AIServiceEndpoint] { ... }
private static func decodeLegacyMounts(from defaults: UserDefaults) -> [AIServiceEndpoint] { ... }
private static func normalizedBuiltInServices(_ services: [AIServiceEndpoint]) -> [AIServiceEndpoint] { ... }
private func persistAIServices() { ... }
```

Migration rule in initializer:

```swift
let decodedServices = Self.decodeAIServices(from: defaults)
let startingServices = decodedServices.isEmpty ? Self.decodeLegacyMounts(from: defaults) : decodedServices
self.aiServiceEndpoints = Self.normalizedBuiltInServices(startingServices)
```

When migrating legacy custom mounts:

```swift
AIServiceEndpoint(
    id: legacy.id,
    displayName: legacy.displayName,
    providerKind: legacy.isBuiltIn ? legacy.providerType : .openAICompatible,
    baseURL: legacy.baseURL,
    models: legacy.models,
    defaultModel: legacy.defaultModel,
    isEnabled: legacy.isEnabled,
    isBuiltIn: legacy.isBuiltIn
)
```

- [ ] **Step 4: Run migration tests to verify they pass**

Run:

```bash
swift test --filter legacyMountsMigrateToServiceEndpoints
swift test --filter aiProviderMountsMigrateFromLegacyProviderPreferences
```

Expected:
- migration tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Support/Persistence/UserPreferences.swift Tests/iTimeTests/AIServiceEndpointMigrationTests.swift Tests/iTimeTests/AIProviderSettingsTests.swift
git commit -m "feat: migrate AI preferences to services"
```

### Task 3: Switch AppModel From Mounts To Services

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: Write the failing AppModel tests for service-based selection**

Replace mount-centric test names and expectations with service names:

```swift
@MainActor
@Test func startAIConversationBindsSelectedServiceAndModel() async {
    let service = AIServiceEndpoint.custom(
        displayName: "公司 OpenAI 网关",
        baseURL: "https://proxy.example.com/v1",
        models: ["gpt-4.1", "gpt-4.1-mini"],
        defaultModel: "gpt-4.1-mini",
        isEnabled: true
    )
    ...
    #expect(session.serviceID == service.id)
    #expect(session.serviceDisplayName == "公司 OpenAI 网关")
    #expect(conversationService.askedConfigurations.first?.provider == .openAICompatible)
}
```

```swift
@MainActor
@Test func testAIServiceConnectionDoesNotDependOnLegacyAnalysisToggle() async {
    ...
    await model.testAIServiceConnection(service.id)
    #expect(model.aiServiceConnectionState(for: service.id) == .succeeded("连接成功"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter startAIConversationBindsSelectedServiceAndModel
swift test --filter testAIServiceConnectionDoesNotDependOnLegacyAnalysisToggle
```

Expected:
- missing `serviceID`, `testAIServiceConnection`, and service selection properties

- [ ] **Step 3: Rewrite AppModel service state and helpers**

Modify `Sources/iTime/App/AppModel.swift`:

```swift
public private(set) var availableAIServices: [AIServiceEndpoint]
public private(set) var aiServiceConnectionStates: [UUID: AIMountConnectionState]
public var defaultAIServiceID: UUID? { preferences.defaultAIServiceID }
public var selectedConversationServiceID: UUID?
```

Replace APIs:

```swift
@discardableResult
public func createCustomAIService() -> UUID { ... }
public func updateAIService(_ service: AIServiceEndpoint) { ... }
public func deleteAIService(id: UUID) { ... }
public func setDefaultAIService(id: UUID) { ... }
public func aiServiceConnectionState(for serviceID: UUID) -> AIMountConnectionState { ... }
public func testAIServiceConnection(_ serviceID: UUID) async { ... }
public func selectConversationService(id: UUID) { ... }
```

Update configuration resolution:

```swift
private func currentSelectedAIService() -> AIServiceEndpoint? { ... }

private func resolvedAIConversationConfiguration(
    serviceID: UUID?,
    provider: AIProviderKind,
    model: String
) -> ResolvedAIProviderConfiguration {
    if let serviceID, let service = availableAIServices.first(where: { $0.id == serviceID }) {
        return ResolvedAIProviderConfiguration(
            provider: service.providerKind,
            baseURL: service.baseURL,
            model: resolvedModel(for: service, selectedModel: model),
            apiKey: (try? aiKeyStore.loadAPIKey(for: service.id)) ?? "",
            isEnabled: service.isEnabled
        )
    }
    ...
}
```

Adjust session creation fields:

```swift
serviceID: selectedService.id,
serviceDisplayName: selectedService.displayName,
provider: selectedService.providerKind,
```

- [ ] **Step 4: Run AppModel tests to verify they pass**

Run:

```bash
swift test --filter AIConversationAppModelTests
```

Expected:
- all AppModel AI conversation tests pass with service naming

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/App/AppModel.swift Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "refactor: bind AI conversations to services"
```

### Task 4: Route Requests Through Service-Based Provider Adapters

**Files:**
- Modify: `Sources/iTime/Services/AIConversationRoutingService.swift`
- Modify: `Sources/iTime/Domain/AIProvider.swift`
- Modify: `Tests/iTimeTests/AIConversationRoutingServiceTests.swift`
- Modify: `Tests/iTimeTests/AIAnalysisServiceTests.swift`

- [ ] **Step 1: Write the failing routing tests for custom OpenAI-compatible services**

Add:

```swift
@Test func conversationRouterUsesOpenAICompatibleServiceForCustomEndpoint() async throws {
    let service = RecordingConversationService()
    let router = AIConversationRoutingService(
        services: [
            .openAICompatible: service
        ]
    )

    try await router.validateConnection(
        configuration: ResolvedAIProviderConfiguration(
            provider: .openAICompatible,
            baseURL: "https://proxy.example.com/v1",
            model: "gpt-4.1-mini",
            apiKey: "secret",
            isEnabled: true
        )
    )

    #expect(service.validatedProviders == [.openAICompatible])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter conversationRouterUsesOpenAICompatibleServiceForCustomEndpoint
```

Expected:
- missing `.openAICompatible` support in routing

- [ ] **Step 3: Implement service routing support**

Modify `Sources/iTime/Services/AIConversationRoutingService.swift` only as needed so that:

```swift
let services: [AIProviderKind: any AIConversationServing] = [
    .openAI: OpenAIConversationService(),
    .openAICompatible: OpenAIConversationService(),
    .anthropic: AnthropicConversationService(),
    .gemini: GeminiConversationService(),
    .deepSeek: DeepSeekConversationService(),
]
```

Keep Gemini/Anthropic specialized; keep DeepSeek and OpenAI-compatible on the OpenAI-compatible adapter.

Confirm sender config still uses:

```swift
let configuration = URLSessionAIAnalysisHTTPSender.defaultConfiguration()
#expect(configuration.connectionProxyDictionary == nil)
```

- [ ] **Step 4: Run routing tests to verify they pass**

Run:

```bash
swift test --filter AIConversationRoutingServiceTests
swift test --filter urlSessionSenderUsesDefaultConfigurationThatFollowsSystemNetworking
```

Expected:
- routing tests pass
- sender default networking test still passes

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Services/AIConversationRoutingService.swift Sources/iTime/Domain/AIProvider.swift Tests/iTimeTests/AIConversationRoutingServiceTests.swift Tests/iTimeTests/AIAnalysisServiceTests.swift
git commit -m "feat: route AI requests by service provider"
```

### Task 5: Rewrite Settings UI From “挂载” To “AI 服务”

**Files:**
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing UI copy tests**

Add:

```swift
@Test func aiSettingsUseServiceTerminology() {
    #expect(SettingsCopy.aiMountSectionTitle == "AI 服务")
    #expect(AISettingsCopy.sectionTitle == "AI 服务")
    #expect(AISettingsCopy.addCustomMountAction == "新增服务")
    #expect(AISettingsCopy.setDefaultMountAction == "设为默认服务")
    #expect(AISettingsCopy.deleteMountAction == "删除服务")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter aiSettingsUseServiceTerminology
```

Expected:
- old “挂载” text still present

- [ ] **Step 3: Rewrite SettingsView around services**

Modify `Sources/iTime/UI/Settings/SettingsView.swift`:

```swift
enum SettingsCopy {
    static let aiMountSectionTitle = "AI 服务"
}

enum AISettingsCopy {
    static let sectionTitle = SettingsCopy.aiMountSectionTitle
    static let addCustomMountAction = "新增服务"
    static let setDefaultMountAction = "设为默认服务"
    static let deleteMountAction = "删除服务"
    static let customBadge = "自定义"
    static let builtInBadge = "内置"
}
```

Replace `availableAIMounts` with `availableAIServices`, and use:

```swift
selectedServiceID = model.createCustomAIService()
model.updateAIService(updatedService)
model.setDefaultAIService(id: service.id)
Task { await model.testAIServiceConnection(service.id) }
```

Keep sidebar sections:

```swift
case .calendars
case .aiMounts
```

but render the right pane title as `AI 服务`; no “挂载” should appear in visible copy.

- [ ] **Step 4: Run presentation tests to verify they pass**

Run:

```bash
swift test --filter PresentationTests
```

Expected:
- presentation tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Settings/SettingsView.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "refactor: rewrite settings for AI services"
```

### Task 6: Update Conversation Window To Select Service + Model

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift`
- Modify: `Tests/iTimeTests/PresentationTests.swift`
- Modify: `Tests/iTimeTests/AIConversationAppModelTests.swift`

- [ ] **Step 1: Write the failing tests for service selection wording**

Add:

```swift
@Test func aiConversationWindowUsesServiceSelectionTitles() {
    #expect(AIConversationWindowCopy.mountSelectionTitle == "服务")
    #expect(AIConversationWindowCopy.mountSelectionHint == "开始前可切换服务和模型。")
}
```

Update AppModel UI-driven tests to look for selected service bindings instead of mount bindings.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter aiConversationWindowUsesServiceSelectionTitles
```

Expected:
- old “挂载” wording fails

- [ ] **Step 3: Implement service-first window selection**

Modify `Sources/iTime/UI/AIConversation/AIConversationWindowView.swift`:

```swift
enum AIConversationWindowCopy {
    static let mountSelectionTitle = "服务"
    static let mountSelectionHint = "开始前可切换服务和模型。"
}
```

Use:

```swift
Picker(
    AIConversationWindowCopy.mountSelectionTitle,
    selection: Binding(
        get: { model.selectedConversationServiceID ?? UUID() },
        set: { model.selectConversationService(id: $0) }
    )
) {
    ForEach(model.availableAIServices) { service in
        Text(service.displayName).tag(service.id)
    }
}
```

Update `OverviewAIAnalysisSection.swift` only if any summary or helper text still mentions mounts.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter aiConversationWindowUsesServiceSelectionTitles
swift test --filter AIConversationAppModelTests
```

Expected:
- service wording passes
- conversation model tests remain green

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationWindowView.swift Sources/iTime/UI/Overview/OverviewAIAnalysisSection.swift Tests/iTimeTests/PresentationTests.swift Tests/iTimeTests/AIConversationAppModelTests.swift
git commit -m "refactor: select AI services before conversation start"
```

### Task 7: Clean Up Legacy Mount References and Sync Xcode Project

**Files:**
- Modify: `iTime.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Modify: any lingering `Sources/iTime/**/*.swift`
- Test: full suite

- [ ] **Step 1: Write the failing cleanup check**

Search for lingering mount references:

```bash
rg -n "Mount|mount|挂载|defaultAIMountID|aiProviderMounts|availableAIMounts" Sources/iTime Tests/iTimeTests README.md
```

Expected:
- remaining hits show what still needs renaming or deletion

- [ ] **Step 2: Remove legacy references and update docs**

Update `README.md` so the AI section says:

```md
- 点击“设置”可打开原生设置窗口，勾选要纳入统计的日历，并配置 AI 服务的 `Base URL / Model / API Key`
- AI 对话开始前可以选择服务与模型
- 内置服务包含 `OpenAI / Anthropic / Gemini / DeepSeek`
- 自定义服务支持 `OpenAI-compatible`
```

Update `iTime.xcodeproj/project.pbxproj`:
- remove `AIProviderMount.swift`
- add `AIServiceEndpoint.swift`
- add `AIProviderCatalog.swift`
- add `AIServiceEndpointMigrationTests.swift`

- [ ] **Step 3: Run full verification**

Run:

```bash
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test
```

Expected:
- `swift test`: PASS, all tests green
- `xcodebuild ... test`: `** TEST SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add README.md iTime.xcodeproj/project.pbxproj Sources/iTime Tests/iTimeTests
git commit -m "chore: finalize AI services redesign"
```

---

## Self-Review

### Spec coverage

- 删除旧 mount 概念：Task 1, Task 2, Task 3, Task 7
- 新 `provider catalog + service endpoint`：Task 1
- 迁移策略：Task 2
- 设置页 AI 服务化：Task 5
- 对话窗口开始前选择服务与模型：Task 6
- 路由与网络默认跟系统走：Task 4
- 文案和测试清理：Task 5, Task 6, Task 7

无缺口。

### Placeholder scan

- 未使用 `TBD`/`TODO`
- 所有任务包含具体文件、命令和代码片段
- 未使用“类似前面任务”的模糊描述

### Type consistency

- 新核心类型统一为 `AIServiceEndpoint`
- 默认 ID 统一为 `defaultAIServiceID`
- 选择器统一为 `selectedConversationServiceID`
- 测试连接统一为 `testAIServiceConnection`

类型和命名一致。
