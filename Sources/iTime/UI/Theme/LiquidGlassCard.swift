import SwiftUI

struct LiquidGlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                content
                    .padding(18)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
            } else {
                content
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }
}
