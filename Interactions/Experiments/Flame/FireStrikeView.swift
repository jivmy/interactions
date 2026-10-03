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
                            simulation.drag(value, in: geo.size)
                        }
                        .onEnded { _ in
                            simulation.endDrag()
                        }
                )
        }
        .accessibilityLabel("Fire")
        .accessibilityHint("Strike")
        .onAppear { simulation.start() }
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
    private var lastPoint: CGPoint?
    private var lastTime: CFTimeInterval = 0

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

    func drag(_ value: DragGesture.Value, in size: CGSize) {
        let now = CACurrentMediaTime()
        let uv = FireUV.point(value.location, in: size)
        touchX = uv.x
        touchY = uv.y
        striking = true
        if let lastPoint {
            let dt = max(now - lastTime, 1.0 / 120.0)
            let dx = value.location.x - lastPoint.x
            let dy = value.location.y - lastPoint.y
            let speed = hypot(dx, dy) / dt
            let len = max(hypot(CGFloat(dx), CGFloat(dy)), 1)
            dirX = Float(dx / len)
            dirY = Float(-dy / len)
            if speed > 2100 {
                heat = 1
            }
        }
        lastPoint = value.location
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
