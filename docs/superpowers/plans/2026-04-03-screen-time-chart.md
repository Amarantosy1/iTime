# Screen Time Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the overview window's simple daily trend chart with a Screen Time-style stacked usage chart grouped by calendar, with adaptive day/week bucketing and a readable legend/summary.

**Architecture:** Extend the domain model with explicit stacked chart bucket types, then upgrade `CalendarStatisticsAggregator` to build chart-ready bucket data in the same pass that computes totals and ranking rows. Keep `AppModel` unchanged as the owner of `TimeOverview`, and swap the overview trend card to render stacked `BarMark`s plus a lightweight summary and legend derived from the precomputed overview data.

**Tech Stack:** Swift 6, SwiftUI, Charts, Observation, Foundation Calendar math, Swift Testing, xcodebuild

---

## File Map

- Create: `Sources/iTime/Domain/OverviewStackedBucket.swift`
- Modify: `Sources/iTime/Domain/TimeOverview.swift`
- Modify: `Sources/iTime/Services/CalendarStatisticsAggregator.swift`
- Modify: `Sources/iTime/UI/Overview/OverviewTrendChartView.swift`
- Modify: `Tests/iTimeTests/TimeOverviewTests.swift`
- Modify: `Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift`
- Modify: `Tests/iTimeTests/PresentationTests.swift`

## Task 1: Add Stacked Chart Domain Types

**Files:**
- Create: `Sources/iTime/Domain/OverviewStackedBucket.swift`
- Modify: `Sources/iTime/Domain/TimeOverview.swift`
- Test: `Tests/iTimeTests/TimeOverviewTests.swift`

- [ ] **Step 1: Write the failing tests for the new stacked chart model**

```swift
@Test func overviewCarriesStackedBucketsAndResolution() {
    let start = Date(timeIntervalSince1970: 0)
    let overview = TimeOverview(
        range: .week,
        interval: DateInterval(start: start, end: start.addingTimeInterval(7 * 86_400)),
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 7_200),
        ],
        stackedBucketResolution: .day,
        stackedBuckets: [
            OverviewStackedBucket(
                id: "1970-01-01",
                label: "1日",
                interval: DateInterval(start: start, end: start.addingTimeInterval(86_400)),
                totalDuration: 7_200,
                segments: [
                    OverviewStackedSegment(calendarID: "work", calendarName: "Work", calendarColorHex: "#4A90E2", duration: 5_400),
                    OverviewStackedSegment(calendarID: "life", calendarName: "Life", calendarColorHex: "#50E3C2", duration: 1_800),
                ]
            ),
        ],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 5_400, eventCount: 2),
            TimeBucketSummary(id: "life", name: "Life", colorHex: "#50E3C2", totalDuration: 1_800, eventCount: 1),
        ]
    )

    #expect(overview.stackedBucketResolution == .day)
    #expect(overview.stackedBuckets.count == 1)
    #expect(overview.stackedBuckets[0].segments.count == 2)
    #expect(overview.stackedBuckets[0].segments[0].calendarName == "Work")
}

@Test func stackedBucketSummaryUsesRangeDayCountForAverage() {
    let start = Date(timeIntervalSince1970: 0)
    let overview = TimeOverview(
        range: .custom,
        interval: DateInterval(start: start, end: start.addingTimeInterval(3 * 86_400)),
        dailyDurations: [
            DailyDurationSummary(date: start, totalDuration: 3_600),
            DailyDurationSummary(date: start.addingTimeInterval(86_400), totalDuration: 0),
            DailyDurationSummary(date: start.addingTimeInterval(2 * 86_400), totalDuration: 1_800),
        ],
        stackedBucketResolution: .day,
        stackedBuckets: [],
        buckets: [
            TimeBucketSummary(id: "work", name: "Work", colorHex: "#4A90E2", totalDuration: 5_400, eventCount: 3),
        ]
    )

    #expect(overview.totalDuration == 5_400)
    #expect(overview.averageDailyDuration == 1_800)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter TimeOverviewTests`

Expected: FAIL because `OverviewStackedBucket`, `OverviewStackedSegment`, and `stackedBucketResolution` do not exist.

- [ ] **Step 3: Add the new chart domain types and wire them into `TimeOverview`**

```swift
public enum OverviewStackedBucketResolution: String, Equatable, Sendable {
    case day
    case week
}

public struct OverviewStackedSegment: Identifiable, Equatable, Sendable {
    public let calendarID: String
    public let calendarName: String
    public let calendarColorHex: String
    public let duration: TimeInterval

    public var id: String { calendarID }
}

public struct OverviewStackedBucket: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let interval: DateInterval
    public let totalDuration: TimeInterval
    public let segments: [OverviewStackedSegment]
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
    public let stackedBucketResolution: OverviewStackedBucketResolution
    public let stackedBuckets: [OverviewStackedBucket]
    public let buckets: [TimeBucketSummary]

    public init(
        range: TimeRangePreset,
        interval: DateInterval,
        dailyDurations: [DailyDurationSummary],
        stackedBucketResolution: OverviewStackedBucketResolution,
        stackedBuckets: [OverviewStackedBucket],
        buckets: [TimeBucketSummary]
    ) {
        let total = buckets.reduce(0) { $0 + $1.totalDuration }
        let totalEventCount = buckets.reduce(0) { $0 + $1.eventCount }

        self.range = range
        self.interval = interval
        self.totalDuration = total
        self.totalEventCount = totalEventCount
        self.averageDailyDuration = dailyDurations.isEmpty ? 0 : total / Double(dailyDurations.count)
        self.longestDayDuration = dailyDurations.map(\.totalDuration).max() ?? 0
        self.dailyDurations = dailyDurations
        self.stackedBucketResolution = stackedBucketResolution
        self.stackedBuckets = stackedBuckets
        self.buckets = buckets.map { bucket in
            var updated = bucket
            updated.share = total == 0 ? 0 : bucket.totalDuration / total
            return updated
        }
    }
}
```

- [ ] **Step 4: Run the targeted tests to verify the domain model passes**

Run: `swift test --filter TimeOverviewTests`

Expected: PASS with the new stacked chart fields and unchanged dashboard metrics.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Domain/OverviewStackedBucket.swift Sources/iTime/Domain/TimeOverview.swift Tests/iTimeTests/TimeOverviewTests.swift
git commit -m "feat: add overview stacked chart model"
```

## Task 2: Upgrade Aggregation for Day and Week Stacked Buckets

**Files:**
- Modify: `Sources/iTime/Services/CalendarStatisticsAggregator.swift`
- Modify: `Sources/iTime/Domain/TimeOverview.swift`
- Test: `Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift`
- Test: `Tests/iTimeTests/TimeOverviewTests.swift`

- [ ] **Step 1: Write the failing tests for stacked aggregation and adaptive weekly grouping**

```swift
@Test func aggregateBuildsStackedDayBucketsInStableCalendarOrder() {
    let calendar = makeUTCGregorianCalendar()
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
            "life": CalendarSource(id: "life", name: "Life", colorHex: "#50E3C2", isSelected: true),
        ],
        calendar: calendar
    )
    let interval = DateInterval(
        start: Date(timeIntervalSince1970: 0),
        end: Date(timeIntervalSince1970: 3 * 86_400)
    )

    let overview = aggregator.makeOverview(
        range: .custom,
        interval: interval,
        events: [
            CalendarEventRecord(id: "1", title: "Focus", calendarID: "work", startDate: interval.start, endDate: interval.start.addingTimeInterval(3_600), isAllDay: false),
            CalendarEventRecord(id: "2", title: "Dinner", calendarID: "life", startDate: interval.start, endDate: interval.start.addingTimeInterval(1_800), isAllDay: false),
            CalendarEventRecord(id: "3", title: "Plan", calendarID: "work", startDate: interval.start.addingTimeInterval(2 * 86_400), endDate: interval.start.addingTimeInterval(2 * 86_400 + 1_800), isAllDay: false),
        ]
    )

    #expect(overview.stackedBucketResolution == .day)
    #expect(overview.stackedBuckets.count == 3)
    #expect(overview.stackedBuckets[0].segments.map(\.calendarName) == ["Work", "Life"])
    #expect(overview.stackedBuckets[1].totalDuration == 0)
    #expect(overview.stackedBuckets[2].segments.first?.duration == 1_800)
}

@Test func aggregateUsesWeekBucketsForLongCustomRanges() {
    let calendar = makeUTCGregorianCalendar()
    let aggregator = CalendarStatisticsAggregator(
        calendarLookup: [
            "work": CalendarSource(id: "work", name: "Work", colorHex: "#4A90E2", isSelected: true),
        ],
        calendar: calendar
    )
    let interval = DateInterval(
        start: Date(timeIntervalSince1970: 0),
        end: Date(timeIntervalSince1970: 60 * 86_400)
    )

    let overview = aggregator.makeOverview(
        range: .custom,
        interval: interval,
        events: [
            CalendarEventRecord(id: "1", title: "Focus", calendarID: "work", startDate: interval.start, endDate: interval.start.addingTimeInterval(3_600), isAllDay: false),
        ]
    )

    #expect(overview.stackedBucketResolution == .week)
    #expect(overview.stackedBuckets.count < 20)
    #expect(overview.stackedBuckets.first?.totalDuration == 3_600)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter CalendarStatisticsAggregatorTests`

Expected: FAIL because the aggregator only produces `dailyDurations` and `buckets`.

- [ ] **Step 3: Implement stacked bucket aggregation and adaptive resolution**

```swift
private let weeklyBucketThreshold = 45

public func makeOverview(range: TimeRangePreset, interval: DateInterval, events: [CalendarEventRecord]) -> TimeOverview {
    let buckets = makeCalendarBuckets(from: events)
    let dailyDurations = makeDailyDurations(in: interval, events: events)
    let resolution = makeBucketResolution(for: interval)
    let stackedBuckets = makeStackedBuckets(
        in: interval,
        events: events,
        calendarBuckets: buckets,
        resolution: resolution
    )

    return TimeOverview(
        range: range,
        interval: interval,
        dailyDurations: dailyDurations,
        stackedBucketResolution: resolution,
        stackedBuckets: stackedBuckets,
        buckets: buckets
    )
}
```

```swift
private func makeBucketResolution(for interval: DateInterval) -> OverviewStackedBucketResolution {
    let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
    return dayCount > weeklyBucketThreshold ? .week : .day
}

private func makeStackedBuckets(
    in interval: DateInterval,
    events: [CalendarEventRecord],
    calendarBuckets: [TimeBucketSummary],
    resolution: OverviewStackedBucketResolution
) -> [OverviewStackedBucket] {
    let orderedCalendars = calendarBuckets.map(\.id)
    let bucketIntervals = makeBucketIntervals(in: interval, resolution: resolution)

    return bucketIntervals.map { bucketInterval in
        let grouped = Dictionary(grouping: events.filter { bucketInterval.contains($0.startDate) }, by: \.calendarID)
        let segments = orderedCalendars.compactMap { calendarID -> OverviewStackedSegment? in
            guard let source = calendarLookup[calendarID] else { return nil }
            let duration = grouped[calendarID, default: []].reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
            guard duration > 0 else { return nil }
            return OverviewStackedSegment(
                calendarID: source.id,
                calendarName: source.name,
                calendarColorHex: source.colorHex,
                duration: duration
            )
        }

        return OverviewStackedBucket(
            id: bucketInterval.start.ISO8601Format(),
            label: bucketLabel(for: bucketInterval, resolution: resolution),
            interval: bucketInterval,
            totalDuration: segments.reduce(0) { $0 + $1.duration },
            segments: segments
        )
    }
}
```

- [ ] **Step 4: Run the targeted tests to verify aggregation passes**

Run: `swift test --filter CalendarStatisticsAggregatorTests --filter TimeOverviewTests`

Expected: PASS with empty buckets preserved, stable segment ordering, and weekly grouping for long custom ranges.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/Services/CalendarStatisticsAggregator.swift Sources/iTime/Domain/TimeOverview.swift Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift Tests/iTimeTests/TimeOverviewTests.swift
git commit -m "feat: aggregate overview stacked chart buckets"
```

## Task 3: Render the Stacked Chart, Legend, and Summary

**Files:**
- Modify: `Sources/iTime/UI/Overview/OverviewTrendChartView.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Write the failing presentation tests for chart copy and summary behavior**

```swift
@Test func stackedTrendSectionUsesChineseStrings() {
    #expect(OverviewTrendChartCopy.title(for: .day) == "每日分布")
    #expect(OverviewTrendChartCopy.title(for: .week) == "每周分布")
    #expect(OverviewTrendChartCopy.summaryPrefix == "最忙时段")
}

@Test func stackedTrendSummaryHighlightsLargestCalendar() {
    let bucket = OverviewStackedBucket(
        id: "1970-01-01",
        label: "1日",
        interval: DateInterval(start: .init(timeIntervalSince1970: 0), end: .init(timeIntervalSince1970: 86_400)),
        totalDuration: 7_200,
        segments: [
            OverviewStackedSegment(calendarID: "work", calendarName: "工作", calendarColorHex: "#4A90E2", duration: 5_400),
            OverviewStackedSegment(calendarID: "life", calendarName: "生活", calendarColorHex: "#50E3C2", duration: 1_800),
        ]
    )

    #expect(OverviewTrendSummary(bucket: bucket)?.contains("工作") == true)
    #expect(OverviewTrendSummary(bucket: bucket)?.contains("2h") == true)
}
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `swift test --filter PresentationTests`

Expected: FAIL because the trend view has no copy helper or stacked summary formatter.

- [ ] **Step 3: Replace the single-series chart with a stacked chart view**

```swift
struct OverviewTrendChartView: View {
    let overview: TimeOverview

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(OverviewTrendChartCopy.title(for: overview.stackedBucketResolution))
                    .font(.headline)

                Chart {
                    ForEach(overview.stackedBuckets) { bucket in
                        ForEach(bucket.segments) { segment in
                            BarMark(
                                x: .value("日期", bucket.label),
                                y: .value("时长", segment.duration / 3600)
                            )
                            .foregroundStyle(by: .value("日历", segment.calendarName))
                            .position(by: .value("日历", segment.calendarName))
                        }
                    }
                }
                .chartForegroundStyleScale(domain: overview.buckets.map(\.name), range: overview.buckets.map { Color(hex: $0.colorHex) })
                .frame(height: 260)

                if let summary = OverviewTrendSummary(bucket: overview.stackedBuckets.max(by: { $0.totalDuration < $1.totalDuration })) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 12) {
                    ForEach(overview.buckets) { bucket in
                        Label {
                            Text(bucket.name)
                        } icon: {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 4: Run the targeted tests to verify the copy helpers and view support pass**

Run: `swift test --filter PresentationTests`

Expected: PASS with the new Chinese labels and deterministic summary text helpers.

- [ ] **Step 5: Commit**

```bash
git add Sources/iTime/UI/Overview/OverviewTrendChartView.swift Tests/iTimeTests/PresentationTests.swift
git commit -m "feat: render stacked screen time chart"
```

## Task 4: Run Full Verification

**Files:**
- Modify: none
- Test: `Tests/iTimeTests/TimeOverviewTests.swift`
- Test: `Tests/iTimeTests/CalendarStatisticsAggregatorTests.swift`
- Test: `Tests/iTimeTests/PresentationTests.swift`

- [ ] **Step 1: Run the package test suite**

Run: `swift test`

Expected: PASS with all existing and new tests green.

- [ ] **Step 2: Run the macOS app test suite**

Run: `xcodebuild -project iTime.xcodeproj -scheme iTime -destination 'platform=macOS' test`

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Inspect the branch state**

Run: `git status --short --branch`

Expected: clean feature branch with no uncommitted changes.
