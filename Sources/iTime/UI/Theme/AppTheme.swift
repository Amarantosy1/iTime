import SwiftUI

enum AppTheme {
    struct BackgroundPalette: Equatable {
        let startHex: String
        let endHex: String
    }

    struct BackgroundGradient: Equatable {
        let palette: BackgroundPalette

        var linearGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: palette.startHex), Color(hex: palette.endHex)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func overviewBackgroundPalette(for colorScheme: ColorScheme) -> BackgroundPalette {
        switch colorScheme {
        case .dark:
            BackgroundPalette(startHex: "#111827", endHex: "#1F2937")
        default:
            BackgroundPalette(startHex: "#F2F7FF", endHex: "#E6F0FA")
        }
    }

    static func overviewBackgroundGradient(for colorScheme: ColorScheme) -> BackgroundGradient {
        BackgroundGradient(palette: overviewBackgroundPalette(for: colorScheme))
    }
}
