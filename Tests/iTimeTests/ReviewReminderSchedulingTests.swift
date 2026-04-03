import Foundation
import Testing
@testable import iTime

@Test func reviewReminderNotificationPayloadUsesFixedIdentifierAndDailyTime() {
    let reminderTime = Date(timeIntervalSince1970: 3_600)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let payload = ReviewReminderNotificationPayload.make(for: reminderTime, calendar: calendar)

    #expect(payload.identifier == "com.amarantos.iTime.reviewReminder")
    #expect(payload.title == "该复盘今天的时间了")
    #expect(payload.body == "打开 iTime，回顾今天的安排与变化。")
    #expect(payload.dateComponents.hour == 1)
    #expect(payload.dateComponents.minute == 0)
    #expect(payload.repeats == true)
}
