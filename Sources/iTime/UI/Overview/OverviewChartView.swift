import Charts
import SwiftUI

struct OverviewChartView: View {
    let overview: TimeOverview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Chart(overview.buckets) { bucket in
                SectorMark(
                    angle: .value("时长", bucket.totalDuration),
                    innerRadius: .ratio(0.58),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: bucket.colorHex))
            }
            .frame(height: 260)

            OverviewBucketTable(overview: overview)
        }
    }
}
