import SwiftUI

struct BreathFireView: View {
    @StateObject private var simulation = BreathFireSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let frame = simulation.frame

        Canvas { context, size in
            BreathFireRenderer.draw(in: &context, size: size, frame: frame)
        }
        .animation(nil, value: frame.time)
        .animation(nil, value: frame.heat)
        .accessibilityLabel("Fire")
        .accessibilityValue(valueLabel(frame))
        .accessibilityHint("Blow into the microphone")
        .onAppear { simulation.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                simulation.start()
            default:
                simulation.stop()
            }
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }

    private func valueLabel(_ frame: BreathFireFrame) -> String {
        if frame.denied { return "Microphone off" }
        return "\(Int((frame.heat * 100).rounded())) percent"
    }
}

/// Nonisolated draw. Callers snapshot MainActor heat before entering Canvas.
private enum BreathFireRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, frame: BreathFireFrame) {
        let heat = max(0, min(1, frame.heat))
        let hearth = CGPoint(x: size.width * 0.5, y: size.height * 0.73)
        let maxHeight = size.height * 0.50
        let maxWidth = size.width * 0.42
        stain(in: &context, hearth: hearth, width: maxWidth, heat: heat)
        coals(in: &context, hearth: hearth, width: maxWidth, heat: heat)
        flames(in: &context, hearth: hearth, width: maxWidth, height: maxHeight, time: frame.time, heat: heat)
        sparks(in: &context, hearth: hearth, width: maxWidth, height: maxHeight, frame: frame, heat: heat)
    }

    private static func stain(
        in context: inout GraphicsContext,
        hearth: CGPoint,
        width: CGFloat,
        heat: CGFloat
    ) {
        let radius = mix(width * 0.18, width * 1.15, heat)
        let rect = CGRect(
            x: hearth.x - radius,
            y: hearth.y - radius * 1.25,
            width: radius * 2,
            height: radius * 2.15
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    rgb(1.00, 0.42, 0.06).opacity(mix(0.04, 0.28, heat)),
                    rgb(1.00, 0.42, 0.06).opacity(0)
                ]),
                center: hearth,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private static func coals(
        in context: inout GraphicsContext,
        hearth: CGPoint,
        width: CGFloat,
        heat: CGFloat
    ) {
        let bedW = mix(width * 0.28, width * 0.72, heat)
        context.fill(
            Path(ellipseIn: CGRect(x: hearth.x - bedW / 2, y: hearth.y - 5, width: bedW, height: 12)),
            with: .color(rgb(0.22, 0.08, 0.04).opacity(0.55 + 0.35 * heat))
        )
        for i in 0..<5 {
            let t = CGFloat(i) / 4
            let x = hearth.x + (t - 0.5) * bedW * 0.72
            let r = mix(3.2, 7.5, heat) * (0.75 + 0.25 * sin(t * 6))
            context.fill(
                Path(ellipseIn: CGRect(x: x - r / 2, y: hearth.y - r * 0.35, width: r, height: r * 0.7)),
                with: .color(rgb(0.55 + 0.45 * heat, 0.10 + 0.28 * heat, 0.03).opacity(0.4 + 0.6 * heat))
            )
        }
    }

    private static func flames(
        in context: inout GraphicsContext,
        hearth: CGPoint,
        width: CGFloat,
        height: CGFloat,
        time: CGFloat,
        heat: CGFloat
    ) {
        guard heat > 0.012 else { return }

        let flicker = 0.86 + 0.14 * sin(time * 10.6) * sin(time * 6.4 + 0.5)
        let lean = sin(time * 1.7) * mix(0.01, 0.10, heat)
        let h = height * heat * flicker
        let w = width * mix(0.34, 1.0, heat)

        var local = context
        local.translateBy(x: hearth.x, y: hearth.y)
        local.rotate(by: .radians(lean))

        fillFlame(in: &local, width: w * 1.55, height: h * 1.06, color: rgb(0.90, 0.16, 0.03).opacity(mix(0.12, 0.40, heat)))
        fillFlame(in: &local, width: w * 1.12, height: h, color: rgb(1.00, 0.38, 0.05).opacity(0.94))
        fillFlame(in: &local, width: w * 0.72, height: h * 0.80, color: rgb(1.00, 0.72, 0.14).opacity(0.96))
        fillFlame(in: &local, width: w * 0.36, height: h * 0.46, color: rgb(1.00, 0.96, 0.78).opacity(0.95))

        let coreH = mix(6, 22, heat)
        local.fill(
            Path(ellipseIn: CGRect(x: -w * 0.08, y: -coreH * 0.55, width: w * 0.16, height: coreH)),
            with: .color(rgb(0.70, 0.86, 1.00).opacity(mix(0.05, 0.62, heat)))
        )

        // Side tongues so the fade reads as a living fire, not a scale slider.
        for side in [-1.0, 1.0] {
            let phase = side > 0 ? 0.9 : 2.1
            let tongueH = h * (0.42 + 0.10 * sin(time * 8.0 + phase))
            let tongueW = w * 0.38
            var tongue = context
            tongue.translateBy(x: hearth.x + CGFloat(side) * w * 0.28, y: hearth.y + 2)
            tongue.rotate(by: .radians(CGFloat(side) * 0.18 + lean * 0.4))
            fillFlame(in: &tongue, width: tongueW, height: tongueH, color: rgb(1.00, 0.45, 0.06).opacity(0.72 * heat))
            fillFlame(in: &tongue, width: tongueW * 0.48, height: tongueH * 0.62, color: rgb(1.00, 0.82, 0.22).opacity(0.7 * heat))
        }
    }

    private static func sparks(
        in context: inout GraphicsContext,
        hearth: CGPoint,
        width: CGFloat,
        height: CGFloat,
        frame: BreathFireFrame,
        heat: CGFloat
    ) {
        let rise = mix(height * 0.2, height * 1.05, heat)
        let spread = width * 0.55
        for spark in frame.sparks {
            let x = hearth.x + spark.x * spread
            let y = hearth.y - spark.y * rise
            let w = spark.size
            let h = w * mix(1.3, 2.6, heat)
            let color = rgb(1.0, 0.38 + spark.warmth * 0.5, 0.06)
            context.fill(
                Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                with: .color(color.opacity(0.2 + 0.8 * spark.life))
            )
        }
    }

    private static func fillFlame(in context: inout GraphicsContext, width: CGFloat, height: CGFloat, color: Color) {
        context.fill(flamePath(width: width, height: height), with: .color(color))
    }

    private static func flamePath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let tip = CGPoint(x: 0, y: -height)
        let left = CGPoint(x: -width * 0.5, y: -height * 0.22)
        let right = CGPoint(x: width * 0.5, y: -height * 0.22)
        let bottom = CGPoint(x: 0, y: width * 0.10)
        path.move(to: tip)
        path.addQuadCurve(to: left, control: CGPoint(x: -width * 0.58, y: -height * 0.58))
        path.addQuadCurve(to: bottom, control: CGPoint(x: -width * 0.40, y: width * 0.28))
        path.addQuadCurve(to: right, control: CGPoint(x: width * 0.40, y: width * 0.28))
        path.addQuadCurve(to: tip, control: CGPoint(x: width * 0.58, y: -height * 0.58))
        path.closeSubpath()
        return path
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    private static func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

#Preview {
    BreathFireView()
}
