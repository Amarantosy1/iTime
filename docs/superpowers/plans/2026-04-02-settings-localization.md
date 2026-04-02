# iTime Settings Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native macOS settings window for calendar selection and translate the current app UI into Chinese without changing main.

**Architecture:** Reuse the existing shared `AppModel` and `UserPreferences` state so the menu bar, overview window, and settings window all operate on the same calendar selection. Keep selection persistence in `UserPreferences`, expose refresh-safe selection mutations through `AppModel`, and move selection UI into a dedicated settings view.

**Tech Stack:** SwiftUI, Observation, EventKit, Swift Testing

---

### Task 1: Lock in presentation strings and selection behavior with tests

**Files:**
- Modify: `Tests/iTimeTests/PresentationTests.swift`
- Modify: `Tests/iTimeTests/AppModelTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func rangeTitlesUseChineseStrings() {
    #expect(TimeRangePreset.today.title == "今天")
    #expect(TimeRangePreset.week.title == "本周")
    #expect(TimeRangePreset.month.title == "本月")
}

@MainActor
@Test func togglingCalendarSelectionUpdatesStoredSelection() async {
    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
            CalendarSource(id: "life", name: "生活", colorHex: "#50E3C2", isSelected: true),
        ],
        events: []
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.refresh()
    await model.toggleCalendarSelection(id: "life")

    #expect(model.availableCalendars.first(where: { $0.id == "life" })?.isSelected == false)
    #expect(Set(preferences.selectedCalendarIDs) == ["work"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter 'PresentationTests|AppModelTests'`
Expected: FAIL because the range titles are still English and selection behavior is not fully asserted yet.

- [ ] **Step 3: Write minimal implementation**

```swift
var title: String {
    switch self {
    case .today: "今天"
    case .week: "本周"
    case .month: "本月"
    }
}
```

```swift
public func toggleCalendarSelection(id: String) async {
    var updated = Set(preferences.selectedCalendarIDs)
    if updated.contains(id) {
        updated.remove(id)
    } else {
        updated.insert(id)
    }
    preferences.replaceSelectedCalendars(with: Array(updated))
    await refresh()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter 'PresentationTests|AppModelTests'`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Tests/iTimeTests/PresentationTests.swift Tests/iTimeTests/AppModelTests.swift Sources/iTime/Domain/TimeRangePreset.swift Sources/iTime/App/AppModel.swift
git commit -m "test: lock in localized range titles and calendar selection"
```

### Task 2: Add a native settings window for calendar selection

**Files:**
- Create: `Sources/iTime/UI/Settings/SettingsView.swift`
- Modify: `Sources/iTime/iTimeApp.swift`
- Modify: `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`
- Test: `Tests/iTimeTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@MainActor
@Test func refreshSelectsAllCalendarsByDefaultWhenNoStoredSelectionExists() async {
    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: false),
            CalendarSource(id: "life", name: "生活", colorHex: "#50E3C2", isSelected: false),
        ],
        events: []
    )
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.refresh()

    #expect(Set(model.availableCalendars.map(\.id)) == ["work", "life"])
    #expect(Set(preferences.selectedCalendarIDs) == ["work", "life"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AppModelTests`
Expected: FAIL if default-selection behavior regresses while wiring settings support.

- [ ] **Step 3: Write minimal implementation**

```swift
Settings {
    SettingsView(model: model)
}
```

```swift
Button("设置") {
    openSettings()
}
```

```swift
ForEach(model.availableCalendars) { calendar in
    Toggle(isOn: Binding(
        get: { calendar.isSelected },
        set: { _ in Task { await model.toggleCalendarSelection(id: calendar.id) } }
    )) {
        Text(calendar.name)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AppModelTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Settings/SettingsView.swift Sources/iTime/iTimeApp.swift Sources/iTime/UI/MenuBar/MenuBarContentView.swift Tests/iTimeTests/AppModelTests.swift
git commit -m "feat: add native settings window for calendar selection"
```

### Task 3: Translate the remaining visible UI copy to Chinese

**Files:**
- Modify: `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewWindowView.swift`
- Modify: `Sources/iTime/UI/Components/AuthorizationStateView.swift`
- Modify: `Sources/iTime/UI/Components/RangePicker.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func rangePickerStillExposesAllThreePresets() {
    #expect(TimeRangePreset.allCases == [.today, .week, .month])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PresentationTests`
Expected: FAIL only if localization work accidentally changes preset ordering or titles.

- [ ] **Step 3: Write minimal implementation**

```swift
Text("已追踪时间")
Text("当前范围内没有日程。")
Button("打开详情") { ... }
Text("我的时间去哪了？")
Text("基于日历事件统计你的时间分布。")
Text("日历权限")
Button("允许访问日历", action: requestAccess)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PresentationTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/MenuBar/MenuBarContentView.swift Sources/iTime/UI/Overview/OverviewWindowView.swift Sources/iTime/UI/Components/AuthorizationStateView.swift Sources/iTime/UI/Components/RangePicker.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: localize visible app copy to Chinese"
```

### Task 4: Final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-04-02-settings-localization-design.md`
- Modify: `docs/superpowers/plans/2026-04-02-settings-localization.md`

- [ ] **Step 1: Run the full test suite**

Run: `swift test`
Expected: PASS with all tests green

- [ ] **Step 2: Verify changed files**

Run: `git status --short`
Expected: only the intended source, test, and docs files are modified or added

- [ ] **Step 3: Summarize outcomes**

```text
- 中文文案已完成
- 原生设置窗口已接入
- 日历选择已移入设置
- 未实现“节假日”自动过滤
```
