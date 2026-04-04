# iTime Settings Notes Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the settings window into a Notes-style left-narrow/right-wide layout that remains readable while freely resizable.

**Architecture:** Keep the native `NavigationSplitView` as the structural shell, move window sizing rules to the `Settings` scene, and introduce shared settings layout constants plus a reusable page/card presentation pattern inside `SettingsView`.

**Tech Stack:** SwiftUI, AppKit, Swift Testing

---

### Task 1: Lock the resizing and layout contract with tests

**Files:**
- Modify: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func settingsLayoutUsesNotesStyleSizingConstraints() {
    #expect(SettingsLayout.defaultWindowWidth == 980)
    #expect(SettingsLayout.defaultWindowHeight == 720)
    #expect(SettingsLayout.minimumWindowWidth == 760)
    #expect(SettingsLayout.minimumWindowHeight == 560)
    #expect(SettingsLayout.sidebarIdealWidth == 192)
    #expect(SettingsLayout.detailContentMaxWidth == 760)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter settingsLayoutUsesNotesStyleSizingConstraints`
Expected: FAIL because `SettingsLayout` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
enum SettingsLayout {
    static let defaultWindowWidth: CGFloat = 980
    static let defaultWindowHeight: CGFloat = 720
    static let minimumWindowWidth: CGFloat = 760
    static let minimumWindowHeight: CGFloat = 560
    static let sidebarIdealWidth: CGFloat = 192
    static let detailContentMaxWidth: CGFloat = 760
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter settingsLayoutUsesNotesStyleSizingConstraints`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tests/iTimeTests/PresentationTests.swift Sources/iTime/UI/Settings/SettingsView.swift
git commit -m "test: lock settings notes layout sizing"
```

### Task 2: Rebuild the settings presentation shell

**Files:**
- Modify: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/iTimeApp.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func settingsSectionsExposeNotesStyleDescriptions() {
    #expect(SettingsSection.calendars.description == "选择参与统计的日历。")
    #expect(SettingsSection.aiServices.description == "管理默认服务、自定义服务与连接凭据。")
    #expect(SettingsSection.reviewReminder.description == "安排每天的复盘提醒与通知权限。")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter settingsSectionsExposeNotesStyleDescriptions`
Expected: FAIL because section descriptions are not defined yet.

- [ ] **Step 3: Write minimal implementation**

```swift
var description: String {
    switch self {
    case .calendars: "选择参与统计的日历。"
    case .aiServices: "管理默认服务、自定义服务与连接凭据。"
    case .reviewReminder: "安排每天的复盘提醒与通知权限。"
    }
}
```

```swift
Settings {
    SettingsView(model: model)
        .frame(minWidth: SettingsLayout.minimumWindowWidth, minHeight: SettingsLayout.minimumWindowHeight)
}
.defaultSize(width: SettingsLayout.defaultWindowWidth, height: SettingsLayout.defaultWindowHeight)
```

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 28) {
        pageHeader
        pageSections
    }
    .frame(maxWidth: SettingsLayout.detailContentMaxWidth, alignment: .leading)
    .frame(maxWidth: .infinity, alignment: .center)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'settingsLayoutUsesNotesStyleSizingConstraints|settingsSectionsExposeNotesStyleDescriptions'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Settings/SettingsView.swift Sources/iTime/iTimeApp.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: redesign settings with notes-style layout shell"
```

### Task 3: Final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-settings-notes-layout-design.md`
- Modify: `docs/superpowers/plans/2026-04-04-settings-notes-layout.md`

- [ ] **Step 1: Run focused presentation tests**

Run: `swift test --filter PresentationTests`
Expected: PASS

- [ ] **Step 2: Run full package tests**

Run: `swift test`
Expected: PASS

- [ ] **Step 3: Run macOS build verification**

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED
