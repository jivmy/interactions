import SwiftUI

struct FireWhirlView: View {
    @StateObject private var simulation = FireWhirlSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        var uniforms = FireUniforms()
        uniforms.spin = Float(simulation.spin)
        uniforms.intensity = Float(min(1, abs(simulation.spin)))

        return GeometryReader { geo in
            FireMetalView(fragmentName: "fireWhirlFragment", uniforms: uniforms)
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
        .accessibilityHint("Spin")
        .onAppear { simulation.start() }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? simulation.start() : simulation.stop()
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireWhirlSimulation: NSObject, ObservableObject {
    @Published private(set) var spin: CGFloat = 0.18

    private let clock = FireLinkClock()
    private var last: CGPoint?

    func start() {
        clock.onTick = { [weak self] dt in
            guard let self else { return }
            self.spin *= pow(0.92, dt * 60)
            if abs(self.spin) < 0.04 { self.spin = self.spin >= 0 ? 0.04 : -0.04 }
        }
        clock.start()
    }

    func stop() {
        clock.stop()
    }

    func drag(_ value: DragGesture.Value, in size: CGSize) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.62)
        let current = value.location
        if let last {
            let ax = last.x - center.x
            let ay = last.y - center.y
            let bx = current.x - center.x
            let by = current.y - center.y
            let cross = ax * by - ay * bx
            let scale = max(size.width, 1) * max(size.height, 1)
            spin = max(-2.4, min(2.4, spin + cross / scale * 8))
        }
        last = current
    }

    func endDrag() {
        last = nil
    }
}

#Preview {
    FireWhirlView()
}
