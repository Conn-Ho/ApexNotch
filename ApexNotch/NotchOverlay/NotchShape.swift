import SwiftUI

// MARK: - NotchShape
// Single unified shape covering the notch + wings.
// topCornerRadius  — inward curves at top (matches physical notch corners: ~6pt)
// bottomCornerRadius — outward curves at bottom of the panel
// Based on DynamicNotchKit / AgentNotch approach.

struct NotchShape: Shape {
    var topCornerRadius:    CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius    = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tr = topCornerRadius
        let br = bottomCornerRadius

        // Top-left: inward quadratic curve
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to:      CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )

        // Left edge down to bottom-left curve
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))

        // Bottom-left: outward quadratic curve
        p.addQuadCurve(
            to:      CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr,      y: rect.maxY)
        )

        // Bottom edge
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))

        // Bottom-right: outward quadratic curve
        p.addQuadCurve(
            to:      CGPoint(x: rect.maxX - tr,       y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr,       y: rect.maxY)
        )

        // Right edge up to top-right curve
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))

        // Top-right: inward quadratic curve
        p.addQuadCurve(
            to:      CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )

        // Top edge back
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return p
    }
}

// MARK: - ToolPillShape (capsule for tool name pill)

struct ToolPillShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.height / 2)
    }
}
