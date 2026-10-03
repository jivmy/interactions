import SwiftUI

struct FireSheetView: View {
    @StateObject private var simulation = FireSheetSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        var uniforms = FireUniforms()
        uniforms.p0 = Float(simulation.offset)
        uniforms.intensity = 0.85

        return GeometryReader { geo in
            FireMetalView(fragmentName: "fireSheetFragment", uniforms: uniforms)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            simulation.drag(to: value.location, in: geo.size)
                        }
                        .onEnded { _ in
                            simulation.endDrag()
                        }
                )
        }
        .accessibilityLabel("Fire")
        .accessibilityHint("Push the sheet")
        .onAppear { simulation.start() }
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? simulation.start() : simulation.stop()
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireSheetSimulation: NSObject, ObservableObject {
    @Published private(set) var offset: CGFloat = 0

    private let clock = FireLinkClock()
    private var target: CGFloat = 0
    private var dragging = false

    func start() {
        clock.onTick = { [weak self] dt in
            guard let self else { return }
            if !self.dragging {
                self.target *= pow(0.88, dt * 60)
            }
            self.offset += (self.target - self.offset) * min(1, dt * 10)
        }
        clock.start()
    }

    func stop() {
        clock.stop()
    }

    func drag(to point: CGPoint, in size: CGSize) {
        dragging = true
        target = (point.x / max(size.width, 1) - 0.5) * 1.35
    }

    func endDrag() {
        dragging = false
    }
}

#Preview {
    FireSheetView()
}
