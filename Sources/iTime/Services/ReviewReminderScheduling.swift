import Foundation
import UserNotifications
#if canImport(AppKit)
import AppKit
#endif

public enum ReviewReminderAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

public struct ReviewReminderNotificationPayload: Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let dateComponents: DateComponents
    public let repeats: Bool

    public static func make(for time: Date, calendar: Calendar) -> Self {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return Self(
            identifier: "com.amarantos.iTime.reviewReminder",
            title: "该复盘今天的时间了",
            body: "打开 iTime，回顾今天的安排与变化。",
            dateComponents: components,
            repeats: true
        )
    }
}

public protocol ReviewReminderScheduling: Sendable {
    func authorizationStatus() async -> ReviewReminderAuthorizationStatus
    func requestAuthorization() async -> ReviewReminderAuthorizationStatus
    func scheduleDailyReminder(at time: Date) async throws
    func removeScheduledReminder() async
}

public enum ReviewReminderAuthorizationOption: String, Hashable, Sendable {
    case alert
    case sound
}

public protocol ReviewReminderAppActivating: Sendable {
    func activateApp() async
}

public protocol UserNotificationAuthorizationRequesting: Sendable {
    func requestAuthorization(options: Set<ReviewReminderAuthorizationOption>) async -> Bool
}

public struct NoopReviewReminderScheduler: ReviewReminderScheduling {
    public init() {}

    public func authorizationStatus() async -> ReviewReminderAuthorizationStatus {
        .notDetermined
    }

    public func requestAuthorization() async -> ReviewReminderAuthorizationStatus {
        .notDetermined
    }

    public func scheduleDailyReminder(at time: Date) async throws {}

    public func removeScheduledReminder() async {}
}

public struct SystemReviewReminderScheduler: @unchecked Sendable, ReviewReminderScheduling {
    private let center: UNUserNotificationCenter?
    private let calendar: Calendar
    private let authorizationRequester: UserNotificationAuthorizationRequesting
    private let appActivator: ReviewReminderAppActivating

    public init(
        center: UNUserNotificationCenter? = .current(),
        calendar: Calendar = .current,
        authorizationRequester: UserNotificationAuthorizationRequesting? = nil,
        appActivator: ReviewReminderAppActivating? = nil
    ) {
        self.center = center
        self.calendar = calendar
        self.authorizationRequester = authorizationRequester ?? SystemUserNotificationAuthorizationRequester(center: center)
        self.appActivator = appActivator ?? DefaultReviewReminderAppActivator()
    }

    public func authorizationStatus() async -> ReviewReminderAuthorizationStatus {
        guard let center else { return .notDetermined }
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: Self.mapAuthorizationStatus(settings.authorizationStatus))
            }
        }
    }

    public func requestAuthorization() async -> ReviewReminderAuthorizationStatus {
        await appActivator.activateApp()
        let granted = await authorizationRequester.requestAuthorization(options: [.alert, .sound])
        if granted {
            return .authorized
        }
        return await authorizationStatus()
    }

    public func scheduleDailyReminder(at time: Date) async throws {
        guard let center else { return }
        let payload = ReviewReminderNotificationPayload.make(for: time, calendar: calendar)
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: payload.dateComponents,
            repeats: payload.repeats
        )
        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: content,
            trigger: trigger
        )

        await removeScheduledReminder()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func removeScheduledReminder() async {
        guard let center else { return }
        let identifier = ReviewReminderNotificationPayload.make(
            for: Date(timeIntervalSince1970: 0),
            calendar: calendar
        ).identifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    private static func mapAuthorizationStatus(_ status: UNAuthorizationStatus) -> ReviewReminderAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }
}

private struct DefaultReviewReminderAppActivator: ReviewReminderAppActivating {
    @MainActor
    func activateApp() async {
        #if canImport(AppKit)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }
}

private struct SystemUserNotificationAuthorizationRequester: @unchecked Sendable, UserNotificationAuthorizationRequesting {
    let center: UNUserNotificationCenter?

    func requestAuthorization(options: Set<ReviewReminderAuthorizationOption>) async -> Bool {
        guard let center else { return false }
        let resolvedOptions = options.reduce(into: UNAuthorizationOptions()) { partialResult, option in
            partialResult.formUnion(option.authorizationOption)
        }
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: resolvedOptions) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}

private extension ReviewReminderAuthorizationOption {
    var authorizationOption: UNAuthorizationOptions {
        switch self {
        case .alert:
            return .alert
        case .sound:
            return .sound
        }
    }
}
