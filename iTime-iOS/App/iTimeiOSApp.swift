import SwiftUI

@main
struct iTimeiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
                .task {
                    await synchronizeDiscovery(with: scenePhase)
                }
                .onChange(of: scenePhase) { _, phase in
                    Task {
                        await synchronizeDiscovery(with: phase)
                    }
                }
        }
    }

    private func synchronizeDiscovery(with phase: ScenePhase) async {
        switch phase {
        case .active:
            await model.startDeviceDiscovery()
        case .inactive, .background:
            await model.stopDeviceDiscovery()
        @unknown default:
            await model.stopDeviceDiscovery()
        }
    }
}
