import SwiftUI

struct SoapFilmView: View {
    @StateObject private var model = SoapFilmModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()
                MetalLabView(fragmentName: "soapFragment", uniforms: model.uniforms, fallback: Color(red: 0.06, green: 0.07, blue: 0.09))
                    .ignoresSafeArea()
                    .onTapGesture {
                        model.pop()
                    }
                LabHintOverlay(text: model.popped ? "Tap to blow another film" : "Tilt for iridescence. Tap to pop.")
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

#Preview { SoapFilmView() }
