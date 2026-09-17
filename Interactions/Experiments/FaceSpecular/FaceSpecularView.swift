import SwiftUI

/// Brushed metal disc whose specular highlight follows TrueDepth eye / head position.
struct FaceSpecularView: View {
    @StateObject private var model = FaceSpecularModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { _ in
            let offset = model.offset
            ZStack {
                LabPalette.studio.ignoresSafeArea()
                Canvas { context, size in
                    FaceSpecularRenderer.draw(in: &context, size: size, offset: offset)
                }
                .accessibilityLabel("Brushed metal disc")
                .accessibilityValue(model.faceTracking ? "Face tracking" : "Tilt")
                .accessibilityHint(hint)

                LabHintOverlay(text: hint)
            }
            .onAppear { model.start() }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }

    private var hint: String {
        model.faceTracking ? "Look." : "Tilt."
    }
}

@MainActor
final class FaceSpecularModel: ObservableObject {
    @Published var offset = CGSize.zero
    @Published var faceTracking = false

    private let face = FaceTrackingSource()
    private let motion = DeviceMotionSource()
    private let ticker = FrameTicker()
    private var displayed = CGSize.zero

    func start() {
        face.start()
        motion.start()
        ticker.onTick = { [weak self] _ in self?.step() }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        face.stop()
        motion.stop()
    }

    private func step() {
        let tracking = face.isTracking
        if tracking != faceTracking { faceTracking = tracking }
        let target: CGSize
        if tracking {
            target = face.offset
        } else {
            let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
            target = CGSize(width: a.dx * 0.85, height: (a.dy - 1) * 0.55)
        }
        displayed.width += (target.width - displayed.width) * 0.2
        displayed.height += (target.height - displayed.height) * 0.2
        if hypot(displayed.width - offset.width, displayed.height - offset.height) > 0.0008 {
            offset = displayed
        }
    }
}

private enum FaceSpecularRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, offset: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius = min(size.width, size.height) * 0.32
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        context.fill(
            Path(ellipseIn: CGRect(x: 18, y: 96, width: size.width - 36, height: size.height - 180)),
            with: .color(Color(red: 0.09, green: 0.08, blue: 0.08))
        )

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius + 12, y: center.y - radius + 18, width: radius * 2, height: radius * 2)),
            with: .color(.black.opacity(0.42))
        )

        context.drawLayer { inner in
            inner.clip(to: disc)
            inner.fill(disc, with: .color(Color(white: 0.14)))
            inner.fill(
                Path(ellipseIn: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 0.2, width: radius * 1.1, height: radius * 1.15)),
                with: .color(Color.black.opacity(0.18))
            )
            for i in stride(from: -radius, through: radius, by: 3.6) {
                var streak = Path()
                let y = center.y + i
                streak.move(to: CGPoint(x: center.x - radius * 0.94, y: y))
                streak.addLine(to: CGPoint(x: center.x + radius * 0.94, y: y + i * 0.016))
                inner.stroke(streak, with: .color(Color.white.opacity(0.038 + abs(Double(i / radius)) * 0.012)), lineWidth: 0.9)
            }
            let hx = center.x + offset.width * radius * 0.55
            let hy = center.y + offset.height * radius * 0.55
            inner.fill(
                Path(ellipseIn: CGRect(x: hx - radius * 0.72, y: hy - radius * 0.26, width: radius * 1.44, height: radius * 0.52)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.20), .clear]),
                    center: CGPoint(x: hx, y: hy),
                    startRadius: 2,
                    endRadius: radius * 0.88
                )
            )
            inner.fill(
                Path(ellipseIn: CGRect(x: hx - radius * 0.48, y: hy - radius * 0.36, width: radius * 0.96, height: radius * 0.72)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.92), Color.white.opacity(0.14), .clear]),
                    center: CGPoint(x: hx, y: hy),
                    startRadius: 2.5,
                    endRadius: radius * 0.60
                )
            )
            inner.fill(
                Path(ellipseIn: CGRect(x: hx - 7, y: hy - 9, width: 12, height: 9)),
                with: .color(.white.opacity(0.96))
            )
            var rim = Path()
            rim.addArc(center: center, radius: radius * 0.92, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
            inner.stroke(rim, with: .color(.white.opacity(0.10)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        context.stroke(disc, with: .color(Color.white.opacity(0.16)), lineWidth: 1.3)
        let bezel = Path(ellipseIn: CGRect(x: center.x - radius - 7, y: center.y - radius - 7, width: (radius + 7) * 2, height: (radius + 7) * 2))
        context.stroke(bezel, with: .color(Color(white: 0.20)), lineWidth: 7)
        context.stroke(bezel, with: .color(Color.white.opacity(0.08)), lineWidth: 1.2)
        for a in [0.25, 0.75, 1.25, 1.75] {
            let sx = center.x + LabMath.cos(a * .pi) * (radius + 7)
            let sy = center.y + LabMath.sin(a * .pi) * (radius + 7)
            context.fill(Path(ellipseIn: CGRect(x: sx - 2.2, y: sy - 2.2, width: 4.4, height: 4.4)), with: .color(Color(white: 0.28)))
        }
    }
}

#Preview { FaceSpecularView() }
