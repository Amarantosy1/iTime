import Charts
import SwiftUI

struct OverviewTrendChartView: View {
    let overview: TimeOverview

    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("每日趋势")
                    .font(.headline)

                Chart(overview.dailyDurations) { day in
                    BarMark(
                        x: .value("日期", day.date, unit: .day),
                        y: .value("时长", day.totalDuration / 3600)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 220)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
