import SwiftUI

/// Brushed metal disc whose specular highlight follows TrueDepth eye / head position.
struct FaceSpecularView: View {
    @StateObject private var model = FaceSpecularModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { _ in
            let offset = model.offset
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
                Canvas { context, size in
                    FaceSpecularRenderer.draw(in: &context, size: size, offset: offset)
                }
                .accessibilityLabel("Brushed metal disc")
                .accessibilityHint(hint)

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: model.faceTracking ? "Face tracking" : "Tilt fallback")
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .allowsHitTesting(false)

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
        if model.faceTracking {
            "Move your head — the highlight follows your eyes"
        } else {
            "Tilt the phone — Face ID tracking unavailable"
        }
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
        faceTracking = face.isTracking
        let target: CGSize
        if face.isTracking {
            target = face.offset
        } else {
            let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
            target = CGSize(width: a.dx * 0.85, height: (a.dy - 1) * 0.55)
        }
        displayed.width += (target.width - displayed.width) * 0.2
        displayed.height += (target.height - displayed.height) * 0.2
        offset = displayed
    }
}

private enum FaceSpecularRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, offset: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius = min(size.width, size.height) * 0.32
        let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius + 10, y: center.y - radius + 16, width: radius * 2, height: radius * 2)),
            with: .color(.black.opacity(0.35))
        )

        context.drawLayer { inner in
            inner.clip(to: disc)
            inner.fill(disc, with: .color(Color(white: 0.17)))
            for i in stride(from: -radius, through: radius, by: 5.5) {
                var streak = Path()
                let y = center.y + i
                streak.move(to: CGPoint(x: center.x - radius * 0.9, y: y))
                streak.addLine(to: CGPoint(x: center.x + radius * 0.9, y: y + i * 0.02))
                inner.stroke(streak, with: .color(Color.white.opacity(0.04)), lineWidth: 1)
            }
            let hx = center.x + offset.width * radius * 0.55
            let hy = center.y + offset.height * radius * 0.55
            let glow = Path(ellipseIn: CGRect(x: hx - radius * 0.55, y: hy - radius * 0.4, width: radius * 1.1, height: radius * 0.8))
            inner.fill(glow, with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.88), Color.white.opacity(0.16), .clear]),
                center: CGPoint(x: hx, y: hy),
                startRadius: 4,
                endRadius: radius * 0.72
            ))
            inner.fill(
                Path(ellipseIn: CGRect(x: hx - 10, y: hy - 12, width: 18, height: 14)),
                with: .color(.white.opacity(0.92))
            )
        }
        context.stroke(disc, with: .color(Color.white.opacity(0.14)), lineWidth: 1.2)
    }
}

#Preview { FaceSpecularView() }
