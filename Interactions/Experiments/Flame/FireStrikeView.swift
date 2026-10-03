import QuartzCore
import SwiftUI

struct FireStrikeView: View {
    @StateObject private var simulation = FireStrikeSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        var uniforms = FireUniforms()
        uniforms.intensity = Float(simulation.heat)
        uniforms.touchX = simulation.touchX
        uniforms.touchY = simulation.touchY
        uniforms.prevX = simulation.dirX
        uniforms.prevY = simulation.dirY
        uniforms.touching = simulation.striking ? 1 : 0

        return GeometryReader { geo in
            FireMetalView(fragmentName: "fireStrikeFragment", uniforms: uniforms)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            simulation.drag(value.location)
                        }
                        .onEnded { _ in
                            simulation.endDrag()
                        }
                )
                .onAppear {
                    simulation.updateViewport(geo.size)
                    simulation.start()
                }
                .onChange(of: geo.size) { _, size in
                    simulation.updateViewport(size)
                }
        }
        .accessibilityLabel("Fire")
        .accessibilityHint("Strike")
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? simulation.start() : simulation.stop()
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireStrikeSimulation: NSObject, ObservableObject {
    @Published private(set) var heat: CGFloat = 0
    @Published private(set) var touchX: Float = 0.5
    @Published private(set) var touchY: Float = 0.28
    @Published private(set) var dirX: Float = 1
    @Published private(set) var dirY: Float = 0
    @Published private(set) var striking = false

    private let clock = FireLinkClock()
    private var viewport: CGSize = .zero
    private var lastPoint: CGPoint?
    private var lastTime: CFTimeInterval = 0

    func updateViewport(_ size: CGSize) {
        viewport = size
    }

    func start() {
        clock.onTick = { [weak self] dt in
            guard let self else { return }
            self.heat = max(0, self.heat - dt / 7)
        }
        clock.start()
    }

    func stop() {
        clock.stop()
    }

    func drag(_ location: CGPoint) {
        let now = CACurrentMediaTime()
        let uv = FireUV.point(location, in: viewport)
        touchX = uv.x
        touchY = uv.y
        striking = true
        if let lastPoint {
            let dt = max(now - lastTime, 1.0 / 120.0)
            let dx = location.x - lastPoint.x
            let dy = location.y - lastPoint.y
            let speed = hypot(dx, dy) / dt
            let len = max(hypot(dx, dy), 1)
            dirX = Float(dx / len)
            dirY = Float(-dy / len)
            if speed > 2100 {
                heat = 1
            }
        }
        lastPoint = location
        lastTime = now
    }

    func endDrag() {
        lastPoint = nil
        striking = false
    }
}

#Preview {
    FireStrikeView()
}
