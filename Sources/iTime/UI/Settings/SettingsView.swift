import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.authorizationState == .authorized {
                    calendarSelectionContent
                } else {
                    AuthorizationStateView(state: model.authorizationState) {
                        Task { await model.requestAccessIfNeeded() }
                    }
                }
            }
            .navigationTitle("设置")
        }
        .frame(width: 420, height: 360)
        .task {
            await model.refresh()
        }
    }

    private var calendarSelectionContent: some View {
        Form {
            Section("统计日历") {
                Text("选择要纳入统计的日历。")
                    .foregroundStyle(.secondary)

                if model.availableCalendars.isEmpty {
                    Text("当前没有可用日历。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.availableCalendars) { calendar in
                        Toggle(isOn: binding(for: calendar)) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: calendar.colorHex))
                                    .frame(width: 8, height: 8)
                                Text(calendar.name)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for calendar: CalendarSource) -> Binding<Bool> {
        Binding(
            get: { calendar.isSelected },
            set: { _ in
                Task { await model.toggleCalendarSelection(id: calendar.id) }
            }
        )
    }
}
