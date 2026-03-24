import SwiftUI

struct NotchOverlayView: View {
    let signal: AppSignal

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * .pi * 2 * signal.pulseSpeed) + 1) / 2
            GlowCanvas(color: signal.color, pulse: pulse)
        }
        .ignoresSafeArea()
    }
}

private struct GlowCanvas: View {
    let color: Color
    let pulse: Double

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            // Outer soft glow
            let outerRect = CGRect(x: cx - 130, y: -20, width: 260, height: 60)
            ctx.fill(
                Path(ellipseIn: outerRect),
                with: .color(color.opacity(0.18 * pulse))
            )
            // Mid glow
            let midRect = CGRect(x: cx - 90, y: -10, width: 180, height: 46)
            ctx.fill(
                Path(ellipseIn: midRect),
                with: .color(color.opacity(0.32 * pulse))
            )
            // Core bright glow
            let coreRect = CGRect(x: cx - 55, y: -4, width: 110, height: 30)
            ctx.fill(
                Path(ellipseIn: coreRect),
                with: .color(color.opacity(0.55 * pulse))
            )
            // Hot center
            let hotRect = CGRect(x: cx - 25, y: 0, width: 50, height: 16)
            ctx.fill(
                Path(ellipseIn: hotRect),
                with: .color(color.opacity(0.75 * pulse))
            )
        }
        .drawingGroup()
    }
}
