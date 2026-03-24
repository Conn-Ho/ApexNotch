import SwiftUI

// MARK: - NotchBgShape
// Rounded rectangle with per-corner radius control.
// Used as the background for each notch wing (left and right).
// Bottom corners are fully rounded; top corners flush against the menu bar.

struct NotchBgShape: Shape {
    var cornerRadius: CGFloat = 12
    /// When true, rounds only the bottom corners (flush to menu bar on top).
    var bottomCornersOnly: Bool = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)

        if bottomCornersOnly {
            // Top-left → top-right: straight
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            // Top-right corner: sharp
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            // Bottom-right corner: rounded
            path.addArc(
                center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                radius: r,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            // Bottom-left corner: rounded
            path.addArc(
                center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                radius: r,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            // Left edge back to top-left
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.closeSubpath()
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        }

        return path
    }
}

// MARK: - ToolPillShape
// A simple pill / capsule shape used for the tool name display inside a notch wing.

struct ToolPillShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.height / 2)
    }
}
