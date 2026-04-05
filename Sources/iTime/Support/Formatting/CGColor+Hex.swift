#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CoreGraphics

extension CGColor {
    var hexString: String {
        #if canImport(AppKit)
        guard let color = NSColor(cgColor: self)?.usingColorSpace(.deviceRGB) else {
            return "#8A8A8A"
        }

        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
        #elseif canImport(UIKit)
        guard let color = UIColor(cgColor: self).cgColor.components else {
            return "#8A8A8A"
        }
        let r = Int(((color.count > 0 ? color[0] : 0) * 255).rounded())
        let g = Int(((color.count > 1 ? color[1] : 0) * 255).rounded())
        let b = Int(((color.count > 2 ? color[2] : 0) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#8A8A8A"
        #endif
    }
}
