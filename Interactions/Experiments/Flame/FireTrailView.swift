import SwiftUI

struct FireTrailView: View {
    @StateObject private var simulation = FireTrailSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let points = simulation.points
        var uniforms = FireUniforms()
        uniforms.p1 = Float(points.count)

        return GeometryReader { geo in
            FireMetalView(fragmentName: "fireTrailFragment", uniforms: uniforms, points: points)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            simulation.add(value.location, in: geo.size)
                        }
                )
        }
        .accessibilityLabel("Fire")
        .accessibilityHint("Drag a trail")
        .onAppear { simulation.start() }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? simulation.start() : simulation.stop()
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireTrailSimulation: NSObject, ObservableObject {
    @Published private(set) var points: [FirePoint] = []

    private let clock = FireLinkClock()

    func start() {
        clock.onTick = { [weak self] dt in self?.age(dt) }
        clock.start()
    }

    func stop() {
        clock.stop()
    }

    func add(_ point: CGPoint, in size: CGSize) {
        let uv = FireUV.point(point, in: size)
        points.append(FirePoint(x: uv.x, y: uv.y, age: 0, strength: 1))
        if points.count > 24 {
            points.removeFirst(points.count - 24)
        }
    }

    private func age(_ dt: CGFloat) {
        guard !points.isEmpty else { return }
        var next: [FirePoint] = []
        next.reserveCapacity(points.count)
        for var point in points {
            point.age += Float(dt / 1.8)
            if point.age < 1 {
                next.append(point)
            }
        }
        points = next
    }
}

#Preview {
    FireTrailView()
}
