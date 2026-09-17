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
        motion.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        motion.stop()
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
        context.stroke(ring, with: .color(Color(red: 0.72, green: 0.62, blue: 0.38).opacity(0.72)), lineWidth: 5)
        context.stroke(ring, with: .color(Color.white.opacity(0.14)), lineWidth: 1.2)
        let handle = CGRect(x: center.x - 7, y: center.y + radius - 2, width: 14, height: 36)
        context.fill(Path(roundedRect: handle, cornerRadius: 3), with: .color(Color(red: 0.62, green: 0.52, blue: 0.30)))
        context.fill(
            Path(roundedRect: CGRect(x: center.x - 3, y: center.y + radius + 6, width: 3, height: 18), cornerRadius: 1),
            with: .color(.white.opacity(0.16))
        )
    }
}

#Preview { SoapFilmView() }
