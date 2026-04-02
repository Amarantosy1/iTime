# Overview Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the overview window into a richer statistics dashboard with summary metrics, daily trend data, ranked calendar details, and a custom date-range option.

**Architecture:** Extend the domain model so range selection resolves to a concrete `DateInterval`, then upgrade aggregation to compute dashboard-ready summary metrics and daily series data in one place. Keep the menu bar lightweight while the standalone overview window renders the richer sections using focused SwiftUI subviews.

**Tech Stack:** Swift 6, SwiftUI, Charts, Observation, EventKit, Swift Testing, Xcodebuild

---

## File Map

- Create: `Sources/iTime/Domain/StatisticsDateRange.swift`
- Create: `Sources/iTime/Domain/DailyDurationSummary.swift`
- Create: `Sources/iTime/UI/Overview/OverviewMetricsSection.swift`
- Create: `Sources/iTime/UI/Overview/OverviewTrendChartView.swift`
- Create: `Sources/iTime/UI/Overview/OverviewBucketTable.swift`
- Modify: `Sources/iTime/Domain/TimeRangePreset.swift`
- Modify: `Sources/iTime/Domain/TimeOverview.swift`
- Modify: `Sources/iTime/Services/CalendarAccessServing.swift`
- Modify: `Sources/iTime/Services/EventKitCalendarAccessService.swift`
- Modify: `Sources/iTime/Services/CalendarStatisticsAggregator.swift`
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Modify: `Sources/iTime/UI/Components/RangePicker.swift`
- Modify: `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewChartView.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewWindowView.swift`
- Modify: `Tests/iTimeTests/UserPreferencesTests.swift`
- Modify: `Tests/iTimeTests/PresentationTests.swift`
- Modify: `Tests/iTimeTests/TimeOverviewTests.swift`
- Modify: `Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift`
- Modify: `Tests/iTimeTests/AppModelTests.swift`

## Task 1: Add Custom Range State and Persistence

**Files:**
- Create: `Sources/iTime/Domain/StatisticsDateRange.swift`
- Modify: `Sources/iTime/Domain/TimeRangePreset.swift`
- Modify: `Sources/iTime/Support/Persistence/UserPreferences.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`
- Test: `Tests/iTimeTests/UserPreferencesTests.swift`

- [ ] **Step 1: Write the failing tests for the new range option and persisted custom dates**

```swift
@Test func allRangesAreVisibleInOrder() {
    #expect(TimeRangePreset.allCases == [.today, .week, .month, .custom])
}

@Test func rangeTitlesUseChineseStrings() {
    #expect(TimeRangePreset.custom.title == "自定义")
}

@Test func defaultPreferencesSeedCustomDatesAroundToday() {
    let preferences = UserPreferences(storage: .inMemory)

    #expect(preferences.selectedRange == .today)
    #expect(preferences.customStartDate <= preferences.customEndDate)
}

@Test func customDatesPersistAcrossPreferenceInstances() {
    let suite = "iTime.tests.persisted-custom-range"
    let first = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    first.customStartDate = Date(timeIntervalSince1970: 86_400)
    first.customEndDate = Date(timeIntervalSince1970: 172_800)

    let second = UserPreferences(storage: .inMemory, suiteNameOverride: suite)
    #expect(second.customStartDate == Date(timeIntervalSince1970: 86_400))
    #expect(second.customEndDate == Date(timeIntervalSince1970: 172_800))
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter PresentationTests --filter UserPreferencesTests`

Expected: failure because `.custom`, `customStartDate`, and persistence support do not exist yet.

- [ ] **Step 3: Add the range model and persisted preference fields**

```swift
public enum TimeRangePreset: String, CaseIterable, Codable, Sendable {
    case today
    case week
    case month
    case custom

    var title: String {
        switch self {
        case .today: "今天"
        case .week: "本周"
        case .month: "本月"
        case .custom: "自定义"
        }
    }
}

public struct StatisticsDateRange: Equatable, Sendable {
    public let startDate: Date
    public let endDate: Date

    public init(startDate: Date, endDate: Date) {
        self.startDate = min(startDate, endDate)
        self.endDate = max(startDate, endDate)
    }
}
```

```swift
private enum Keys {
    static let selectedRange = "selectedRange"
    static let selectedCalendarIDs = "selectedCalendarIDs"
    static let customStartDate = "customStartDate"
    static let customEndDate = "customEndDate"
}

public var customStartDate: Date {
    didSet { defaults.set(customStartDate, forKey: Keys.customStartDate) }
}

public var customEndDate: Date {
    didSet { defaults.set(customEndDate, forKey: Keys.customEndDate) }
}
```

- [ ] **Step 4: Run the targeted tests to verify the new preference behavior passes**

Run: `swift test --filter PresentationTests --filter UserPreferencesTests`

Expected: PASS with the new range option visible and custom dates persisted.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Domain/StatisticsDateRange.swift Sources/iTime/Domain/TimeRangePreset.swift Sources/iTime/Support/Persistence/UserPreferences.swift Tests/iTimeTests/PresentationTests.swift Tests/iTimeTests/UserPreferencesTests.swift
git commit -m "feat: persist custom overview ranges"
```

## Task 2: Upgrade Aggregation for Dashboard Metrics

**Files:**
- Create: `Sources/iTime/Domain/DailyDurationSummary.swift`
- Modify: `Sources/iTime/Domain/TimeOverview.swift`
- Modify: `Sources/iTime/Services/CalendarStatisticsAggregator.swift`
- Test: `Tests/iTimeTests/TimeOverviewTests.swift`
- Test: `Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift`

- [ ] **Step 1: Write the failing tests for totals, daily averages, and trend buckets**

```swift
@Test func overviewComputesDashboardMetrics() {
    let interval = DateInterval(
        start: Date(timeIntervalSince1970: 0),
        end: Date(timeIntervalSince1970: 172_800)
    )

    let overview = TimeOverview(
        range: .custom,
        interval: interval,
        dailyDurations: [
            DailyDurationSummary(date: interval.start, totalDuration: 3_600),
            DailyDurationSummary(date: interval.start.addingTimeInterval(86_400), totalDuration: 1_800),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 3_600, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1_800, eventCount: 1),
        ]
    )

    #expect(overview.totalDuration == 5_400)
    #expect(overview.totalEventCount == 3)
    #expect(overview.averageDailyDuration == 2_700)
    #expect(overview.longestDayDuration == 3_600)
}

@Test func aggregateBuildsDailySeriesAndSortsBuckets() {
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true),
        ]
    )
    let interval = DateInterval(
        start: Date(timeIntervalSince1970: 0),
        end: Date(timeIntervalSince1970: 172_800)
    )

    let overview = aggregator.makeOverview(
        range: .custom,
        interval: interval,
        events: [
            CalendarEventRecord(id: "1", title: "Focus", calendarID: "work", startDate: interval.start, endDate: interval.start.addingTimeInterval(3_600), isAllDay: false),
            CalendarEventRecord(id: "2", title: "Dinner", calendarID: "life", startDate: interval.start.addingTimeInterval(90_000), endDate: interval.start.addingTimeInterval(91_800), isAllDay: false),
        ]
    )

    #expect(overview.dailyDurations.count == 2)
    #expect(overview.dailyDurations[0].totalDuration == 3_600)
    #expect(overview.dailyDurations[1].totalDuration == 1_800)
    #expect(overview.buckets.map(\.name) == ["Work", "Life"])
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter TimeOverviewTests --filter CalendarStatisticsAggregatorTests`

Expected: failure because `TimeOverview` does not yet expose interval, event totals, or daily summaries.

- [ ] **Step 3: Implement the richer overview model and aggregation**

```swift
public struct DailyDurationSummary: Identifiable, Equatable, Sendable {
    public let date: Date
    public let totalDuration: TimeInterval

    public var id: Date { date }
}
```

```swift
public struct TimeOverview: Equatable, Sendable {
    public let range: TimeRangePreset
    public let interval: DateInterval
    public let totalDuration: TimeInterval
    public let totalEventCount: Int
    public let averageDailyDuration: TimeInterval
    public let longestDayDuration: TimeInterval
    public let dailyDurations: [DailyDurationSummary]
    public let buckets: [TimeBucketSummary]
}
```

```swift
public func makeOverview(range: TimeRangePreset, interval: DateInterval, events: [CalendarEventRecord]) -> TimeOverview {
    let groupedByCalendar = Dictionary(grouping: events, by: \.calendarID)
    let groupedByDay = Dictionary(grouping: events) { calendar.startOfDay(for: $0.startDate) }

    let buckets = makeBuckets(from: groupedByCalendar)
    let dailyDurations = makeDailyDurations(from: groupedByDay, interval: interval)
    let totalDuration = buckets.reduce(0) { $0 + $1.totalDuration }
    let totalEventCount = buckets.reduce(0) { $0 + $1.eventCount }
    let averageDailyDuration = dailyDurations.isEmpty ? 0 : totalDuration / Double(dailyDurations.count)
    let longestDayDuration = dailyDurations.map(\.totalDuration).max() ?? 0

    return TimeOverview(
        range: range,
        interval: interval,
        totalDuration: totalDuration,
        totalEventCount: totalEventCount,
        averageDailyDuration: averageDailyDuration,
        longestDayDuration: longestDayDuration,
        dailyDurations: dailyDurations,
        buckets: buckets
    )
}
```

- [ ] **Step 4: Run the targeted tests to verify the richer aggregation passes**

Run: `swift test --filter TimeOverviewTests --filter CalendarStatisticsAggregatorTests`

Expected: PASS with total event count, average daily duration, longest day, and daily series covered.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Domain/DailyDurationSummary.swift Sources/iTime/Domain/TimeOverview.swift Sources/iTime/Services/CalendarStatisticsAggregator.swift Tests/iTimeTests/TimeOverviewTests.swift Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift
git commit -m "feat: add overview dashboard aggregation"
```

## Task 3: Resolve Actual Date Intervals in App State

**Files:**
- Modify: `Sources/iTime/Services/CalendarAccessServing.swift`
- Modify: `Sources/iTime/Services/EventKitCalendarAccessService.swift`
- Modify: `Sources/iTime/App/AppModel.swift`
- Test: `Tests/iTimeTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing tests for custom range refresh behavior**

```swift
private struct StubCalendarAccessService: CalendarAccessServing {
    var lastInterval: DateInterval?

    mutating func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        lastInterval = interval
        return events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
}

@MainActor
@Test func refreshUsesCustomDateIntervalWhenSelected() async {
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .custom
    preferences.customStartDate = Date(timeIntervalSince1970: 86_400)
    preferences.customEndDate = Date(timeIntervalSince1970: 172_800)

    let service = StubCalendarAccessService(
        state: .authorized,
        calendars: [
            CalendarSource(id: "work", name: "工作", colorHex: "#4A90E2", isSelected: true),
        ],
        events: [
            CalendarEventRecord(
                id: "1",
                title: "深度工作",
                calendarID: "work",
                startDate: Date(timeIntervalSince1970: 90_000),
                endDate: Date(timeIntervalSince1970: 93_600),
                isAllDay: false
            ),
        ]
    )
    let model = AppModel(service: service, preferences: preferences)

    await model.refresh()

    #expect(model.overview?.range == .custom)
    #expect(model.overview?.interval.start == preferences.customStartDate.startOfDay)
}

@MainActor
@Test func settingInvalidCustomDatesClampsEndDate() async {
    let preferences = UserPreferences(storage: .inMemory)
    let model = AppModel(service: service, preferences: preferences)

    await model.setCustomDateRange(start: laterDate, end: earlierDate)

    #expect(model.preferences.customStartDate <= model.preferences.customEndDate)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter AppModelTests`

Expected: failure because `fetchEvents` still accepts `TimeRangePreset` and `AppModel` cannot resolve custom intervals.

- [ ] **Step 3: Update the service protocol and app model to use concrete intervals**

```swift
public protocol CalendarAccessServing {
    func fetchEvents(in interval: DateInterval, selectedCalendarIDs: [String]) -> [CalendarEventRecord]
}
```

```swift
public func resolvedInterval(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
    switch preferences.selectedRange {
    case .today:
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateInterval(start: start, end: end)
    case .week:
        let week = calendar.dateInterval(of: .weekOfYear, for: now)!
        return week
    case .month:
        let month = calendar.dateInterval(of: .month, for: now)!
        return month
    case .custom:
        let start = calendar.startOfDay(for: preferences.customStartDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: preferences.customEndDate))!
        return DateInterval(start: start, end: end)
    }
}

public func setCustomDateRange(start: Date, end: Date) async {
    preferences.customStartDate = min(start, end)
    preferences.customEndDate = max(start, end)
    await refresh()
}
```

- [ ] **Step 4: Run the targeted tests to verify interval resolution passes**

Run: `swift test --filter AppModelTests`

Expected: PASS with custom range refresh behavior covered.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Services/CalendarAccessServing.swift Sources/iTime/Services/EventKitCalendarAccessService.swift Sources/iTime/App/AppModel.swift Tests/iTimeTests/AppModelTests.swift
git commit -m "feat: resolve overview date intervals"
```

## Task 4: Build the Dashboard Sections

**Files:**
- Create: `Sources/iTime/UI/Overview/OverviewMetricsSection.swift`
- Create: `Sources/iTime/UI/Overview/OverviewTrendChartView.swift`
- Create: `Sources/iTime/UI/Overview/OverviewBucketTable.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewChartView.swift`
- Modify: `Sources/iTime/UI/Components/RangePicker.swift`
- Modify: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing presentation tests for custom range labels and derived metric text**

```swift
@Test func allRangesAreVisibleInOrder() {
    #expect(TimeRangePreset.allCases == [.today, .week, .month, .custom])
}

@Test func dashboardMetricFormattingUsesExpectedChineseLabels() {
    #expect(OverviewMetricLabel.totalDuration == "总时长")
    #expect(OverviewMetricLabel.eventCount == "事件数")
    #expect(OverviewMetricLabel.averageDailyDuration == "日均时长")
    #expect(OverviewMetricLabel.longestDay == "最长单日")
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter PresentationTests`

Expected: failure because the overview metrics section and custom option labels are not yet present.

- [ ] **Step 3: Implement focused overview subviews**

```swift
struct OverviewMetricsSection: View {
    let overview: TimeOverview

    var body: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            MetricCard(title: "总时长", value: overview.totalDuration.formattedDuration)
            MetricCard(title: "事件数", value: "\(overview.totalEventCount)")
            MetricCard(title: "日均时长", value: overview.averageDailyDuration.formattedDuration)
            MetricCard(title: "最长单日", value: overview.longestDayDuration.formattedDuration)
        }
    }
}
```

```swift
struct OverviewTrendChartView: View {
    let overview: TimeOverview

    var body: some View {
        Chart(overview.dailyDurations) { day in
            BarMark(
                x: .value("日期", day.date, unit: .day),
                y: .value("时长", day.totalDuration / 3600)
            )
        }
        .frame(height: 220)
    }
}
```

- [ ] **Step 4: Run the targeted tests to verify presentation logic passes**

Run: `swift test --filter PresentationTests`

Expected: PASS with custom range ordering and dashboard labels stabilized.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewMetricsSection.swift Sources/iTime/UI/Overview/OverviewTrendChartView.swift Sources/iTime/UI/Overview/OverviewBucketTable.swift Sources/iTime/UI/Overview/OverviewChartView.swift Sources/iTime/UI/Components/RangePicker.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: add overview dashboard sections"
```

## Task 5: Integrate the New Overview Window Layout

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewWindowView.swift`
- Modify: `Sources/iTime/UI/MenuBar/MenuBarContentView.swift`
- Test: `Tests/iTimeTests/AppModelTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing integration assertions for empty state and custom range visibility**

```swift
@Test func rangeTitlesUseChineseStrings() {
    #expect(TimeRangePreset.custom.title == "自定义")
}

@MainActor
@Test func refreshBuildsOverviewForCustomRangeSelection() async {
    let preferences = UserPreferences(storage: .inMemory)
    preferences.selectedRange = .custom

    let model = AppModel(service: service, preferences: preferences)
    await model.refresh()

    #expect(model.overview?.range == .custom)
    #expect(model.overview?.dailyDurations.isEmpty == false)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter AppModelTests --filter PresentationTests`

Expected: failure until the overview window is wired to the new model and custom controls.

- [ ] **Step 3: Update the overview screen composition**

```swift
VStack(alignment: .leading, spacing: 20) {
    header
    RangePicker(selection: $model.preferences.selectedRange)
    if model.preferences.selectedRange == .custom {
        CustomDateRangeControls(
            startDate: Binding(
                get: { model.preferences.customStartDate },
                set: { newValue in Task { await model.setCustomDateRange(start: newValue, end: model.preferences.customEndDate) } }
            ),
            endDate: Binding(
                get: { model.preferences.customEndDate },
                set: { newValue in Task { await model.setCustomDateRange(start: model.preferences.customStartDate, end: newValue) } }
            )
        )
    }

    if let overview = model.overview, !overview.buckets.isEmpty {
        OverviewMetricsSection(overview: overview)
        OverviewTrendChartView(overview: overview)
        OverviewChartView(overview: overview)
        OverviewBucketTable(overview: overview)
    } else {
        EmptyOverviewCard()
    }
}
```

Remove the descriptive subtitle from the header and keep the menu bar view unchanged except for any compile fixes caused by the shared range picker API.

- [ ] **Step 4: Run focused and full verification**

Run: `swift test`
Expected: all Swift Testing cases pass, including the new custom range and dashboard coverage

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewWindowView.swift Sources/iTime/UI/MenuBar/MenuBarContentView.swift Tests/iTimeTests/AppModelTests.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: turn overview into a dashboard"
```

## Task 6: Final Documentation and Manual Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the README feature list and interaction description**

```md
- 查看详情窗口提供总时长、事件数、日均时长、最长单日、按天趋势和按日历排行
- 统计范围支持 今天 / 本周 / 本月 / 自定义
```

- [ ] **Step 2: Verify the dashboard manually in the app**

Run: `open iTime.xcodeproj`

Expected manual checks:
- custom range expands and persists
- invalid date ordering self-corrects
- metrics, trend chart, donut chart, and table all render in light and dark mode
- overview empty state contains no marketing text

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: describe overview dashboard"
```

## Self-Review

- Spec coverage check:
  - richer statistics covered by Tasks 2, 4, and 5
  - remove explanatory text covered by Task 5
  - custom range covered by Tasks 1, 3, and 5
  - README updates covered by Task 6
- Placeholder scan:
  - no `TBD`, `TODO`, or “implement later” placeholders remain
- Type consistency:
  - `StatisticsDateRange`, `DailyDurationSummary`, `TimeOverview.interval`, and `fetchEvents(in interval:)` are used consistently across tasks
