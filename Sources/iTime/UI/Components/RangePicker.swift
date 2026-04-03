import SwiftUI

struct RangePicker: View {
    @Binding var selection: TimeRangePreset
    let ranges: [TimeRangePreset]

    init(selection: Binding<TimeRangePreset>, ranges: [TimeRangePreset] = TimeRangePreset.menuCases) {
        self._selection = selection
        self.ranges = ranges
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ranges, id: \.self) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selection == range ? .primary : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selection == range {
                                if #available(macOS 26, *) {
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.regular, in: Capsule())
                                        .overlay {
                                            Capsule()
                                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                        }
                                } else {
                                    Capsule()
                                        .fill(.white.opacity(0.12))
                                }
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.05), lineWidth: 0.5)
        }
    }
}
