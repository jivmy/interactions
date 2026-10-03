import SwiftUI

struct FireLeanView: View {
    @StateObject private var simulation = FireLeanSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let tilt = simulation.tilt
        var uniforms = FireUniforms()
        uniforms.tiltX = Float(tilt.dx)
        uniforms.tiltY = Float(tilt.dy)
        uniforms.intensity = 0.7

        return GeometryReader { geo in
            FireMetalView(fragmentName: "fireLeanFragment", uniforms: uniforms)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            simulation.drag(to: value.location)
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
        .accessibilityHint(simulation.usingMotion ? "Tilt the phone" : "Drag to lean")
        .onChange(of: scenePhase) { _, phase in
            phase == .active ? simulation.start() : simulation.stop()
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireLeanSimulation: NSObject, ObservableObject {
    @Published private(set) var tilt = CGVector.zero
    @Published private(set) var usingMotion = false

    private let motion = DeviceMotionSource()
    private let clock = FireLinkClock()
    private var viewport: CGSize = .zero
    private var dragging = false
    private var dragTilt = CGVector.zero

    func updateViewport(_ size: CGSize) {
        viewport = size
    }

    func start() {
        motion.start()
        clock.onTick = { [weak self] _ in self?.sample() }
        clock.start()
    }

    func stop() {
        clock.stop()
        motion.stop()
    }

    func drag(to point: CGPoint) {
        dragging = true
        let size = viewport
        let x = (point.x / max(size.width, 1) - 0.5) * 2
        let y = (0.5 - point.y / max(size.height, 1)) * 2
        dragTilt = CGVector(dx: max(-1.4, min(1.4, x)), dy: max(-1.4, min(1.4, y)))
    }

    func endDrag() {
        dragging = false
    }

    private func sample() {
        let hardware = motion.isUsingHardware
        usingMotion = hardware
        if hardware, !dragging {
            let mapped = ViewSpaceMotion.acceleration(
                motion.acceleration,
                interface: ViewSpaceMotion.currentInterfaceOrientation()
            )
            tilt = CGVector(dx: mapped.dx, dy: mapped.dy - 1)
        } else if dragging {
            tilt = dragTilt
        } else if !hardware {
            tilt = CGVector(dx: tilt.dx * 0.94, dy: tilt.dy * 0.94)
        }
    }
}

#Preview {
    FireLeanView()
}
