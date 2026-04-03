import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset
    let ranges: [TimeRangePreset]

    init(selection: Binding<TimeRangePreset>, ranges: [TimeRangePreset] = TimeRangePreset.menuCases) {
        self._selection = selection
        self.ranges = ranges
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ranges, id: \.self) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == range ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .frame(minWidth: 52)
                        .background {
                            if selection == range {
                                if #available(macOS 26, *) {
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.regular, in: Capsule())
                                } else {
                                    Capsule()
                                        .fill(.regularMaterial)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
