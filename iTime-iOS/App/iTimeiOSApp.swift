import SwiftUI

@main
struct iTimeiOSApp: App {
    @State private var model: AppModel

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
        WindowGroup {
            iTimeIOSRootView(model: model)
        }
    }
}
