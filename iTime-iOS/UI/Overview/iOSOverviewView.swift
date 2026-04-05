import SwiftUI

struct iOSOverviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section("概览") {
                    LabeledContent("统计周期", value: model.liveSelectedRange.title)
                    LabeledContent("总时长", value: (model.overview?.totalDuration ?? 0).formattedHours)
                    LabeledContent("事件数量", value: "\(model.overview?.totalEventCount ?? 0)")
                }

                if let overview = model.overview {
                    if overview.buckets.isEmpty {
                        Text("暂无可显示的数据")
                            .foregroundStyle(.secondary)
                    } else {
                        Section("时间分布") {
                            ForEach(overview.buckets) { bucket in
                                HStack {
                                    Text(bucket.name)
                                    Spacer()
                                    Text(bucket.totalDuration.formattedHours)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Text("请先授予日历权限")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("统计")
            .refreshable {
                await model.refresh()
            }
        }
    }
}

private extension TimeInterval {
    var formattedHours: String {
        let hours = self / 3600
        if hours < 1 {
            return "\(Int(self / 60)) 分钟"
        }
        return String(format: "%.1f 小时", hours)
    }
}
