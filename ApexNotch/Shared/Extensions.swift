import SwiftUI
import AppKit

// MARK: - Color hex initializer (shared)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)          / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns a new Color with its hue rotated by `amount` (0.0–1.0 = full circle).
    func hueShifted(by amount: Double) -> Color {
        guard let ns = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        var newH = (Double(h) + amount).truncatingRemainder(dividingBy: 1.0)
        if newH < 0 { newH += 1.0 }
        return Color(hue: newH, saturation: Double(s), brightness: Double(b), opacity: Double(a))
    }
}
