import SwiftUI
import UserNotifications

private final class iTimeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = ReviewReminderNotificationCenterDelegate.shared
    }
}

@main
struct iTimeApp: App {
    @NSApplicationDelegateAdaptor(iTimeAppDelegate.self) private var appDelegate
    @State private var model = AppModel(
        service: EventKitCalendarAccessService(),
        preferences: UserPreferences(storage: .standard),
        reviewReminderScheduler: SystemReviewReminderScheduler()
    )

    var body: some Scene {
        MenuBarExtra("iTime", systemImage: "clock.badge.checkmark") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("概览", id: "overview") {
            OverviewWindowView(model: model)
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowResizability(.contentSize)

        Window(AIConversationWindowCopy.title, id: AIConversationWindowView.windowID) {
            AIConversationWindowView(model: model)
                .frame(minWidth: 620, minHeight: 540)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(model: model)
                .frame(
                    minWidth: SettingsLayout.minimumWindowWidth,
                    minHeight: SettingsLayout.minimumWindowHeight
                )
        }
        .defaultSize(
            width: SettingsLayout.defaultWindowWidth,
            height: SettingsLayout.defaultWindowHeight
        )
    }
}
