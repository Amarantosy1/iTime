# iTime V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that reads calendar data, groups time by calendar, and shows time distribution in a quick summary plus a detailed chart window.

**Architecture:** Use a native SwiftUI macOS app with a menu bar entry and a separate detail window. Keep the app split into UI scenes, a calendar access service backed by EventKit, and a lightweight aggregation layer that converts calendar events into time summaries for `today`, `this week`, and `this month`.

**Tech Stack:** Swift 6, SwiftUI, EventKit, Charts, XCTest, Xcode 26

---

### Task 1: Bootstrap The Native macOS App

**Files:**
- Create: `iTime.xcodeproj`
- Create: `iTime/iTimeApp.swift`
- Create: `iTime/Info.plist`
- Create: `iTime/Assets.xcassets`
- Create: `iTime/Support/Persistence/UserPreferences.swift`
- Create: `iTimeTests/iTimeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class iTimeTests: XCTestCase {
    func testDefaultPreferencesUseTodayPresetAndNoSelectedCalendars() {
        let preferences = UserPreferences(storage: .inMemory)

        XCTAssertEqual(preferences.selectedRange, .today)
        XCTAssertEqual(preferences.selectedCalendarIDs, [])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/iTimeTests/testDefaultPreferencesUseTodayPresetAndNoSelectedCalendars`
Expected: FAIL because the project and `UserPreferences` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

@main
struct iTimeApp: App {
    @StateObject private var preferences = UserPreferences(storage: .standard)

    var body: some Scene {
        MenuBarExtra("iTime", systemImage: "clock.badge.checkmark") {
            Text("iTime")
                .padding()
        }

        Window("Overview", id: "overview") {
            Text("Overview")
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
```

```swift
import Foundation

final class UserPreferences: ObservableObject {
    enum Storage {
        case standard
        case inMemory
    }

    @Published var selectedRange: TimeRangePreset
    @Published var selectedCalendarIDs: [String]

    init(storage: Storage) {
        self.selectedRange = .today
        self.selectedCalendarIDs = []
    }
}
```

```swift
enum TimeRangePreset: String, CaseIterable {
    case today
    case week
    case month
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/iTimeTests/testDefaultPreferencesUseTodayPresetAndNoSelectedCalendars`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add .gitignore iTime.xcodeproj iTime iTimeTests plan.md
git commit -m "feat: bootstrap native macOS calendar app"
```

### Task 2: Add Time Range And Calendar Summary Models

**Files:**
- Modify: `iTime/Support/Persistence/UserPreferences.swift`
- Create: `iTime/Domain/TimeRangePreset.swift`
- Create: `iTime/Domain/CalendarSource.swift`
- Create: `iTime/Domain/TimeBucketSummary.swift`
- Create: `iTime/Domain/TimeOverview.swift`
- Test: `iTimeTests/TimeOverviewTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class TimeOverviewTests: XCTestCase {
    func testOverviewComputesTotalDurationFromBuckets() {
        let overview = TimeOverview(
            range: .today,
            buckets: [
                TimeBucketSummary(
                    id: "work",
                    name: "Work",
                    colorHex: "#4A90E2",
                    totalDuration: 3600,
                    eventCount: 2
                ),
                TimeBucketSummary(
                    id: "life",
                    name: "Life",
                    colorHex: "#50E3C2",
                    totalDuration: 1800,
                    eventCount: 1
                )
            ]
        )

        XCTAssertEqual(overview.totalDuration, 5400)
        XCTAssertEqual(overview.buckets[0].share, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(overview.buckets[1].share, 1.0 / 3.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/TimeOverviewTests/testOverviewComputesTotalDurationFromBuckets`
Expected: FAIL because overview models do not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

struct CalendarSource: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    var isSelected: Bool
}
```

```swift
import Foundation

struct TimeBucketSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let colorHex: String
    let totalDuration: TimeInterval
    let eventCount: Int
    var share: Double = 0
}
```

```swift
import Foundation

struct TimeOverview: Equatable {
    let range: TimeRangePreset
    let totalDuration: TimeInterval
    let buckets: [TimeBucketSummary]

    init(range: TimeRangePreset, buckets: [TimeBucketSummary]) {
        let total = buckets.reduce(0) { $0 + $1.totalDuration }
        self.range = range
        self.totalDuration = total
        self.buckets = buckets.map { bucket in
            var copy = bucket
            copy.share = total == 0 ? 0 : bucket.totalDuration / total
            return copy
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/TimeOverviewTests/testOverviewComputesTotalDurationFromBuckets`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/Domain iTime/Support/Persistence/UserPreferences.swift iTimeTests/TimeOverviewTests.swift
git commit -m "feat: add time overview domain models"
```

### Task 3: Implement Calendar Permission And Fetch Service

**Files:**
- Create: `iTime/Services/CalendarAccessServing.swift`
- Create: `iTime/Services/EventKitCalendarAccessService.swift`
- Create: `iTime/Domain/CalendarEventRecord.swift`
- Test: `iTimeTests/EventKitCalendarAccessServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class EventKitCalendarAccessServiceTests: XCTestCase {
    func testDateIntervalForWeekCoversCurrentWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSince1970: 1_742_070_400)

        let interval = EventKitCalendarAccessService.dateInterval(
            for: .week,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(interval.duration, 7 * 24 * 3600, accuracy: 1)
        XCTAssertTrue(interval.start <= referenceDate)
        XCTAssertTrue(interval.end >= referenceDate)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/EventKitCalendarAccessServiceTests/testDateIntervalForWeekCoversCurrentWeek`
Expected: FAIL because the service does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

struct CalendarEventRecord: Equatable {
    let id: String
    let title: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

protocol CalendarAccessServing {
    func authorizationState() -> CalendarAuthorizationState
    func requestAccess() async -> CalendarAuthorizationState
    func fetchCalendars() -> [CalendarSource]
    func fetchEvents(
        in range: TimeRangePreset,
        selectedCalendarIDs: [String]
    ) -> [CalendarEventRecord]
}
```

```swift
import EventKit
import Foundation

final class EventKitCalendarAccessService: CalendarAccessServing {
    private let store = EKEventStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func authorizationState() -> CalendarAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .restricted
        }
    }

    func requestAccess() async -> CalendarAuthorizationState {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            return authorizationState()
        }
        return authorizationState()
    }

    func fetchCalendars() -> [CalendarSource] {
        store.calendars(for: .event).map { item in
            CalendarSource(
                id: item.calendarIdentifier,
                name: item.title,
                colorHex: item.cgColor.hexString,
                isSelected: false
            )
        }
    }

    func fetchEvents(in range: TimeRangePreset, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        let interval = Self.dateInterval(for: range, referenceDate: .now, calendar: calendar)
        let calendars = store.calendars(for: .event).filter {
            selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarIdentifier)
        }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return store.events(matching: predicate).map {
            CalendarEventRecord(
                id: $0.eventIdentifier,
                title: $0.title,
                calendarID: $0.calendar.calendarIdentifier,
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay
            )
        }
    }

    static func dateInterval(for range: TimeRangePreset, referenceDate: Date, calendar: Calendar) -> DateInterval {
        switch range {
        case .today:
            return calendar.dateInterval(of: .day, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 24 * 3600)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 7 * 24 * 3600)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 30 * 24 * 3600)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/EventKitCalendarAccessServiceTests/testDateIntervalForWeekCoversCurrentWeek`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/Services iTime/Domain/CalendarEventRecord.swift iTimeTests/EventKitCalendarAccessServiceTests.swift
git commit -m "feat: add eventkit calendar access service"
```

### Task 4: Implement Aggregation Logic

**Files:**
- Create: `iTime/Services/StatisticsAggregating.swift`
- Create: `iTime/Services/CalendarStatisticsAggregator.swift`
- Test: `iTimeTests/CalendarStatisticsAggregatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class CalendarStatisticsAggregatorTests: XCTestCase {
    func testAggregateGroupsDurationByCalendar() {
        let aggregator = CalendarStatisticsAggregator(
            calendarLookup: [
                "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
                "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true)
            ]
        )

        let overview = aggregator.makeOverview(
            range: .today,
            events: [
                CalendarEventRecord(
                    id: "1",
                    title: "Focus",
                    calendarID: "work",
                    startDate: .init(timeIntervalSince1970: 0),
                    endDate: .init(timeIntervalSince1970: 3600),
                    isAllDay: false
                ),
                CalendarEventRecord(
                    id: "2",
                    title: "Dinner",
                    calendarID: "life",
                    startDate: .init(timeIntervalSince1970: 7200),
                    endDate: .init(timeIntervalSince1970: 9000),
                    isAllDay: false
                )
            ]
        )

        XCTAssertEqual(overview.totalDuration, 5400)
        XCTAssertEqual(overview.buckets.count, 2)
        XCTAssertEqual(overview.buckets[0].name, "Work")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/CalendarStatisticsAggregatorTests/testAggregateGroupsDurationByCalendar`
Expected: FAIL because the aggregator does not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

protocol StatisticsAggregating {
    func makeOverview(range: TimeRangePreset, events: [CalendarEventRecord]) -> TimeOverview
}
```

```swift
import Foundation

final class CalendarStatisticsAggregator: StatisticsAggregating {
    private let calendarLookup: [String: CalendarSource]

    init(calendarLookup: [String: CalendarSource]) {
        self.calendarLookup = calendarLookup
    }

    func makeOverview(range: TimeRangePreset, events: [CalendarEventRecord]) -> TimeOverview {
        let grouped = Dictionary(grouping: events) { $0.calendarID }
        let buckets = grouped.compactMap { calendarID, items in
            guard let source = calendarLookup[calendarID] else { return nil }
            let total = items.reduce(0) { partial, event in
                partial + max(0, event.endDate.timeIntervalSince(event.startDate))
            }

            return TimeBucketSummary(
                id: source.id,
                name: source.name,
                colorHex: source.colorHex,
                totalDuration: total,
                eventCount: items.count
            )
        }
        .sorted { $0.totalDuration > $1.totalDuration }

        return TimeOverview(range: range, buckets: buckets)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/CalendarStatisticsAggregatorTests/testAggregateGroupsDurationByCalendar`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/Services/StatisticsAggregating.swift iTime/Services/CalendarStatisticsAggregator.swift iTimeTests/CalendarStatisticsAggregatorTests.swift
git commit -m "feat: add calendar statistics aggregation"
```

### Task 5: Build Shared App State

**Files:**
- Create: `iTime/App/AppModel.swift`
- Test: `iTimeTests/AppModelTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class AppModelTests: XCTestCase {
    func testRefreshLoadsCalendarsAndOverview() async {
        let service = StubCalendarAccessService(
            state: .authorized,
            calendars: [
                CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true)
            ],
            events: [
                CalendarEventRecord(
                    id: "1",
                    title: "Focus",
                    calendarID: "work",
                    startDate: .init(timeIntervalSince1970: 0),
                    endDate: .init(timeIntervalSince1970: 3600),
                    isAllDay: false
                )
            ]
        )
        let model = AppModel(
            service: service,
            preferences: UserPreferences(storage: .inMemory)
        )

        await model.refresh()

        XCTAssertEqual(model.authorizationState, .authorized)
        XCTAssertEqual(model.availableCalendars.count, 1)
        XCTAssertEqual(model.overview?.totalDuration, 3600)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/AppModelTests/testRefreshLoadsCalendarsAndOverview`
Expected: FAIL because `AppModel` and the test stub do not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var authorizationState: CalendarAuthorizationState
    @Published private(set) var availableCalendars: [CalendarSource]
    @Published private(set) var overview: TimeOverview?

    let preferences: UserPreferences
    private let service: CalendarAccessServing

    init(service: CalendarAccessServing, preferences: UserPreferences) {
        self.service = service
        self.preferences = preferences
        self.authorizationState = service.authorizationState()
        self.availableCalendars = []
        self.overview = nil
    }

    func refresh() async {
        authorizationState = service.authorizationState()
        guard authorizationState == .authorized else {
            availableCalendars = []
            overview = nil
            return
        }

        var calendars = service.fetchCalendars()
        let selectedIDs = preferences.selectedCalendarIDs
        if selectedIDs.isEmpty {
            calendars = calendars.map { CalendarSource(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: true) }
        } else {
            calendars = calendars.map { CalendarSource(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSelected: selectedIDs.contains($0.id)) }
        }

        availableCalendars = calendars
        let selected = calendars.filter(\.isSelected).map(\.id)
        let events = service.fetchEvents(in: preferences.selectedRange, selectedCalendarIDs: selected)
        let aggregator = CalendarStatisticsAggregator(calendarLookup: Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) }))
        overview = aggregator.makeOverview(range: preferences.selectedRange, events: events)
    }
}
```

```swift
import Foundation

struct StubCalendarAccessService: CalendarAccessServing {
    let state: CalendarAuthorizationState
    let calendars: [CalendarSource]
    let events: [CalendarEventRecord]

    func authorizationState() -> CalendarAuthorizationState { state }
    func requestAccess() async -> CalendarAuthorizationState { state }
    func fetchCalendars() -> [CalendarSource] { calendars }
    func fetchEvents(in range: TimeRangePreset, selectedCalendarIDs: [String]) -> [CalendarEventRecord] {
        events.filter { selectedCalendarIDs.isEmpty || selectedCalendarIDs.contains($0.calendarID) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/AppModelTests/testRefreshLoadsCalendarsAndOverview`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/App/AppModel.swift iTimeTests/AppModelTests.swift
git commit -m "feat: add shared app state"
```

### Task 6: Build Menu Bar Summary UI

**Files:**
- Modify: `iTime/iTimeApp.swift`
- Create: `iTime/UI/MenuBar/MenuBarContentView.swift`
- Create: `iTime/UI/Components/RangePicker.swift`
- Create: `iTime/UI/Components/AuthorizationStateView.swift`
- Test: `iTimeTests/RangePickerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class RangePickerTests: XCTestCase {
    func testAllRangesAreVisibleInOrder() {
        XCTAssertEqual(TimeRangePreset.allCases, [.today, .week, .month])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/RangePickerTests/testAllRangesAreVisibleInOrder`
Expected: FAIL until the range picker support code is wired into the project.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RangePicker(selection: $model.preferences.selectedRange)

            switch model.authorizationState {
            case .authorized:
                if let overview = model.overview {
                    Text(overview.totalDuration.formattedDuration)
                        .font(.title2.weight(.semibold))

                    ForEach(overview.buckets.prefix(3)) { bucket in
                        HStack {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)
                            Text(bucket.name)
                            Spacer()
                            Text(bucket.totalDuration.formattedDuration)
                        }
                    }
                } else {
                    Text("No events in this range.")
                        .foregroundStyle(.secondary)
                }
            default:
                AuthorizationStateView(state: model.authorizationState) {
                    Task { await model.requestAccessIfNeeded() }
                }
            }

            Button("Open Details") {
                openWindow(id: "overview")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 320)
        .task { await model.refresh() }
    }
}
```

```swift
import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset

    var body: some View {
        Picker("Range", selection: $selection) {
            Text("Today").tag(TimeRangePreset.today)
            Text("Week").tag(TimeRangePreset.week)
            Text("Month").tag(TimeRangePreset.month)
        }
        .pickerStyle(.segmented)
    }
}
```

```swift
import SwiftUI

struct AuthorizationStateView: View {
    let state: CalendarAuthorizationState
    let requestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .foregroundStyle(.secondary)

            if state == .notDetermined {
                Button("Allow Calendar Access", action: requestAccess)
            }
        }
    }

    private var message: String {
        switch state {
        case .notDetermined:
            return "Calendar access is required to analyze your time."
        case .restricted:
            return "Calendar access is restricted by the system."
        case .denied:
            return "Calendar access is denied. Enable it in System Settings."
        case .authorized:
            return ""
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/RangePickerTests/testAllRangesAreVisibleInOrder`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/iTimeApp.swift iTime/UI iTimeTests/RangePickerTests.swift
git commit -m "feat: add menu bar summary interface"
```

### Task 7: Build Detail Window Charts UI

**Files:**
- Create: `iTime/UI/Overview/OverviewWindowView.swift`
- Create: `iTime/UI/Overview/OverviewChartView.swift`
- Test: `iTimeTests/OverviewPresentationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class OverviewPresentationTests: XCTestCase {
    func testBucketFormattingUsesPercentageStrings() {
        let bucket = TimeBucketSummary(
            id: "work",
            name: "Work",
            colorHex: "#4A90E2",
            totalDuration: 3600,
            eventCount: 1,
            share: 0.25
        )

        XCTAssertEqual(bucket.shareText, "25%")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/OverviewPresentationTests/testBucketFormattingUsesPercentageStrings`
Expected: FAIL because presentation helpers do not exist.

- [ ] **Step 3: Write minimal implementation**

```swift
import Charts
import SwiftUI

struct OverviewWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Where did your time go?")
                    .font(.largeTitle.bold())

                RangePicker(selection: $model.preferences.selectedRange)

                if let overview = model.overview, !overview.buckets.isEmpty {
                    OverviewChartView(overview: overview)

                    ForEach(overview.buckets) { bucket in
                        HStack {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 10, height: 10)
                            Text(bucket.name)
                            Spacer()
                            Text(bucket.shareText)
                            Text(bucket.totalDuration.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No events available for this time range.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .task { await model.refresh() }
    }
}
```

```swift
import Charts
import SwiftUI

struct OverviewChartView: View {
    let overview: TimeOverview

    var body: some View {
        Chart(overview.buckets) { bucket in
            SectorMark(
                angle: .value("Duration", bucket.totalDuration),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(Color(hex: bucket.colorHex))
        }
        .frame(height: 260)
    }
}
```

```swift
import Foundation

extension TimeBucketSummary {
    var shareText: String {
        "\(Int((share * 100).rounded()))%"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/OverviewPresentationTests/testBucketFormattingUsesPercentageStrings`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/UI/Overview iTimeTests/OverviewPresentationTests.swift
git commit -m "feat: add overview charts window"
```

### Task 8: Add Liquid Glass Styling And Wiring

**Files:**
- Modify: `iTime/iTimeApp.swift`
- Modify: `iTime/UI/MenuBar/MenuBarContentView.swift`
- Modify: `iTime/UI/Overview/OverviewWindowView.swift`
- Create: `iTime/UI/Theme/LiquidGlassCard.swift`
- Create: `iTime/UI/Theme/Color+Hex.swift`
- Create: `iTime/Support/Formatting/TimeInterval+Formatting.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import iTime

final class TimeFormattingTests: XCTestCase {
    func testDurationFormattingRendersHoursAndMinutes() {
        XCTAssertEqual(TimeInterval(5400).formattedDuration, "1h 30m")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/TimeFormattingTests/testDurationFormattingRendersHoursAndMinutes`
Expected: FAIL because formatting helpers are missing.

- [ ] **Step 3: Write minimal implementation**

```swift
import SwiftUI

struct LiquidGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                content
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
            } else {
                content
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}
```

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        let value = Int(sanitized, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
```

```swift
import Foundation

extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours == 0 {
            return "\(remainder)m"
        }
        if remainder == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainder)m"
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' -only-testing:iTimeTests/TimeFormattingTests/testDurationFormattingRendersHoursAndMinutes`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add iTime/UI/Theme iTime/Support/Formatting/TimeInterval+Formatting.swift iTimeTests/TimeFormattingTests.swift
git commit -m "feat: add liquid glass styling helpers"
```

### Task 9: End-To-End Verification

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing test**

Use the already-added automated test suite as the regression net for the feature set.

- [ ] **Step 2: Run verification to confirm current gaps**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS'`
Expected: This may fail before the final wiring and project settings are complete.

- [ ] **Step 3: Finish integration**

Ensure these behaviors work together:
- Menu bar launch succeeds.
- Requesting calendar access updates UI state.
- Changing the time range refreshes event aggregation.
- Opening the detail window shows the same overview data and chart.
- Selected calendars and time range persist across launches.

- [ ] **Step 4: Run final verification**

Run: `xcodebuild test -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS'`
Expected: PASS with all tests green.

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update project readme for v1 calendar analytics app"
```

## Assumptions And Defaults

- V1 only supports the latest macOS and may directly use modern SwiftUI and Liquid Glass APIs with local fallback guards where needed.
- Time categories are calendar-based only; no manual tags, no keyword rule engine, no AI evaluation, and no Health sleep import in this phase.
- The default user experience is a menu bar summary plus a dedicated detail window.
- Event data is fetched live from EventKit and not duplicated into a local database.
- User preferences only persist selected calendar IDs and the active time range preset.
