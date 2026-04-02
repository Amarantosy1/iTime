import AppKit

extension CGColor {
    var hexString: String {
        guard let color = NSColor(cgColor: self)?.usingColorSpace(.deviceRGB) else {
            return "#8A8A8A"
        }

        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
