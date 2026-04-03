import Foundation
import Testing
@testable import iTime

private final class RecordingReviewReminderAppActivator: @unchecked Sendable, ReviewReminderAppActivating {
    private(set) var activationCount = 0

    func activateApp() async {
        activationCount += 1
    }
}

private final class StubNotificationAuthorizationRequester: @unchecked Sendable, UserNotificationAuthorizationRequesting {
    var grantedResult: Bool
    private(set) var requestedOptions: [ReviewReminderAuthorizationOption] = []

    init(grantedResult: Bool) {
        self.grantedResult = grantedResult
    }

    func requestAuthorization(options: Set<ReviewReminderAuthorizationOption>) async -> Bool {
        requestedOptions = Array(options).sorted(by: { $0.rawValue < $1.rawValue })
        return grantedResult
    }
}

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

@Test func requestAuthorizationActivatesMenuBarAppBeforePromptingSystemPermission() async {
    let activator = RecordingReviewReminderAppActivator()
    let requester = StubNotificationAuthorizationRequester(grantedResult: true)
    let scheduler = SystemReviewReminderScheduler(
        center: nil,
        calendar: Calendar(identifier: .gregorian),
        authorizationRequester: requester,
        appActivator: activator
    )

    let status = await scheduler.requestAuthorization()

    #expect(status == .authorized)
    #expect(activator.activationCount == 1)
    #expect(requester.requestedOptions == [.alert, .sound])
}
