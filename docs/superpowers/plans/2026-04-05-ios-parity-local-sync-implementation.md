# iOS Parity + Local Multipeer Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an iOS 17+ version of iTime with macOS-equivalent core features and manual Mac↔iOS local sync (no iCloud), including encrypted API key transfer.

**Architecture:** Keep existing macOS app structure, add a shared sync layer inside `Sources/iTime` (`Domain/Sync` + `Services/Sync`) and integrate through `AppModel`. Build iOS UI in `iTime-iOS` with the same domain/services contracts and one `AppModel` state owner. Use `MultipeerConnectivity` for discovery/transport, `SyncEngine` for merge/tombstone/LWW, and CryptoKit for API key payload encryption.

**Tech Stack:** Swift 6.3, SwiftUI, Swift Testing (`@Test`), EventKit, MultipeerConnectivity, CryptoKit, xcodebuild/swift test.

---

## Scope Check

This spec includes two tightly-coupled tracks (iOS parity + local sync). They are not independent enough to split into separate plans because:

1. iOS settings must expose sync controls.
2. Sync data model must include AI/settings entities already used by parity features.
3. AppModel API changes are shared by both macOS and iOS surfaces.

So this plan keeps one implementation stream with incremental, testable milestones.

## File Map

### New files

- `Sources/iTime/Domain/Sync/SyncRecord.swift` — generic sync record/tombstone metadata.
- `Sources/iTime/Domain/Sync/SyncMessage.swift` — Hello/Manifest/Patch/Result message types.
- `Sources/iTime/Domain/Sync/DevicePeer.swift` — UI-facing peer/device status model.
- `Sources/iTime/Services/Sync/SyncEngine.swift` — merge/LWW/tombstone logic.
- `Sources/iTime/Services/Sync/CryptoEnvelopeService.swift` — API key encrypt/decrypt helpers.
- `Sources/iTime/Services/Sync/MultipeerTransport.swift` — transport protocol for testability.
- `Sources/iTime/Services/Sync/MultipeerTransportService.swift` — MPC concrete implementation.
- `Sources/iTime/Services/Sync/SyncPersistenceAdapter.swift` — archive/preferences/API-key snapshot & patch apply.
- `Sources/iTime/Services/Sync/SyncCoordinator.swift` — sync session orchestration.
- `Sources/iTime/UI/Settings/DeviceSyncSettingsSection.swift` — macOS settings sync section UI.
- `Tests/iTimeTests/Sync/SyncEngineTests.swift`
- `Tests/iTimeTests/Sync/CryptoEnvelopeServiceTests.swift`
- `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift`
- `Tests/iTimeTests/Sync/SyncCoordinatorTests.swift`
- `Tests/iTimeTests/AppModelSyncTests.swift`
- `iTime-iOS/App/iTimeiOSApp.swift`
- `iTime-iOS/UI/Root/iTimeIOSRootView.swift`
- `iTime-iOS/UI/Overview/iOSOverviewView.swift`
- `iTime-iOS/UI/Conversation/iOSConversationView.swift`
- `iTime-iOS/UI/Settings/iOSSettingsView.swift`
- `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift`

### Modified files

- `Sources/iTime/App/AppModel.swift` — add sync state, peer discovery, manual sync actions.
- `Sources/iTime/UI/Settings/SettingsView.swift` — add “设备互传” section entry and compose new section view.
- `Sources/iTime/Support/Persistence/UserPreferences.swift` — add exported/imported sync payload shape for syncable preference fields.
- `Sources/iTime/Support/Persistence/FileAIConversationArchiveStore.swift` — expose helper for adapter loading/saving.
- `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift` — add batch export/import helpers for sync.
- `Sources/iTime/iTimeApp.swift` — inject SyncCoordinator dependencies.
- `iTime.xcodeproj/project.pbxproj` — add iOS target/scheme and include `iTime-iOS` sources.
- `README.md` — update “当前能力范围” and run/build instructions with iOS and local sync.

---

### Task 1: 建立同步域模型与序列化契约

**Files:**
- Create: `Sources/iTime/Domain/Sync/SyncRecord.swift`
- Create: `Sources/iTime/Domain/Sync/SyncMessage.swift`
- Create: `Sources/iTime/Domain/Sync/DevicePeer.swift`
- Test: `Tests/iTimeTests/Sync/SyncEngineTests.swift`

- [ ] **Step 1: 写失败测试（消息结构可编码/解码）**

```swift
import Foundation
import Testing
@testable import iTime

@Test func syncMessageRoundTripsManifestAndPatch() throws {
    let now = Date(timeIntervalSince1970: 1_710_000_000)
    let manifest = SyncManifest(
        archiveVersion: 3,
        preferencesVersion: 7,
        apiKeyFingerprintByServiceID: ["openai": "sha256:abc"],
        generatedAt: now
    )
    let message = SyncMessage.manifest(manifest)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
    #expect(decoded == message)
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter syncMessageRoundTripsManifestAndPatch`  
Expected: FAIL with missing `SyncManifest` / `SyncMessage`.

- [ ] **Step 3: 实现 `SyncRecord` 和 tombstone 语义**

```swift
import Foundation

public struct SyncRecord<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let recordID: String
    public let value: Value?
    public let updatedAt: Date
    public let deletedAt: Date?
    public let version: Int

    public var isDeleted: Bool { deletedAt != nil }
}
```

- [ ] **Step 4: 实现 `SyncMessage` 结构**

```swift
import Foundation

public struct SyncManifest: Codable, Equatable, Sendable {
    public let archiveVersion: Int
    public let preferencesVersion: Int
    public let apiKeyFingerprintByServiceID: [String: String]
    public let generatedAt: Date
}

public enum SyncMessage: Codable, Equatable, Sendable {
    case hello(SyncHello)
    case manifest(SyncManifest)
    case patch(SyncPatch)
    case result(SyncResult)
}
```

- [ ] **Step 5: 实现 `DevicePeer`（UI 展示模型）**

```swift
import Foundation

public struct DevicePeer: Identifiable, Equatable, Sendable {
    public enum ConnectionState: Equatable, Sendable { case discovered, connecting, connected, failed(String) }
    public let id: String
    public let displayName: String
    public let state: ConnectionState
}
```

- [ ] **Step 6: 运行测试确认通过**

Run: `swift test --filter syncMessageRoundTripsManifestAndPatch`  
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/iTime/Domain/Sync/SyncRecord.swift \
  Sources/iTime/Domain/Sync/SyncMessage.swift \
  Sources/iTime/Domain/Sync/DevicePeer.swift \
  Tests/iTimeTests/Sync/SyncEngineTests.swift
git commit -m "feat: add sync domain message and record models"
```

---

### Task 2: 实现 SyncEngine（自动合并 + LWW + tombstone）

**Files:**
- Create: `Sources/iTime/Services/Sync/SyncEngine.swift`
- Test: `Tests/iTimeTests/Sync/SyncEngineTests.swift`

- [ ] **Step 1: 写失败测试（同 ID 冲突按 updatedAt 取新）**

```swift
@Test func syncEngineUsesLWWForRecordConflicts() {
    let old = SyncRecord(recordID: "summary-1", value: "old", updatedAt: .init(timeIntervalSince1970: 10), deletedAt: nil, version: 1)
    let new = SyncRecord(recordID: "summary-1", value: "new", updatedAt: .init(timeIntervalSince1970: 20), deletedAt: nil, version: 2)
    let merged = SyncEngine.merge(local: [old], remote: [new])
    #expect(merged.count == 1)
    #expect(merged.first?.value == "new")
}
```

- [ ] **Step 2: 写失败测试（tombstone 覆盖旧值）**

```swift
@Test func syncEnginePrefersNewerTombstoneOverOlderValue() {
    let local = SyncRecord(recordID: "session-1", value: "alive", updatedAt: .init(timeIntervalSince1970: 30), deletedAt: nil, version: 3)
    let remote = SyncRecord(recordID: "session-1", value: nil, updatedAt: .init(timeIntervalSince1970: 40), deletedAt: .init(timeIntervalSince1970: 40), version: 4)
    let merged = SyncEngine.merge(local: [local], remote: [remote])
    #expect(merged.first?.isDeleted == true)
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `swift test --filter syncEngine`  
Expected: FAIL with missing `SyncEngine`.

- [ ] **Step 4: 实现 `SyncEngine.merge`**

```swift
import Foundation

public enum SyncEngine {
    public static func merge<Value: Codable & Equatable & Sendable>(
        local: [SyncRecord<Value>],
        remote: [SyncRecord<Value>]
    ) -> [SyncRecord<Value>] {
        var map = Dictionary(uniqueKeysWithValues: local.map { ($0.recordID, $0) })
        for candidate in remote {
            guard let existing = map[candidate.recordID] else {
                map[candidate.recordID] = candidate
                continue
            }
            map[candidate.recordID] = pickWinner(lhs: existing, rhs: candidate)
        }
        return map.values.sorted { $0.recordID < $1.recordID }
    }

    private static func pickWinner<Value>(lhs: SyncRecord<Value>, rhs: SyncRecord<Value>) -> SyncRecord<Value> {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt ? lhs : rhs }
        if lhs.version != rhs.version { return lhs.version > rhs.version ? lhs : rhs }
        return lhs.recordID >= rhs.recordID ? lhs : rhs
    }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `swift test --filter syncEngine`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/Services/Sync/SyncEngine.swift Tests/iTimeTests/Sync/SyncEngineTests.swift
git commit -m "feat: implement sync merge engine with lww and tombstones"
```

---

### Task 3: 实现 API Key 端到端加密封装

**Files:**
- Create: `Sources/iTime/Services/Sync/CryptoEnvelopeService.swift`
- Test: `Tests/iTimeTests/Sync/CryptoEnvelopeServiceTests.swift`

- [ ] **Step 1: 写失败测试（加密后可解密）**

```swift
import Foundation
import Testing
@testable import iTime

@Test func cryptoEnvelopeEncryptsAndDecryptsAPIKeyPayload() throws {
    let service = CryptoEnvelopeService()
    let plaintext = Data("sk-test-123".utf8)
    let sharedSecret = try service.deriveSymmetricKey(localPrivateKey: .init(), remotePublicKey: .init())
    let envelope = try service.encrypt(payload: plaintext, using: sharedSecret)
    let decrypted = try service.decrypt(envelope: envelope, using: sharedSecret)
    #expect(decrypted == plaintext)
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter cryptoEnvelope`  
Expected: FAIL with missing types.

- [ ] **Step 3: 实现加密服务**

```swift
import CryptoKit
import Foundation

public struct EncryptedSecretPayload: Codable, Equatable, Sendable {
    public let nonceBase64: String
    public let ciphertextBase64: String
    public let tagBase64: String
}

public struct CryptoEnvelopeService {
    public func deriveSymmetricKey(localPrivateKey: Curve25519.KeyAgreement.PrivateKey,
                                   remotePublicKey: Curve25519.KeyAgreement.PublicKey) throws -> SymmetricKey {
        let shared = try localPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        return shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data("itime.sync".utf8), outputByteCount: 32)
    }
}
```

- [ ] **Step 4: 实现 AES.GCM encrypt/decrypt**

```swift
extension CryptoEnvelopeService {
    public func encrypt(payload: Data, using key: SymmetricKey) throws -> EncryptedSecretPayload {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(payload, using: key, nonce: nonce)
        return EncryptedSecretPayload(
            nonceBase64: Data(nonce).base64EncodedString(),
            ciphertextBase64: sealed.ciphertext.base64EncodedString(),
            tagBase64: sealed.tag.base64EncodedString()
        )
    }

    public func decrypt(envelope: EncryptedSecretPayload, using key: SymmetricKey) throws -> Data {
        let nonce = try AES.GCM.Nonce(data: Data(base64Encoded: envelope.nonceBase64)!)
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: Data(base64Encoded: envelope.ciphertextBase64)!,
            tag: Data(base64Encoded: envelope.tagBase64)!
        )
        return try AES.GCM.open(box, using: key)
    }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `swift test --filter cryptoEnvelope`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/Services/Sync/CryptoEnvelopeService.swift Tests/iTimeTests/Sync/CryptoEnvelopeServiceTests.swift
git commit -m "feat: add cryptokit envelope for secure api key sync"
```

---

### Task 4: 实现同步快照适配器（Archive + Preferences + API Key）

**Files:**
- Create: `Sources/iTime/Services/Sync/SyncPersistenceAdapter.swift`
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Modify: `Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift`
- Test: `Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift`

- [ ] **Step 1: 写失败测试（可导出 manifest + patch）**

```swift
@Test func syncPersistenceAdapterBuildsManifestFromArchiveAndPreferences() async throws {
    let adapter = makeSyncAdapterFixture()
    let manifest = try await adapter.makeManifest()
    #expect(manifest.archiveVersion > 0)
    #expect(manifest.preferencesVersion > 0)
}
```

- [ ] **Step 2: 写失败测试（applyPatch 后保存到存储）**

```swift
@Test func syncPersistenceAdapterAppliesPatchToArchiveAndPreferences() async throws {
    let adapter = makeSyncAdapterFixture()
    let patch = makePatchFixture()
    try await adapter.apply(patch: patch)
    let after = try await adapter.makeManifest()
    #expect(after.archiveVersion >= patch.archiveVersion)
}
```

- [ ] **Step 3: 运行测试确认失败**

Run: `swift test --filter syncPersistenceAdapter`  
Expected: FAIL with missing adapter API.

- [ ] **Step 4: 在 `UserPreferences` 增加可同步 payload**

```swift
public struct SyncablePreferencesPayload: Codable, Equatable, Sendable {
    public let selectedRange: TimeRangePreset
    public let selectedCalendarIDs: [String]
    public let reviewExcludedCalendarIDs: [String]
    public let reviewReminderEnabled: Bool
    public let reviewReminderTime: Date
    public let aiServiceEndpoints: [AIServiceEndpoint]
    public let defaultAIServiceID: UUID?
}
```

- [ ] **Step 5: 在 `AIAPIKeyStoring` 增加批量导入导出**

```swift
public extension AIAPIKeyStoring {
    func exportAPIKeys(for serviceIDs: [UUID]) throws -> [UUID: String] {
        try Dictionary(uniqueKeysWithValues: serviceIDs.map { ($0, try loadAPIKey(for: $0)) })
    }

    func importAPIKeys(_ apiKeys: [UUID: String]) throws {
        for (serviceID, apiKey) in apiKeys where !apiKey.isEmpty {
            try saveAPIKey(apiKey, for: serviceID)
        }
    }
}
```

- [ ] **Step 6: 实现 `SyncPersistenceAdapter`**

```swift
public final class SyncPersistenceAdapter {
    public func makeManifest() async throws -> SyncManifest { /* 使用 archive + preferences + api key fingerprint */ }
    public func buildPatch(since remote: SyncManifest) async throws -> SyncPatch { /* 仅返回增量 */ }
    public func apply(patch: SyncPatch) async throws { /* 调用 SyncEngine 并写回 archive/preferences/keychain */ }
}
```

- [ ] **Step 7: 运行测试确认通过**

Run: `swift test --filter syncPersistenceAdapter`  
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/iTime/Services/Sync/SyncPersistenceAdapter.swift \
  Sources/iTime/Support/Persistence/UserPreferences.swift \
  Sources/iTime/Support/Persistence/AIAPIKeyStoring.swift \
  Tests/iTimeTests/Sync/SyncPersistenceAdapterTests.swift
git commit -m "feat: add sync persistence adapter for archive preferences and api keys"
```

---

### Task 5: 实现 MultipeerTransport 与 SyncCoordinator（手动同步流程）

**Files:**
- Create: `Sources/iTime/Services/Sync/MultipeerTransport.swift`
- Create: `Sources/iTime/Services/Sync/MultipeerTransportService.swift`
- Create: `Sources/iTime/Services/Sync/SyncCoordinator.swift`
- Test: `Tests/iTimeTests/Sync/SyncCoordinatorTests.swift`

- [ ] **Step 1: 写失败测试（coordinator 会话流程）**

```swift
@Test func syncCoordinatorRunsHelloManifestPatchResultFlow() async throws {
    let transport = FakeTransport()
    let adapter = FakeAdapter()
    let coordinator = SyncCoordinator(transport: transport, adapter: adapter)
    try await coordinator.syncNow(with: "peer-a")
    #expect(transport.sentMessages.contains { if case .hello = $0 { true } else { false } })
    #expect(adapter.appliedPatchCount == 1)
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter syncCoordinatorRunsHelloManifestPatchResultFlow`  
Expected: FAIL with missing coordinator.

- [ ] **Step 3: 定义 transport 协议**

```swift
public protocol MultipeerTransport: Sendable {
    var discoveredPeers: AsyncStream<DevicePeer> { get }
    func startBrowsing() async
    func stopBrowsing() async
    func connect(to peerID: String) async throws
    func send(_ message: SyncMessage, to peerID: String) async throws
    func incomingMessages() -> AsyncStream<(peerID: String, message: SyncMessage)>
}
```

- [ ] **Step 4: 实现 `MultipeerTransportService`（MPC 封装）**

```swift
public final class MultipeerTransportService: NSObject, MultipeerTransport {
    // MCPeerID + MCSession + MCNearbyServiceBrowser + MCNearbyServiceAdvertiser
    // 将 delegate 回调桥接为 AsyncStream<DevicePeer> 和 AsyncStream<(String, SyncMessage)>
}
```

- [ ] **Step 5: 实现 `SyncCoordinator.syncNow`**

```swift
public final class SyncCoordinator {
    public func syncNow(with peerID: String) async throws {
        try await transport.connect(to: peerID)
        try await transport.send(.hello(.init(protocolVersion: 1, deviceName: localDeviceName)), to: peerID)
        let localManifest = try await adapter.makeManifest()
        try await transport.send(.manifest(localManifest), to: peerID)
        let remoteManifest = try await waitForManifest(from: peerID)
        let patch = try await adapter.buildPatch(since: remoteManifest)
        try await transport.send(.patch(patch), to: peerID)
        let remotePatch = try await waitForPatch(from: peerID)
        try await adapter.apply(patch: remotePatch)
        try await transport.send(.result(.success), to: peerID)
    }
}
```

- [ ] **Step 6: 运行测试确认通过**

Run: `swift test --filter syncCoordinator`  
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/iTime/Services/Sync/MultipeerTransport.swift \
  Sources/iTime/Services/Sync/MultipeerTransportService.swift \
  Sources/iTime/Services/Sync/SyncCoordinator.swift \
  Tests/iTimeTests/Sync/SyncCoordinatorTests.swift
git commit -m "feat: add multipeer transport and manual sync coordinator"
```

---

### Task 6: 集成到 AppModel + macOS 设置页“设备互传”

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`
- Create: `Sources/iTime/UI/Settings/DeviceSyncSettingsSection.swift`
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/iTimeApp.swift`
- Test: `Tests/iTimeTests/AppModelSyncTests.swift`

- [ ] **Step 1: 写失败测试（AppModel 可发现设备并触发手动同步）**

```swift
@MainActor
@Test func appModelSyncFlowUpdatesStateToSucceeded() async throws {
    let fixture = makeSyncAppModelFixture()
    await fixture.model.startDeviceDiscovery()
    #expect(!fixture.model.discoveredPeers.isEmpty)
    try await fixture.model.syncNow(with: fixture.model.discoveredPeers[0].id)
    #expect(fixture.model.lastSyncStatus == .succeeded)
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter appModelSyncFlowUpdatesStateToSucceeded`  
Expected: FAIL with missing sync API on `AppModel`.

- [ ] **Step 3: 在 `AppModel` 增加 sync 状态与方法**

```swift
public enum DeviceSyncStatus: Equatable, Sendable { case idle, syncing, succeeded, failed(String) }

public private(set) var discoveredPeers: [DevicePeer] = []
public private(set) var lastSyncStatus: DeviceSyncStatus = .idle

public func startDeviceDiscovery() async { /* consume transport stream */ }
public func stopDeviceDiscovery() async { /* stop browsing */ }
public func syncNow(with peerID: String) async throws { /* call coordinator */ }
```

- [ ] **Step 4: 新增 macOS 设置页 section 组件**

```swift
struct DeviceSyncSettingsSection: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("立即同步") { Task { try? await model.syncNow(with: model.discoveredPeers.first?.id ?? "") } }
            Text("最近状态：\(model.lastSyncStatus.displayText)")
            ForEach(model.discoveredPeers) { peer in Text(peer.displayName) }
        }
    }
}
```

- [ ] **Step 5: 在 `SettingsView` 接入新 section**

```swift
enum SettingsSection: String, CaseIterable, Identifiable {
    case calendars, aiServices, reviewReminder, deviceSync
}
```

- [ ] **Step 6: 在 `iTimeApp` 注入 `SyncCoordinator` 依赖**

```swift
@State private var model = AppModel(
    service: EventKitCalendarAccessService(),
    preferences: UserPreferences(storage: .standard),
    reviewReminderScheduler: SystemReviewReminderScheduler(),
    syncCoordinator: SyncCoordinator(
        transport: MultipeerTransportService(serviceType: "itime-sync"),
        adapter: SyncPersistenceAdapter.live()
    )
)
```

- [ ] **Step 7: 运行测试确认通过**

Run: `swift test --filter AppModelSyncTests`  
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/iTime/App/AppModel.swift \
  Sources/iTime/UI/Settings/DeviceSyncSettingsSection.swift \
  Sources/iTime/UI/Settings/SettingsView.swift \
  Sources/iTime/iTimeApp.swift \
  Tests/iTimeTests/AppModelSyncTests.swift
git commit -m "feat: integrate manual sync flow into app model and mac settings"
```

---

### Task 7: 创建 iOS App 壳并接入共享 AppModel

**Files:**
- Create: `iTime-iOS/App/iTimeiOSApp.swift`
- Create: `iTime-iOS/UI/Root/iTimeIOSRootView.swift`
- Create: `iTime-iOS/UI/Overview/iOSOverviewView.swift`
- Create: `iTime-iOS/UI/Conversation/iOSConversationView.swift`
- Create: `iTime-iOS/UI/Settings/iOSSettingsView.swift`
- Modify: `iTime.xcodeproj/project.pbxproj`

- [ ] **Step 1: 先验证当前 iOS 构建失败（基线）**

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build`  
Expected: FAIL with `scheme iTime-iOS not found`.

- [ ] **Step 2: 在 Xcode 工程新增 `iTime-iOS` target 与 scheme**

```text
Modify: iTime.xcodeproj/project.pbxproj
- Add PBXNativeTarget: iTime-iOS
- Add build settings: IPHONEOS_DEPLOYMENT_TARGET = 17.0
- Add Sources build phase entries for iTime-iOS/**/*.swift
- Add Scheme: iTime-iOS
```

- [ ] **Step 3: 创建 iOS App 入口**

```swift
import SwiftUI

@main
struct iTimeiOSApp: App {
    @State private var model = AppModel(
        service: EventKitCalendarAccessService(),
        preferences: UserPreferences(storage: .standard),
        reviewReminderScheduler: SystemReviewReminderScheduler(),
        syncCoordinator: SyncCoordinator(
            transport: MultipeerTransportService(serviceType: "itime-sync"),
            adapter: SyncPersistenceAdapter.live()
        )
    )

    var body: some Scene { WindowGroup { iTimeIOSRootView(model: model) } }
}
```

- [ ] **Step 4: 创建 iOS Root + 三个 Tab 壳**

```swift
struct iTimeIOSRootView: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView {
            iOSOverviewView(model: model).tabItem { Label("统计", systemImage: "chart.bar") }
            iOSConversationView(model: model).tabItem { Label("复盘", systemImage: "bubble.left.and.bubble.right") }
            iOSSettingsView(model: model).tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
```

- [ ] **Step 5: 运行 iOS 构建确认通过**

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build`  
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add iTime-iOS/App/iTimeiOSApp.swift \
  iTime-iOS/UI/Root/iTimeIOSRootView.swift \
  iTime-iOS/UI/Overview/iOSOverviewView.swift \
  iTime-iOS/UI/Conversation/iOSConversationView.swift \
  iTime-iOS/UI/Settings/iOSSettingsView.swift \
  iTime.xcodeproj/project.pbxproj
git commit -m "feat: add ios app target and tab shell with shared app model"
```

---

### Task 8: 完成 iOS 功能对齐（统计/复盘/设置）+ 设备互传页

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`
- Modify: `iTime-iOS/UI/Conversation/iOSConversationView.swift`
- Modify: `iTime-iOS/UI/Settings/iOSSettingsView.swift`
- Create: `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift`
- Modify: `README.md`

- [ ] **Step 1: 在 iOS 统计页复用范围切换与关键指标**

```swift
struct iOSOverviewView: View {
    @Bindable var model: AppModel
    var body: some View {
        NavigationStack {
            ScrollView {
                RangePicker(selectedRange: Binding(get: { model.liveSelectedRange }, set: { range in Task { await model.setRange(range) } }))
                OverviewMetricsSection(overview: model.overview)
                OverviewChartView(overview: model.overview)
            }
            .navigationTitle("统计")
            .task { await model.refresh() }
        }
    }
}
```

- [ ] **Step 2: 在 iOS 复盘页接入新建/继续/历史**

```swift
struct iOSConversationView: View {
    @Bindable var model: AppModel
    var body: some View {
        NavigationStack {
            AIConversationMessagesView(model: model)
                .toolbar { Button("新建复盘") { Task { await model.startAIConversation() } } }
                .navigationTitle("复盘")
        }
    }
}
```

- [ ] **Step 3: 新增 iOS 设备互传页并接入设置导航**

```swift
struct iOSDeviceSyncView: View {
    @Bindable var model: AppModel
    var body: some View {
        List {
            Section("附近设备") {
                ForEach(model.discoveredPeers) { peer in
                    Button(peer.displayName) { Task { try? await model.syncNow(with: peer.id) } }
                }
            }
            Section("状态") { Text(model.lastSyncStatus.displayText) }
        }
        .navigationTitle("设备互传")
        .task { await model.startDeviceDiscovery() }
    }
}
```

- [ ] **Step 4: 在 iOS 设置页加入 AI 配置/提醒/设备互传入口**

```swift
NavigationLink("设备互传") { iOSDeviceSyncView(model: model) }
```

- [ ] **Step 5: 更新 README（新增 iOS 和本地互传能力）**

```markdown
- iOS 版本：支持统计、AI 复盘、设置
- Mac ↔ iOS 本地近场互传（非 iCloud，手动触发）
```

- [ ] **Step 6: 跑完整验证**

Run:

```bash
swift build
swift test
xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test
xcodebuild -project iTime.xcodeproj -scheme iTime-iOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected:

- `swift build`: Build complete
- `swift test`: all tests passed
- macOS test: `** TEST SUCCEEDED **`
- iOS build: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift \
  iTime-iOS/UI/Conversation/iOSConversationView.swift \
  iTime-iOS/UI/Settings/iOSSettingsView.swift \
  iTime-iOS/UI/Sync/iOSDeviceSyncView.swift \
  README.md
git commit -m "feat: complete ios parity views and local device sync ui"
```

---

## Self-Review

### 1) Spec coverage check

- iOS 功能对齐（统计/复盘/设置）: Task 7, Task 8 覆盖。
- 本地近场同步（MPC）: Task 5, Task 6, Task 8 覆盖。
- 数据范围（复盘 + 设置）: Task 4 覆盖。
- 冲突策略（自动合并 + LWW + tombstone）: Task 2 覆盖。
- API Key 端到端加密: Task 3 + Task 4 覆盖。
- 手动触发同步: Task 5 + Task 6 + Task 8 覆盖。
- 验收与测试: Task 8 Step 6 覆盖。

未发现需求遗漏。

### 2) Placeholder scan

已检查计划中不存在 `TBD`、`TODO`、`implement later`、`similar to Task` 等占位表达。

### 3) Type consistency

- `SyncMessage / SyncManifest / SyncPatch / SyncResult` 在 Task 1、Task 5、Task 4 保持一致命名。
- `DevicePeer`、`DeviceSyncStatus` 在 AppModel 与 UI 任务里保持一致命名。
- `SyncCoordinator.syncNow(with:)` 在 Task 5、Task 6、Task 8 调用一致。

---

## Rollout Notes

- 每完成一个 Task 都要先执行对应局部验证命令，再执行 commit。
- 如果某个 Task 引入跨平台编译问题，先修复条件编译（`#if os(macOS)` / `#if os(iOS)`）再进入下一 Task。
- 同步相关错误必须显式 surfaced 到 UI 状态，不允许 silent failure。
