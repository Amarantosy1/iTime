import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset

    var body: some View {
        Picker("范围", selection: $selection) {
            ForEach(TimeRangePreset.runtimeCases, id: \.self) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
