import SwiftUI

struct OverviewWindowView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                RangePicker(selection: $model.preferences.selectedRange)
                    .onChange(of: model.preferences.selectedRange) { _, newValue in
                        Task { await model.setRange(newValue) }
                    }

                if model.authorizationState == .authorized {
                    overviewContent
                } else {
                    AuthorizationStateView(state: model.authorizationState) {
                        Task { await model.requestAccessIfNeeded() }
                    }
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.9, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where is my time?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("A calendar-based breakdown of your scheduled time.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var overviewContent: some View {
        if let overview = model.overview, !overview.buckets.isEmpty {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text(overview.totalDuration.formattedDuration)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))

                    OverviewChartView(overview: overview)

                    ForEach(overview.buckets) { bucket in
                        HStack {
                            Label(bucket.name, systemImage: "circle.fill")
                                .foregroundStyle(Color(hex: bucket.colorHex))
                            Spacer()
                            Text(bucket.shareText)
                                .fontWeight(.semibold)
                            Text(bucket.totalDuration.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            LiquidGlassCard {
                Text("No events available for this time range.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
