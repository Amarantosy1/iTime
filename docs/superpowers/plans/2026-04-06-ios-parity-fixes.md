# iOS Parity Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four iOS defects: bidirectional device sync (protocol + permissions), statistics charts parity with Mac, AI service enable/disable in settings, and app icon.

**Architecture:** All Mac stat components (Charts-based) are already compiled into the iOS target — they just aren't used yet. Sync needs a new `startResponding()` loop in `SyncCoordinator` that mirrors the initiator's state machine. iOS permissions go into a new `ExtraInfo.plist` merged via `INFOPLIST_ADDITIONAL_FILE`. No new files beyond the plist and the test additions.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing (`@Test` / `#expect`), MultipeerConnectivity, Charts

---

## File Map

| File | Change |
|------|--------|
| `iTime-iOS/ExtraInfo.plist` | **Create** — NSLocalNetworkUsageDescription + NSBonjourServices |
| `iTime.xcodeproj/project.pbxproj` | Add `INFOPLIST_ADDITIONAL_FILE` to iOS Debug + Release build configs |
| `Sources/iTime/Services/Sync/SyncCoordinator.swift` | Add `SyncResponderEvent` enum + `startResponding()` method |
| `Tests/iTimeTests/Sync/SyncCoordinatorTests.swift` | Add responder flow test |
| `Sources/iTime/App/AppModel.swift` | Add `respondingTask` property; update `startDeviceDiscovery` and `stopDeviceDiscovery` |
| `Tests/iTimeTests/AppModelSyncTests.swift` | Add responder integration test |
| `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift` | Replace "刷新设备" with start/stop discovery buttons |
| `iTime-iOS/UI/Overview/iOSOverviewView.swift` | Replace plain list with RangePicker + Charts components |
| `iTime-iOS/UI/Settings/iOSSettingsView.swift` | Replace Picker with per-service Toggle + SecureField list |
| `iTime-iOS/Assets.xcassets/AppIcon.appiconset/logo.png` | **Create** — copy from `logo.png` at repo root |
| `iTime-iOS/Assets.xcassets/AppIcon.appiconset/Contents.json` | Rewrite to single-image Xcode 14+ format |

---

## Task 1: iOS Network Permissions

**Files:**
- Create: `iTime-iOS/ExtraInfo.plist`
- Modify: `iTime.xcodeproj/project.pbxproj`

### Why this is required
iOS 14+ requires `NSLocalNetworkUsageDescription` for the privacy prompt and `NSBonjourServices` to declare which Bonjour service types the app uses. Without these, `MCNearbyServiceBrowser` and `MCNearbyServiceAdvertiser` are silently blocked. `NSBonjourServices` must be an array — it cannot be expressed via the `INFOPLIST_KEY_*` build setting string format, so we use `INFOPLIST_ADDITIONAL_FILE` to merge a hand-written plist.

- [ ] **Step 1: Create the extra plist**

Create `iTime-iOS/ExtraInfo.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>iTime 需要访问局域网以发现附近设备并同步数据。</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_itime-sync._tcp</string>
        <string>_itime-sync._udp</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Add INFOPLIST_ADDITIONAL_FILE to the iOS Debug build config in project.pbxproj**

In `iTime.xcodeproj/project.pbxproj`, there are two iOS build configuration blocks (Debug and Release). Both contain this line:
```
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```
Find the **first** occurrence (Debug) and add the new key **before** `IPHONEOS_DEPLOYMENT_TARGET`:
```
				INFOPLIST_ADDITIONAL_FILE = "iTime-iOS/ExtraInfo.plist";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

- [ ] **Step 3: Add to the iOS Release build config**

Find the **second** occurrence of `IPHONEOS_DEPLOYMENT_TARGET = 17.0;` and apply the same addition:
```
				INFOPLIST_ADDITIONAL_FILE = "iTime-iOS/ExtraInfo.plist";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
```

- [ ] **Step 4: Verify build succeeds**

Open the project in Xcode, select the `iTime-iOS` scheme, build for a simulator. The build should succeed with no errors.

- [ ] **Step 5: Commit**

```bash
git add iTime-iOS/ExtraInfo.plist iTime.xcodeproj/project.pbxproj
git commit -m "fix: add iOS network permissions for MultipeerConnectivity"
```

---

## Task 2: SyncCoordinator Responder — Test

**Files:**
- Modify: `Tests/iTimeTests/Sync/SyncCoordinatorTests.swift`

The `FakeTransport` in this file already has `pushIncoming(peerID:message:)`. Write the responder test before writing the implementation.

- [ ] **Step 1: Add the failing test at the bottom of SyncCoordinatorTests.swift**

```swift
@Test func syncCoordinatorResponderHandlesFullFlow() async throws {
    let archiveStore = CoordinatorInMemoryArchiveStore(archive: AIConversationArchive(
        sessions: [], summaries: [], memorySnapshots: [], longFormReports: []
    ))
    let preferences = UserPreferences(storage: .inMemory)
    let keyStore = CoordinatorInMemoryKeyStore(values: [:])
    let adapter = SyncPersistenceAdapter(
        archiveStore: archiveStore, preferences: preferences, apiKeyStore: keyStore
    )
    let transport = FakeTransport()
    let coordinator = SyncCoordinator(
        transport: transport, adapter: adapter,
        localDeviceName: "Responder", timeoutNanoseconds: 2_000_000_000
    )

    var completedPeerIDs: [String] = []
    var failedPeerIDs: [String] = []

    let respondingTask = Task {
        await coordinator.startResponding { event in
            switch event {
            case .completed(let peerID): completedPeerIDs.append(peerID)
            case .failed(let peerID, _): failedPeerIDs.append(peerID)
            }
        }
    }
    try await Task.sleep(nanoseconds: 50_000_000)

    // Simulate initiator sending: hello → manifest → patch
    transport.pushIncoming(peerID: "initiator",
        message: .hello(SyncHello(protocolVersion: 1, deviceName: "Initiator")))
    try await Task.sleep(nanoseconds: 50_000_000)

    transport.pushIncoming(peerID: "initiator",
        message: .manifest(SyncManifest(
            archiveVersion: 0, preferencesVersion: 0,
            apiKeyFingerprintByServiceID: [:],
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )))
    try await Task.sleep(nanoseconds: 50_000_000)

    transport.pushIncoming(peerID: "initiator",
        message: .patch(SyncPatch(
            archiveVersion: 0, preferencesVersion: 0,
            archivePayload: nil, preferencesPayload: nil,
            encryptedAPIKeysByServiceID: [:]
        )))
    try await Task.sleep(nanoseconds: 100_000_000)

    respondingTask.cancel()

    // Responder must have sent: hello back, its manifest, and its patch
    #expect(transport.sentMessages.contains(where: { if case .hello = $0 { return true }; return false }))
    #expect(transport.sentMessages.contains(where: { if case .manifest = $0 { return true }; return false }))
    #expect(transport.sentMessages.contains(where: { if case .patch = $0 { return true }; return false }))
    #expect(completedPeerIDs == ["initiator"])
    #expect(failedPeerIDs.isEmpty)
}
```

- [ ] **Step 2: Run the test to confirm it fails (method not yet defined)**

```bash
swift test --filter iTimeTests.syncCoordinatorResponderHandlesFullFlow 2>&1 | tail -10
```
Expected: compile error — `value of type 'SyncCoordinator' has no member 'startResponding'`

---

## Task 3: SyncCoordinator Responder — Implementation

**Files:**
- Modify: `Sources/iTime/Services/Sync/SyncCoordinator.swift`

- [ ] **Step 1: Add SyncResponderEvent enum and startResponding() to SyncCoordinator.swift**

Add the following **after** the closing brace of `waitForMessage` and **before** the final `}` closing `SyncCoordinator`:

```swift
public enum SyncResponderEvent: Sendable {
    case completed(peerID: String)
    case failed(peerID: String, error: Error)
}

/// Runs until cancelled. Listens for incoming sync initiations and
/// plays the responder role: replies with hello + manifest, then patch.
public func startResponding(
    onEvent: @Sendable @escaping (SyncResponderEvent) async -> Void = { _ in }
) async {
    enum PeerState {
        case awaitingManifest   // sent our manifest, waiting for initiator's manifest
        case sentPatch          // sent our patch, waiting for initiator's patch
    }
    var peerStates: [String: PeerState] = [:]

    for await (peerID, message) in transport.incomingMessages() {
        let state = peerStates[peerID]
        switch (state, message) {

        case (.none, .hello):
            // Initiator announced itself — reply with hello then our manifest
            do {
                try await transport.send(
                    .hello(SyncHello(protocolVersion: 1, deviceName: localDeviceName)),
                    to: peerID
                )
                let manifest = try await adapter.makeManifest()
                try await transport.send(.manifest(manifest), to: peerID)
                peerStates[peerID] = .awaitingManifest
            } catch {
                peerStates[peerID] = nil
                await onEvent(.failed(peerID: peerID, error: error))
            }

        case (.awaitingManifest, .manifest(let initiatorManifest)):
            // Initiator sent its manifest — build and send our patch
            do {
                let patch = try await adapter.buildPatch(since: initiatorManifest)
                try await transport.send(.patch(patch), to: peerID)
                peerStates[peerID] = .sentPatch
            } catch {
                peerStates[peerID] = nil
                await onEvent(.failed(peerID: peerID, error: error))
            }

        case (.sentPatch, .patch(let initiatorPatch)):
            // Initiator sent its patch — apply and finish
            do {
                try await adapter.apply(patch: initiatorPatch)
                peerStates[peerID] = nil
                await onEvent(.completed(peerID: peerID))
            } catch {
                peerStates[peerID] = nil
                await onEvent(.failed(peerID: peerID, error: error))
            }

        case (_, .result):
            // Initiator finished — clean up state
            peerStates[peerID] = nil

        default:
            break
        }
    }
}
```

- [ ] **Step 2: Run the test to confirm it passes**

```bash
swift test --filter iTimeTests.syncCoordinatorResponderHandlesFullFlow 2>&1 | tail -5
```
Expected: `Test run with 1 test passed.`

- [ ] **Step 3: Run the full test suite to confirm no regressions**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/iTime/Services/Sync/SyncCoordinator.swift \
        Tests/iTimeTests/Sync/SyncCoordinatorTests.swift
git commit -m "feat: add SyncCoordinator responder loop for bidirectional sync"
```

---

## Task 4: AppModel Responder Integration — Test

**Files:**
- Modify: `Tests/iTimeTests/AppModelSyncTests.swift`

- [ ] **Step 1: Add the failing test at the bottom of AppModelSyncTests.swift**

```swift
@MainActor
@Test func appModelStartDiscoveryAlsoStartsResponder() async throws {
    let fixture = makeSyncModelFixture()
    let model = fixture.model
    let transport = fixture.transport

    // Start discovery — this should also start the responder loop
    await model.startDeviceDiscovery()
    try await Task.sleep(nanoseconds: 50_000_000)

    // Simulate an initiator performing a full sync against us
    transport.pushIncoming(
        (peerID: "remote-initiator",
         message: .hello(SyncHello(protocolVersion: 1, deviceName: "Remote"))))
    try await Task.sleep(nanoseconds: 50_000_000)

    transport.pushIncoming(
        (peerID: "remote-initiator",
         message: .manifest(SyncManifest(
            archiveVersion: 0, preferencesVersion: 0,
            apiKeyFingerprintByServiceID: [:],
            generatedAt: Date()
         ))))
    try await Task.sleep(nanoseconds: 50_000_000)

    transport.pushIncoming(
        (peerID: "remote-initiator",
         message: .patch(SyncPatch(
            archiveVersion: 0, preferencesVersion: 0,
            archivePayload: nil, preferencesPayload: nil,
            encryptedAPIKeysByServiceID: [:]
         ))))
    try await Task.sleep(nanoseconds: 150_000_000)

    #expect(model.lastSyncStatus == .succeeded)
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
swift test --filter iTimeTests.appModelStartDiscoveryAlsoStartsResponder 2>&1 | tail -10
```
Expected: test runs but `lastSyncStatus` remains `.idle`, assertion fails.

---

## Task 5: AppModel Responder Integration — Implementation

**Files:**
- Modify: `Sources/iTime/App/AppModel.swift`

- [ ] **Step 1: Add the respondingTask stored property**

Find this existing line (near the other private Task properties, around line 46):
```swift
    private var discoveryTask: Task<Void, Never>?
```
Add directly below it:
```swift
    private var respondingTask: Task<Void, Never>?
```

- [ ] **Step 2: Update startDeviceDiscovery() to also start the responder**

Find the full `startDeviceDiscovery()` method body:
```swift
    public func startDeviceDiscovery() async {
        guard let syncCoordinator else { return }
        await syncCoordinator.startDiscovery()
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            for await peer in syncCoordinator.discoveredPeers() {
                await MainActor.run {
                    var merged = self.discoveredPeers.filter { $0.id != peer.id }
                    merged.append(peer)
                    merged.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                    self.discoveredPeers = merged
                }
            }
        }
    }
```
Replace it entirely with:
```swift
    public func startDeviceDiscovery() async {
        guard let syncCoordinator else { return }
        await syncCoordinator.startDiscovery()
        discoveryTask?.cancel()
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            for await peer in syncCoordinator.discoveredPeers() {
                await MainActor.run {
                    var merged = self.discoveredPeers.filter { $0.id != peer.id }
                    merged.append(peer)
                    merged.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                    self.discoveredPeers = merged
                }
            }
        }
        respondingTask?.cancel()
        respondingTask = Task { [weak self] in
            guard let self else { return }
            await syncCoordinator.startResponding { [weak self] event in
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    switch event {
                    case .completed:
                        self.lastSyncStatus = .succeeded
                        self.availableAIServices = self.preferences.aiServiceEndpoints
                    case .failed(_, let error):
                        self.lastSyncStatus = .failed("同步失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }
```

- [ ] **Step 3: Cancel respondingTask in stopDeviceDiscovery()**

Find:
```swift
    public func stopDeviceDiscovery() async {
        discoveryTask?.cancel()
        discoveryTask = nil
        guard let syncCoordinator else { return }
        await syncCoordinator.stopDiscovery()
    }
```
Replace with:
```swift
    public func stopDeviceDiscovery() async {
        discoveryTask?.cancel()
        discoveryTask = nil
        respondingTask?.cancel()
        respondingTask = nil
        guard let syncCoordinator else { return }
        await syncCoordinator.stopDiscovery()
    }
```

- [ ] **Step 4: Run the new test**

```bash
swift test --filter iTimeTests.appModelStartDiscoveryAlsoStartsResponder 2>&1 | tail -5
```
Expected: `Test run with 1 test passed.`

- [ ] **Step 5: Run full test suite**

```bash
swift test 2>&1 | tail -5
```
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/App/AppModel.swift \
        Tests/iTimeTests/AppModelSyncTests.swift
git commit -m "feat: start responder loop on device discovery for bidirectional sync"
```

---

## Task 6: iOS Sync UI Update

**Files:**
- Modify: `iTime-iOS/UI/Sync/iOSDeviceSyncView.swift`

Replace the single "刷新设备" button with the same start/stop discovery pair used on Mac.

- [ ] **Step 1: Rewrite iOSDeviceSyncView.swift**

```swift
import SwiftUI

struct iOSDeviceSyncView: View {
    @Bindable var model: AppModel

    var body: some View {
        Section("设备互传") {
            HStack(spacing: 12) {
                Button("开始发现设备") {
                    Task { await model.startDeviceDiscovery() }
                }
                .buttonStyle(.bordered)

                Button("停止发现") {
                    Task { await model.stopDeviceDiscovery() }
                }
                .buttonStyle(.bordered)
            }

            if model.discoveredPeers.isEmpty {
                Text("暂未发现可连接设备")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.discoveredPeers) { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(peer.displayName)
                            Spacer()
                            Button("立即同步") {
                                Task { try? await model.syncNow(with: peer.id) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isSyncing)
                        }
                        Text(peer.state.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Text(model.lastSyncStatus.displayText)
                .font(.footnote)
                .foregroundStyle(model.lastSyncStatus.isFailure ? .red : .secondary)
        }
    }

    private var isSyncing: Bool {
        if case .syncing = model.lastSyncStatus { return true }
        return false
    }
}

private extension DevicePeer.ConnectionState {
    var displayText: String {
        switch self {
        case .discovered: return "已发现"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .failed(let message): return "异常 · \(message)"
        }
    }
}

private extension AppModel.DeviceSyncStatus {
    var displayText: String {
        switch self {
        case .idle: return "空闲"
        case .syncing: return "同步中"
        case .succeeded: return "同步成功"
        case .failed(let message): return "同步失败 · \(message)"
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
```

- [ ] **Step 2: Build the iOS target in Xcode to confirm no errors**

Select scheme `iTime-iOS`, build for any simulator.

- [ ] **Step 3: Commit**

```bash
git add iTime-iOS/UI/Sync/iOSDeviceSyncView.swift
git commit -m "fix: replace iOS sync UI with start/stop discovery buttons"
```

---

## Task 7: iOS Statistics Charts

**Files:**
- Modify: `iTime-iOS/UI/Overview/iOSOverviewView.swift`

All needed components (`RangePicker`, `OverviewMetricsSection`, `OverviewTrendChartView`, `OverviewChartView`, `LiquidGlassCard`, `AuthorizationStateView`) are already compiled into the iOS target. No imports to change.

- [ ] **Step 1: Rewrite iOSOverviewView.swift**

```swift
import SwiftUI

struct iOSOverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RangePicker(
                        selection: Binding(
                            get: { model.preferences.selectedRange },
                            set: { newValue in Task { await model.setRange(newValue) } }
                        ),
                        ranges: TimeRangePreset.overviewCases
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                    if model.authorizationState == .authorized {
                        overviewContent
                    } else {
                        AuthorizationStateView(state: model.authorizationState) {
                            Task { await model.requestAccessIfNeeded() }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("统计")
            .task { await model.refresh() }
            .refreshable { await model.refresh() }
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = model.overview, !overview.buckets.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                OverviewMetricsSection(overview: overview)

                OverviewTrendChartView(overview: overview)

                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("分类分布")
                            .font(.headline)
                        OverviewChartView(overview: overview)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            LiquidGlassCard {
                Text("当前时间范围内没有可统计的日程。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
```

- [ ] **Step 2: Build the iOS target**

Select scheme `iTime-iOS`, build for any simulator. Confirm no errors.

- [ ] **Step 3: Commit**

```bash
git add iTime-iOS/UI/Overview/iOSOverviewView.swift
git commit -m "feat: add full statistics charts to iOS overview (parity with Mac)"
```

---

## Task 8: iOS AI Service Settings

**Files:**
- Modify: `iTime-iOS/UI/Settings/iOSSettingsView.swift`

Replace the Picker-only AI section with a per-service Toggle + SecureField list. This lets users enable/disable built-in providers and enter API keys, without navigating away.

- [ ] **Step 1: Rewrite iOSSettingsView.swift**

```swift
import SwiftUI

struct iOSSettingsView: View {
    @Bindable var model: AppModel
    @State private var apiKeys: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section("AI 服务") {
                    ForEach(model.availableAIServices) { service in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(service.displayName, isOn: Binding(
                                get: { service.isEnabled },
                                set: { enabled in
                                    model.updateAIService(service.updating(isEnabled: enabled))
                                }
                            ))
                            if service.isEnabled {
                                SecureField("API Key", text: Binding(
                                    get: { apiKeys[service.id] ?? "" },
                                    set: { newValue in
                                        apiKeys[service.id] = newValue
                                        model.updateAIAPIKey(newValue, for: service.id)
                                    }
                                ))
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                iOSDeviceSyncView(model: model)
            }
            .navigationTitle("设置")
            .onAppear { loadAPIKeys() }
            .onChange(of: model.availableAIServices.map(\.id)) { _, _ in loadAPIKeys() }
        }
    }

    private func loadAPIKeys() {
        for service in model.availableAIServices {
            apiKeys[service.id] = model.loadAIAPIKey(for: service.id)
        }
    }
}
```

- [ ] **Step 2: Build the iOS target**

Select scheme `iTime-iOS`, build for any simulator. Confirm no errors.

- [ ] **Step 3: Commit**

```bash
git add iTime-iOS/UI/Settings/iOSSettingsView.swift
git commit -m "feat: add per-service enable toggle and API key input to iOS settings"
```

---

## Task 9: iOS App Icon

**Files:**
- Create: `iTime-iOS/Assets.xcassets/AppIcon.appiconset/logo.png`
- Modify: `iTime-iOS/Assets.xcassets/AppIcon.appiconset/Contents.json`

The project root already has `logo.png` (1024×1024). Xcode 14+ accepts a single 1024×1024 image and generates all required sizes automatically when using the universal platform format.

- [ ] **Step 1: Copy logo.png into the AppIcon asset folder**

```bash
cp /Users/amarantos/Project/iTime/logo.png \
   /Users/amarantos/Project/iTime/iTime-iOS/Assets.xcassets/AppIcon.appiconset/logo.png
```

- [ ] **Step 2: Rewrite Contents.json**

```json
{
  "images" : [
    {
      "filename" : "logo.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Build and verify in Xcode**

Build the `iTime-iOS` scheme. Open the asset catalog in Xcode (`Assets.xcassets` → `AppIcon`) and confirm the icon appears in the 1024×1024 slot.

- [ ] **Step 4: Commit**

```bash
git add iTime-iOS/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add iOS app icon"
```

---

## Self-Review Checklist

- **Spec coverage:**
  - ✅ iOS NSLocalNetworkUsageDescription + NSBonjourServices → Task 1
  - ✅ Mac entitlements: `ENABLE_APP_SANDBOX = NO` — no changes needed (confirmed in project)
  - ✅ SyncCoordinator.startResponding() → Tasks 2–3
  - ✅ AppModel integrates responder → Tasks 4–5
  - ✅ iOS Sync UI → Task 6
  - ✅ iOS statistics charts → Task 7
  - ✅ iOS AI service enable/disable → Task 8
  - ✅ iOS app icon → Task 9

- **Placeholder scan:** No TBDs, no vague "implement this" steps. All code blocks are complete.

- **Type consistency:**
  - `SyncResponderEvent` defined in Task 3, used in Task 3 test and Task 5 AppModel. Consistent.
  - `respondingTask: Task<Void, Never>?` added in Task 5 step 1, cancelled in step 3. Consistent.
  - `model.updateAIService(_:)` and `model.updateAIAPIKey(_:for:)` already exist in AppModel. Confirmed.
  - `model.loadAIAPIKey(for:)` already exists. Confirmed.
  - `model.setRange(_:)`, `model.refresh()`, `model.requestAccessIfNeeded()` all exist in AppModel. Confirmed.
  - `TimeRangePreset.overviewCases` exists. Confirmed.
