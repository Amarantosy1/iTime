import SwiftUI
import UIKit

struct TagChip: View {
    let icon: String
    let text: String
    var theme: AppDisplayTheme = .flowing

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                if theme == .pure {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                } else {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)
                    }
                }
            }
    }
}

struct MagazineDivider: View {
    var body: some View {
        Rectangle()
            .frame(height: 0.5)
            .foregroundStyle(.primary.opacity(0.12))
    }
}

struct QuoteBlock: View {
    let content: String
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor)
                .frame(width: 3)
            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NumberedCard: View {
    let number: Int
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", number))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Text(content)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

struct MagazineGlassCard<Content: View>: View {
    let theme: AppDisplayTheme
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(theme: AppDisplayTheme = .flowing, padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.theme = theme
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if theme == .pure {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                } else {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.clear)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .overlay {
                if theme == .pure {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 0.5)
                }
            }
            .shadow(color: theme == .flowing ? .black.opacity(0.08) : .clear, radius: 10, x: 0, y: 5)
    }
}

struct iOSThemeBackground: View {
    let theme: AppDisplayTheme
    let accentColor: Color
    var customImageName: String? = nil
    var customScale: Double = 1.12
    var customOffsetX: Double = 0
    var customOffsetY: Double = 0
    var starCount: Int = 150
    var twinkleBoost: Double = 1.5
    var meteorCount: Int = 4

    var body: some View {
        if theme == .pure {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        } else if theme == .custom {
            if let image = CustomThemeBackgroundImageStore.loadImage(named: customImageName) {
                CustomImageThemeBackground(
                    image: image,
                    scale: customScale,
                    offsetX: customOffsetX,
                    offsetY: customOffsetY
                )
            } else {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
        } else {
            StarrySkyBackground(
                accentColor: accentColor,
                starCount: starCount,
                twinkleBoost: twinkleBoost,
                meteorCount: meteorCount
            )
        }
    }
}

private struct CustomImageThemeBackground: View {
    let image: UIImage
    let scale: Double
    let offsetX: Double
    let offsetY: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedScale = min(max(scale, 1.0), 4.0)
            let clampedOffsetX = min(max(offsetX, -1.0), 1.0)
            let clampedOffsetY = min(max(offsetY, -1.0), 1.0)

            let x = clampedOffsetX * proxy.size.width * 0.35
            let y = clampedOffsetY * proxy.size.height * 0.35

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(clampedScale)
                .offset(x: x, y: y)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.2), .clear, .black.opacity(0.24)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
    }
}

enum CustomThemeBackgroundImageStore {
    private static let directoryName = "CustomThemeBackground"

    static func saveImageData(_ data: Data, replacing oldImageName: String?) throws -> String {
        guard let image = UIImage(data: data), let jpegData = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "iTime.CustomTheme", code: 1, userInfo: [NSLocalizedDescriptionKey: "图片格式不支持"])
        }

        let folderURL = try ensureFolderURL()
        let imageName = "custom-theme-\(UUID().uuidString.lowercased()).jpg"
        let destinationURL = folderURL.appendingPathComponent(imageName)
        try jpegData.write(to: destinationURL, options: .atomic)

        if let oldImageName, oldImageName != imageName {
            removeImage(named: oldImageName)
        }

        return imageName
    }

    static func loadImage(named imageName: String?) -> UIImage? {
        guard let imageName, let imageURL = imageURL(named: imageName) else {
            return nil
        }
        guard let data = try? Data(contentsOf: imageURL) else {
            return nil
        }
        return UIImage(data: data)
    }

    static func removeImage(named imageName: String?) {
        guard let imageName, let imageURL = imageURL(named: imageName) else {
            return
        }
        try? FileManager.default.removeItem(at: imageURL)
    }

    private static func imageURL(named imageName: String) -> URL? {
        guard !imageName.isEmpty else {
            return nil
        }
        guard let folderURL = try? ensureFolderURL() else {
            return nil
        }
        return folderURL.appendingPathComponent(imageName)
    }

    private static func ensureFolderURL() throws -> URL {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folderURL = appSupportURL.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: folderURL.path()) {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL
    }
}

struct StarrySkyBackground: View {
    let accentColor: Color
    var starCount: Int = 150
    var twinkleBoost: Double = 1.5
    var meteorCount: Int = 4

    private var stars: [SkyStar] {
        (0..<starCount).map { index in
            SkyStar(
                x: Self.seed(index, salt: 0.11),
                y: Self.seed(index, salt: 0.23),
                size: 0.7 + Self.seed(index, salt: 0.37) * 2.4,
                baseOpacity: 0.2 + Self.seed(index, salt: 0.41) * 0.65,
                speed: 0.8 + Self.seed(index, salt: 0.53) * 3.0,
                phase: Self.seed(index, salt: 0.67) * .pi * 2
            )
        }
    }

    private var meteors: [SkyMeteor] {
        (0..<meteorCount).map { index in
            SkyMeteor(
                laneY: 0.03 + Self.seed(index, salt: 1.01) * 0.45,
                length: 70 + Self.seed(index, salt: 1.13) * 100,
                width: 1.0 + Self.seed(index, salt: 1.19) * 1.6,
                speed: 0.04 + Self.seed(index, salt: 1.31) * 0.06,
                phase: Self.seed(index, salt: 1.49),
                opacity: 0.4 + Self.seed(index, salt: 1.61) * 0.45
            )
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#030409"), Color(hex: "#090D1B"), Color(hex: "#020204")],
                startPoint: .top,
                endPoint: .bottom
            )

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                let time = context.date.timeIntervalSinceReferenceDate

                Canvas { canvas, size in
                    drawStars(on: canvas, size: size, time: time)
                    drawMeteors(on: canvas, size: size, time: time)
                }
                .blur(radius: 0.2)
            }

            Circle()
                .fill(accentColor.opacity(0.16))
                .frame(width: 380, height: 380)
                .blur(radius: 58)
                .offset(x: 180, y: -260)

            Circle()
                .fill(accentColor.opacity(0.11))
                .frame(width: 300, height: 300)
                .blur(radius: 64)
                .offset(x: -180, y: 330)

            if #available(iOS 26, *) {
                LinearGradient(
                    colors: [accentColor.opacity(0.05), .clear, accentColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawStars(on canvas: GraphicsContext, size: CGSize, time: TimeInterval) {
        for star in stars {
            let pulse = (sin((time * star.speed) + star.phase) + 1) / 2
            let twinkle = 0.25 + 0.75 * pow(pulse, twinkleBoost)
            let opacity = star.baseOpacity * twinkle

            let x = star.x * size.width
            let y = star.y * size.height
            let rect = CGRect(x: x, y: y, width: star.size, height: star.size)
            canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }

    private func drawMeteors(on canvas: GraphicsContext, size: CGSize, time: TimeInterval) {
        let activeStart = 0.06
        let activeEnd = 0.98

        for meteor in meteors {
            var cycle = (time * meteor.speed) + meteor.phase
            cycle -= floor(cycle)

            if cycle < activeStart || cycle > activeEnd {
                continue
            }

            let progress = (cycle - activeStart) / (activeEnd - activeStart)
            let fadeIn = smoothstep(edge0: 0.0, edge1: 0.14, x: progress)
            let fadeOut = 1.0 - smoothstep(edge0: 0.84, edge1: 1.0, x: progress)
            let alpha = max(0, min(1, fadeIn * fadeOut))

            let headX = (progress * 1.35 - 0.2) * size.width
            let headY = (meteor.laneY + progress * 0.35) * size.height

            let visibleLength = meteor.length * (0.55 + 0.45 * alpha)
            let tailX = headX - visibleLength
            let tailY = headY - visibleLength * 0.38

            let head = CGPoint(x: headX, y: headY)
            let tail = CGPoint(x: tailX, y: tailY)

            var path = Path()
            path.move(to: head)
            path.addLine(to: tail)

            canvas.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(meteor.opacity * alpha), .white.opacity(0.0)]),
                    startPoint: head,
                    endPoint: tail
                ),
                lineWidth: meteor.width
            )

            let headRect = CGRect(x: headX - 1.2, y: headY - 1.2, width: 2.4, height: 2.4)
            canvas.fill(
                Path(ellipseIn: headRect),
                with: .color(.white.opacity(min(1.0, (meteor.opacity + 0.2) * alpha)))
            )
        }
    }

    private func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        guard edge0 != edge1 else { return x >= edge1 ? 1 : 0 }
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func seed(_ index: Int, salt: Double) -> Double {
        let value = sin((Double(index) + 1) * 12.9898 + salt * 78.233) * 43758.5453
        return value - floor(value)
    }
}

private struct SkyStar {
    let x: Double
    let y: Double
    let size: Double
    let baseOpacity: Double
    let speed: Double
    let phase: Double
}

private struct SkyMeteor {
    let laneY: Double
    let length: Double
    let width: Double
    let speed: Double
    let phase: Double
    let opacity: Double
}

extension Color {
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard let value = Int(sanitized, radix: 16) else {
            self = .accentColor
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self = Color(red: red, green: green, blue: blue)
    }
}
