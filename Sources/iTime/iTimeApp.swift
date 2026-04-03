import SwiftUI

@main
struct iTimeApp: App {
    @State private var model = AppModel(
        service: EventKitCalendarAccessService(),
        preferences: UserPreferences(storage: .standard)
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
        }
    }
}
