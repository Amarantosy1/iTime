import Foundation
import Testing
@testable import iTime

@Test func allRangesAreVisibleInOrder() {
    #expect(TimeRangePreset.allCases == [.today, .week, .month])
}

@Test func rangeTitlesUseChineseStrings() {
    #expect(TimeRangePreset.today.title == "今天")
    #expect(TimeRangePreset.week.title == "本周")
    #expect(TimeRangePreset.month.title == "本月")
}

@Test func durationFormattingRendersHoursAndMinutes() {
    #expect(TimeInterval(5400).formattedDuration == "1h 30m")
}

@Test func bucketFormattingUsesPercentageStrings() {
    let bucket = TimeBucketSummary(
        id: "work",
        name: "Work",
        colorHex: "#4A90E2",
        totalDuration: 3600,
        eventCount: 1,
        share: 0.25
    )

    #expect(bucket.shareText == "25%")
}
