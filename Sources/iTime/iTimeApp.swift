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
        reviewReminderScheduler: SystemReviewReminderScheduler(),
        syncCoordinator: nil
    )

    init() {
        let preferences = UserPreferences(storage: .standard)
        let syncAdapter = SyncPersistenceAdapter(
            archiveStore: FileAIConversationArchiveStore(
                directoryURL: FileAIConversationArchiveStore.defaultDirectoryURL
            ),
            preferences: preferences,
            apiKeyStore: KeychainAIAPIKeyStore()
        )
        _model = State(
            initialValue: AppModel(
                service: EventKitCalendarAccessService(),
                preferences: preferences,
                reviewReminderScheduler: SystemReviewReminderScheduler(),
                syncCoordinator: SyncCoordinator(
                    transport: MultipeerTransportService(serviceType: "itime-sync"),
                    adapter: syncAdapter
                )
            )
        )
    }

    var body: some Scene {
        MenuBarExtra("iTime", systemImage: "clock.badge.checkmark") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("概览", id: OverviewWindowView.windowID) {
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
