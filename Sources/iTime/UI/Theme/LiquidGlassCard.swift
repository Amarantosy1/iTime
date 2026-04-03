import SwiftUI

struct LiquidGlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content.glassCardStyle()
    }
}
