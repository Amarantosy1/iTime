import SwiftUI

struct iTimeIOSRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        TabView {
            iOSOverviewView(model: model)
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }

            iOSConversationView(model: model)
                .tabItem {
                    Label("复盘", systemImage: "message")
                }

            iOSSettingsView(model: model)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .task {
            await model.requestAccessIfNeeded()
        }
    }
}
