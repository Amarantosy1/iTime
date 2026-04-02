import Foundation
import SwiftUI
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

@Test func overviewBackgroundPaletteChangesWithColorScheme() {
    let lightPalette = AppTheme.overviewBackgroundPalette(for: .light)
    let darkPalette = AppTheme.overviewBackgroundPalette(for: .dark)

    #expect(lightPalette.startHex == "#F2F7FF")
    #expect(lightPalette.endHex == "#E6F0FA")
    #expect(darkPalette.startHex == "#111827")
    #expect(darkPalette.endHex == "#1F2937")
}

@Test func overviewBackgroundGradientUsesPaletteColors() {
    let darkGradient = AppTheme.overviewBackgroundGradient(for: .dark)
    let lightGradient = AppTheme.overviewBackgroundGradient(for: .light)

    #expect(darkGradient.palette == AppTheme.BackgroundPalette(startHex: "#111827", endHex: "#1F2937"))
    #expect(lightGradient.palette == AppTheme.BackgroundPalette(startHex: "#F2F7FF", endHex: "#E6F0FA"))
}
