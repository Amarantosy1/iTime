import SwiftUI

struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RangePicker(selection: $model.preferences.selectedRange)
                .onChange(of: model.preferences.selectedRange) { _, newValue in
                    Task { await model.setRange(newValue) }
                }

            switch model.authorizationState {
            case .authorized:
                authorizedContent
            default:
                AuthorizationStateView(state: model.authorizationState) {
                    Task { await model.requestAccessIfNeeded() }
                }
            }

            Button("Open Details") {
                openWindow(id: "overview")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 340)
        .task {
            await model.refresh()
        }
    }

    @ViewBuilder
    private var authorizedContent: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tracked time")
                    .font(.headline)

                Text(model.overview?.totalDuration.formattedDuration ?? "0m")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                if let overview = model.overview, !overview.buckets.isEmpty {
                    ForEach(overview.buckets.prefix(3)) { bucket in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: bucket.colorHex))
                                .frame(width: 8, height: 8)
                            Text(bucket.name)
                            Spacer()
                            Text(bucket.totalDuration.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("No events in this range.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
