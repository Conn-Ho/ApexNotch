import SwiftUI

// MARK: - Effect Style

enum NotchEffectStyle: String, CaseIterable, Identifiable {
    case sweep   = "Sweep"
    case aurora  = "Aurora"
    case breathe = "Breathe"
    case rainbow = "Rainbow"
    case neon    = "Neon"
    case sparkle = "Sparkle"
    case halo    = "Halo"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sweep:   "arrow.clockwise.circle.fill"
        case .aurora:  "aqi.medium"
        case .breathe: "waveform.path.ecg"
        case .rainbow: "rainbow"
        case .neon:    "bolt.fill"
        case .sparkle: "sparkles"
        case .halo:    "circle.dashed"
        }
    }
}

// MARK: - Effect Settings (persisted via UserDefaults)

@Observable
final class EffectSettings {

    var style: NotchEffectStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "effect.style") }
    }
    /// 0.0 – 1.0
    var intensity: Double {
        didSet { UserDefaults.standard.set(intensity, forKey: "effect.intensity") }
    }
    /// 0.25 – 2.0
    var speed: Double {
        didSet { UserDefaults.standard.set(speed, forKey: "effect.speed") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "effect.style") ?? ""
        style     = NotchEffectStyle(rawValue: raw) ?? .sweep
        let i     = UserDefaults.standard.double(forKey: "effect.intensity")
        intensity = i == 0 ? 1.0 : i
        let s     = UserDefaults.standard.double(forKey: "effect.speed")
        speed     = s == 0 ? 1.0 : s
    }
}

// MARK: - NotchEffectBorder (dispatcher)

struct NotchEffectBorder: View {
    let topR: CGFloat
    let bottomR: CGFloat
    let color: Color
    let settings: EffectSettings

    var body: some View {
        switch settings.style {
        case .sweep:   SweepEffect  (topR: topR, bottomR: bottomR, color: color, settings: settings)
        case .aurora:  AuroraEffect (topR: topR, bottomR: bottomR, color: color, settings: settings)
        case .breathe: BreatheEffect(topR: topR, bottomR: bottomR, color: color, settings: settings)
        case .rainbow: RainbowEffect(topR: topR, bottomR: bottomR, settings: settings)
        case .neon:    NeonEffect   (topR: topR, bottomR: bottomR, color: color, settings: settings)
        case .sparkle: SparkleEffect(topR: topR, bottomR: bottomR, color: color, settings: settings)
        case .halo:    HaloEffect   (topR: topR, bottomR: bottomR, color: color, settings: settings)
        }
    }
}

// MARK: - Shared helpers

private extension View {
    /// Hides the 1 pt flush with the screen top to prevent glow bleeding above the bezel,
    /// while keeping the animation visible all the way around the notch corners.
    var topEdgeMasked: some View {
        self.mask(
            VStack(spacing: 0) {
                Color.clear.frame(height: 1)
                Color.white
            }
        )
    }
}

// MARK: - 1. Sweep  (rotating spotlight)

private struct SweepEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t   = tl.date.timeIntervalSinceReferenceDate
            let cyc = 2.0 / settings.speed
            let rot = (t.truncatingRemainder(dividingBy: cyc)) / cyc * 360
            let α   = settings.intensity

            NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: .clear,                   location: 0.00),
                            .init(color: color.opacity(0.30 * α),  location: 0.10),
                            .init(color: color.opacity(α),         location: 0.20),
                            .init(color: color.opacity(0.80 * α),  location: 0.30),
                            .init(color: color.opacity(0.30 * α),  location: 0.40),
                            .init(color: .clear,                   location: 0.55),
                            .init(color: .clear,                   location: 1.00),
                        ],
                        center: .center,
                        startAngle: .degrees(rot),
                        endAngle:   .degrees(rot + 360)
                    ),
                    lineWidth: 1.5
                )
                .shadow(color: color.opacity(0.70 * α), radius: 6)
                .shadow(color: color.opacity(0.35 * α), radius: 14)
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }
}

// MARK: - 2. Aurora  (northern-lights, multi-hue wave)

private struct AuroraEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let t  = tl.date.timeIntervalSinceReferenceDate * settings.speed * 0.18
            let α  = settings.intensity
            let rot = t * 55

            // Slowly shift multiple hue stops around the signal color
            let c0 = color.hueShifted(by: sin(t * 1.0) * 0.12)
            let c1 = color.hueShifted(by: sin(t * 1.4 + 1.0) * 0.20)
            let c2 = color.hueShifted(by: sin(t * 0.8 + 2.0) * 0.15)
            let c3 = color.hueShifted(by: sin(t * 1.2 + 0.5) * 0.25)

            NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: c0.opacity(0.20 * α), location: 0.00),
                            .init(color: c1.opacity(0.90 * α), location: 0.14),
                            .init(color: c2.opacity(0.55 * α), location: 0.28),
                            .init(color: c3.opacity(0.85 * α), location: 0.42),
                            .init(color: c0.opacity(0.50 * α), location: 0.56),
                            .init(color: c2.opacity(0.75 * α), location: 0.70),
                            .init(color: c1.opacity(0.30 * α), location: 0.85),
                            .init(color: c0.opacity(0.20 * α), location: 1.00),
                        ],
                        center: .center,
                        startAngle: .degrees(rot),
                        endAngle:   .degrees(rot + 360)
                    ),
                    lineWidth: 2
                )
                .shadow(color: color.opacity(0.50 * α), radius: 8)
                .shadow(color: color.opacity(0.25 * α), radius: 20)
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }
}

// MARK: - 3. Breathe  (pulsing glow, no sweep)

private struct BreatheEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let t      = tl.date.timeIntervalSinceReferenceDate
            let breath = (sin(t * .pi * settings.speed * 0.5) + 1) / 2  // 0..1
            let stroke = 0.20 + breath * 0.80
            let α      = settings.intensity

            NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                .stroke(color.opacity(stroke * α), lineWidth: 1.5)
                .shadow(color: color.opacity(breath * 0.80 * α), radius: 4  + breath * 10)
                .shadow(color: color.opacity(breath * 0.40 * α), radius: 10 + breath * 20)
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Rainbow  (full spectrum)

private struct RainbowEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let settings: EffectSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t   = tl.date.timeIntervalSinceReferenceDate
            let rot = (t * 45 * settings.speed).truncatingRemainder(dividingBy: 360)
            let α   = settings.intensity

            let stops: [Gradient.Stop] = stride(from: 0.0, through: 1.0, by: 1.0 / 6).map { loc in
                .init(color: Color(hue: loc, saturation: 1, brightness: 1).opacity(α), location: loc)
            }

            NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                .stroke(
                    AngularGradient(stops: stops, center: .center,
                                    startAngle: .degrees(rot), endAngle: .degrees(rot + 360)),
                    lineWidth: 1.5
                )
                .shadow(color: .white.opacity(0.30 * α), radius: 5)
                .shadow(color: .white.opacity(0.15 * α), radius: 14)
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }
}

// MARK: - 5. Neon  (fast sweep + flicker)

private struct NeonEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let t       = tl.date.timeIntervalSinceReferenceDate
            let sp      = settings.speed
            let α       = settings.intensity
            let phase   = (t * 1.5 * sp).truncatingRemainder(dividingBy: 1.0)
            let rot     = phase * 360
            // Flicker: product of two misaligned sines
            let flicker = 0.65 + 0.35 * sin(t * 17.3 * sp) * sin(t * 11.7 * sp)

            NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
                .stroke(
                    AngularGradient(
                        stops: [
                            .init(color: .clear,                              location: 0.00),
                            .init(color: color .opacity(0.40 * α * flicker),  location: 0.05),
                            .init(color: .white.opacity(0.95 * α * flicker),  location: 0.10),
                            .init(color: color .opacity(0.70 * α * flicker),  location: 0.16),
                            .init(color: .clear,                              location: 0.26),
                            .init(color: .clear,                              location: 1.00),
                        ],
                        center: .center,
                        startAngle: .degrees(rot),
                        endAngle:   .degrees(rot + 360)
                    ),
                    lineWidth: 2
                )
                .shadow(color: .white.opacity(0.60 * α * flicker), radius: 3)
                .shadow(color: color .opacity(0.80 * α * flicker), radius: 8)
                .shadow(color: color .opacity(0.40 * α * flicker), radius: 18)
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }
}

// MARK: - 6. Sparkle  (particle dots along border)

private struct SparkleEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings
    private let count = 18

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
            let t  = tl.date.timeIntervalSinceReferenceDate
            let sp = settings.speed
            let α  = settings.intensity

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ForEach(0..<count, id: \.self) { i in
                    let freq  = 1.0 + Double(i % 4) * 0.55
                    let phase = Double(i) / Double(count) * 2 * .pi
                    let life  = max(0.0, (sin(t * freq * sp + phase) + 1) / 2)
                    let pt    = perimeterPoint(i, count, w, h)
                    let r     = 1.0 + life * 2.5

                    Circle()
                        .fill(color)
                        .frame(width: r * 2, height: r * 2)
                        .shadow(color: color.opacity(0.90 * life * α), radius: 3)
                        .shadow(color: color.opacity(0.45 * life * α), radius: 8)
                        .opacity(life * α)
                        .position(pt)
                }
            }
        }
        .topEdgeMasked
        .allowsHitTesting(false)
    }

    private func perimeterPoint(_ i: Int, _ total: Int, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        let t        = Double(i) / Double(total)
        let flatX0   = topR + bottomR
        let flatX1   = w - topR - bottomR
        // Distribute: 15% left side (lower half), 70% bottom flat, 15% right side
        if t < 0.15 {
            let u = t / 0.15
            return CGPoint(x: topR, y: h / 2 + u * (h - bottomR - h / 2))
        } else if t < 0.85 {
            let u = (t - 0.15) / 0.70
            return CGPoint(x: flatX0 + u * (flatX1 - flatX0), y: h - 1)
        } else {
            let u = (t - 0.85) / 0.15
            return CGPoint(x: w - topR, y: h - bottomR - u * (h - bottomR - h / 2))
        }
    }
}

// MARK: - 7. Halo  (static soft glow)

private struct HaloEffect: View {
    let topR: CGFloat; let bottomR: CGFloat; let color: Color; let settings: EffectSettings

    var body: some View {
        NotchShape(topCornerRadius: topR, bottomCornerRadius: bottomR)
            .stroke(color.opacity(0.70 * settings.intensity), lineWidth: 1.5)
            .shadow(color: color.opacity(0.65 * settings.intensity), radius: 5)
            .shadow(color: color.opacity(0.35 * settings.intensity), radius: 14)
            .shadow(color: color.opacity(0.18 * settings.intensity), radius: 28)
            .topEdgeMasked
            .allowsHitTesting(false)
    }
}
