import SwiftUI

struct SoapFilmView: View {
    @StateObject private var model = SoapFilmModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(red: 0.05, green: 0.055, blue: 0.07).ignoresSafeArea()
                MetalLabView(fragmentName: "soapFragment", uniforms: model.uniforms, fallback: Color(red: 0.05, green: 0.055, blue: 0.07), isActive: scenePhase == .active)
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.pop()
                    }
                    .accessibilityLabel(model.popped ? "Soap film, popped" : "Soap film")
                    .accessibilityHint("Tilt the film. Tap to pop.")

                Canvas { context, size in
                    SoapHoopRenderer.draw(in: &context, size: size)
                }
                .allowsHitTesting(false)

                LabHintOverlay(text: model.popped ? "Again." : "Tilt.")
            }
            .onAppear { model.start() }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class SoapFilmModel: ObservableObject {
    @Published var uniforms = LabUniforms()
    @Published var popped = false

    private let motion = DeviceMotionSource()
    private let ticker = FrameTicker()
    private let haptics = HapticPlayer()
    private var t: Float = 0
    private var hole: Float = 0
    private var popping = false

    func start() {
        haptics.startEngine()
        motion.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        motion.stop()
        haptics.shutdown()
    }

    func pop() {
        if popping || popped {
            hole = 0
            popping = false
            popped = false
            return
        }
        popping = true
        haptics.pop()
    }

    private func step(dt: CGFloat) {
        t += Float(dt)
        if popping {
            hole += Float(dt) * 0.55
            if hole > 0.55 {
                popped = true
                popping = false
            }
        }
        let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
        var u = LabUniforms()
        u.time = t
        u.tiltX = Float(a.dx)
        u.tiltY = Float(a.dy)
        u.pop = hole
        u.p0 = Float(sin(Double(t) * 0.7)) * 0.3
        uniforms = u
    }
}

private enum SoapHoopRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = size.height * 0.38
        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(ring, with: .color(Color(red: 0.42, green: 0.34, blue: 0.18).opacity(0.55)), lineWidth: 9)
        context.stroke(ring, with: .color(Color(red: 0.72, green: 0.62, blue: 0.38).opacity(0.86)), lineWidth: 5)
        context.stroke(ring, with: .color(Color.white.opacity(0.16)), lineWidth: 1.2)
        let ferrule = Path(ellipseIn: CGRect(x: center.x - 11, y: center.y + radius - 10, width: 22, height: 16))
        context.fill(ferrule, with: .color(Color(red: 0.58, green: 0.48, blue: 0.28)))
        let handle = CGRect(x: center.x - 7, y: center.y + radius - 2, width: 14, height: 38)
        context.fill(Path(roundedRect: handle, cornerRadius: 3), with: .color(Color(red: 0.62, green: 0.52, blue: 0.30)))
        context.fill(
            Path(roundedRect: CGRect(x: center.x - 3, y: center.y + radius + 6, width: 3, height: 20), cornerRadius: 1),
            with: .color(.white.opacity(0.18))
        )
        for a in [0.18, 0.82, 1.18, 1.82] {
            let sx = center.x + LabMath.cos(a * .pi) * radius
            let sy = center.y + LabMath.sin(a * .pi) * radius
            context.fill(Path(ellipseIn: CGRect(x: sx - 2.1, y: sy - 2.1, width: 4.2, height: 4.2)), with: .color(Color(red: 0.50, green: 0.40, blue: 0.22)))
        }
    }
}

#Preview { SoapFilmView() }
