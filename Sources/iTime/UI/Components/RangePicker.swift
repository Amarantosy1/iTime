import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset
    let ranges: [TimeRangePreset]

    init(selection: Binding<TimeRangePreset>, ranges: [TimeRangePreset] = TimeRangePreset.menuCases) {
        self._selection = selection
        self.ranges = ranges
    }

    var body: some View {
        Picker("范围", selection: $selection) {
            ForEach(ranges, id: \.self) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
