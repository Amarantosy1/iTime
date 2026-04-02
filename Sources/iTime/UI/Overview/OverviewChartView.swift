import Charts
import SwiftUI

struct OverviewChartView: View {
    let overview: TimeOverview

    var body: some View {
        Chart(overview.buckets) { bucket in
            SectorMark(
                angle: .value("Duration", bucket.totalDuration),
                innerRadius: .ratio(0.58),
                angularInset: 2
            )
            .foregroundStyle(Color(hex: bucket.colorHex))
        }
        .frame(height: 260)
    }
}
