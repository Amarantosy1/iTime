import SwiftUI

struct iTimeIOSRootView: View {
    @Bindable var model: AppModel
    @State private var selectedTab: RootTab = .overview

    var body: some View {
        TabView(selection: $selectedTab) {
            iOSOverviewView(model: model)
                .tag(RootTab.overview)
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }

            iOSConversationView(model: model)
                .tag(RootTab.conversation)
                .tabItem {
                    Label("复盘", systemImage: "message")
                }

            iOSSettingsView(model: model)
                .tag(RootTab.settings)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(.accentColor)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .task {
            await model.requestAccessIfNeeded()
        }
    }
}

private enum RootTab {
    case overview
    case conversation
    case settings
}
