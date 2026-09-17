import SwiftUI

struct MetaballMercuryView: View {
    @StateObject private var model = MetaballModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LabPaperBackground()
                MetalLabView(fragmentName: "metaballFragment", uniforms: model.uniforms, isActive: scenePhase == .active)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                model.touch = value.location
                                model.touching = true
                            }
                            .onEnded { _ in
                                model.touching = false
                            }
                    )
                    .accessibilityLabel("Metaball mercury")
                    .accessibilityHint("Drag a blob. Tilt merges them.")

                LabHintOverlay(text: "Drag.")
            }
            .onAppear {
                model.size = geo.size
                model.start()
            }
            .onChange(of: geo.size) { _, size in model.size = size }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class MetaballModel: ObservableObject {
    @Published var uniforms = LabUniforms()
    var size: CGSize = .zero
    var touch = CGPoint.zero
    var touching = false

    private let motion = DeviceMotionSource()
    private let ticker = FrameTicker()
    private var t: Float = 0
    private var blobs: [SIMD2<Float>] = [
        SIMD2(0.38, 0.48), SIMD2(0.62, 0.52), SIMD2(0.50, 0.38), SIMD2(0.55, 0.64)
    ]
    private var vel: [SIMD2<Float>] = Array(repeating: .zero, count: 4)

    func start() {
        motion.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        motion.stop()
    }

    private func step(dt: CGFloat) {
        t += Float(dt)
        let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
        let gx = Float(a.dx) * 0.55
        let gy = Float(a.dy - 0.2) * 0.35
        if touching, size.width > 1 {
            blobs[0] = SIMD2(Float(touch.x / size.width), Float(touch.y / size.height))
            vel[0] = .zero
        }
        for i in blobs.indices {
            if i == 0 && touching { continue }
            vel[i].x += gx * Float(dt)
            vel[i].y += gy * Float(dt)
            vel[i] *= 0.96
            blobs[i] += vel[i] * Float(dt) * 1.8
            blobs[i].x = min(max(blobs[i].x, 0.12), 0.88)
            blobs[i].y = min(max(blobs[i].y, 0.18), 0.86)
            if blobs[i].x <= 0.12 || blobs[i].x >= 0.88 { vel[i].x *= -0.4 }
            if blobs[i].y <= 0.18 || blobs[i].y >= 0.86 { vel[i].y *= -0.4 }
        }
        var u = LabUniforms()
        u.time = t
        u.tiltX = gx
        u.tiltY = gy
        u.b0x = blobs[0].x; u.b0y = blobs[0].y; u.b0r = 0.155
        u.b1x = blobs[1].x; u.b1y = blobs[1].y; u.b1r = 0.12
        u.b2x = blobs[2].x; u.b2y = blobs[2].y; u.b2r = 0.10
        u.b3x = blobs[3].x; u.b3y = blobs[3].y; u.b3r = 0.09
        uniforms = u
    }
}

#Preview { MetaballMercuryView() }
