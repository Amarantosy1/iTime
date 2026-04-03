import SwiftUI

enum AppTheme {
    enum ForegroundRole: Equatable {
        case primary
        case secondary
        case tertiary

        var color: Color {
            switch self {
            case .primary:
                .primary
            case .secondary:
                .secondary
            case .tertiary:
                .secondary.opacity(0.6)
            }
        }
    }

    struct BackgroundPalette: Equatable {
        let startHex: String
        let endHex: String
        let accentHex: String
    }

    struct OverviewLegendStyle: Equatable {
        let swatchHex: String
        let titleRole: ForegroundRole
        let shareRole: ForegroundRole
        let durationRole: ForegroundRole
    }

    struct BackgroundGradient: View {
        let palette: BackgroundPalette
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            ZStack {
                // Base Gradient
                LinearGradient(
                    colors: [Color(hex: palette.startHex), Color(hex: palette.endHex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Subtle Mesh/Vibrancy Overlay
                if #available(macOS 15.0, *) {
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5, 0.5], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: [
                            Color(hex: palette.startHex), Color(hex: palette.startHex), Color(hex: palette.accentHex).opacity(0.15),
                            Color(hex: palette.startHex), Color(hex: palette.accentHex).opacity(0.1), Color(hex: palette.endHex),
                            Color(hex: palette.accentHex).opacity(0.2), Color(hex: palette.endHex), Color(hex: palette.endHex)
                        ]
                    )
                    .opacity(colorScheme == .dark ? 0.3 : 0.15)
                    .ignoresSafeArea()
                } else {
                    Circle()
                        .fill(Color(hex: palette.accentHex).opacity(0.15))
                        .frame(width: 600, height: 600)
                        .blur(radius: 100)
                        .offset(x: 200, y: -200)
                }
            }
        }
    }

    static func overviewBackgroundPalette(for colorScheme: ColorScheme) -> BackgroundPalette {
        switch colorScheme {
        case .dark:
            BackgroundPalette(
                startHex: "#1C1C1E",
                endHex: "#0A0A0B",
                accentHex: "#5E5CE6"
            )
        default:
            BackgroundPalette(
                startHex: "#F2F2F7",
                endHex: "#E5E5EA",
                accentHex: "#007AFF"
            )
        }
    }

    static func overviewBackgroundGradient(for colorScheme: ColorScheme) -> some View {
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

    static let cardCornerRadius: CGFloat = 22
    static let cardPadding: CGFloat = 18
}

extension View {
    func glassCardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
