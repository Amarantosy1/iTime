import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset

    var body: some View {
        Picker("Range", selection: $selection) {
            ForEach(TimeRangePreset.allCases, id: \.self) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
}
