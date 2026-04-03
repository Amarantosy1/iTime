import SwiftUI

enum AppTheme {
    enum ForegroundRole: Equatable {
        case primary
        case secondary

        var color: Color {
            switch self {
            case .primary:
                .primary
            case .secondary:
                .secondary
            }
        }
    }

    struct BackgroundPalette: Equatable {
        let startHex: String
        let endHex: String
    }

    struct OverviewLegendStyle: Equatable {
        let swatchHex: String
        let titleRole: ForegroundRole
        let shareRole: ForegroundRole
        let durationRole: ForegroundRole
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
            BackgroundPalette(startHex: "#202124", endHex: "#2A2B2F")
        default:
            BackgroundPalette(startHex: "#ECECE8", endHex: "#E1E1DC")
        }
    }

    static func overviewBackgroundGradient(for colorScheme: ColorScheme) -> BackgroundGradient {
        BackgroundGradient(palette: overviewBackgroundPalette(for: colorScheme))
    }

    static func overviewLegendStyle(for accentHex: String) -> OverviewLegendStyle {
        OverviewLegendStyle(
            swatchHex: accentHex,
            titleRole: .primary,
            shareRole: .primary,
            durationRole: .secondary
        )
    }
}
