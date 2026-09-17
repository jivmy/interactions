import QuartzCore
import SwiftUI

/// Ceiling pull-cord. A slow tug stretches the rope and fails. A yank (velocity gate) toggles the bulb.
struct PullCordView: View {
    @StateObject private var sim = PullCordSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                (sim.isOn ? Color(red: 0.99, green: 0.93, blue: 0.78) : Color(red: 0.10, green: 0.10, blue: 0.12))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.18), value: sim.isOn)

                Canvas { context, size in
                    PullCordRenderer.draw(in: &context, sim: sim, size: size)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sim.drag(to: value.location)
                        }
                        .onEnded { _ in
                            sim.release()
                        }
                )

                LabHintOverlay(text: sim.isOn ? "Yank again to kill the light" : "Yank the handle — a limp tug fails")
            }
            .onAppear {
                sim.updateViewport(size: geo.size)
                sim.start()
            }
            .onChange(of: geo.size) { _, size in
                sim.updateViewport(size: size)
            }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? sim.start() : sim.stop()
            }
            .onDisappear { sim.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class PullCordSimulation: ObservableObject {
    @Published var positions: [CGPoint] = []
    @Published var isOn = false
    @Published var handle: CGPoint = .zero

    private var rope = VerletRope.hanging(count: 14, origin: .zero, restLength: 18)
    private let ticker = FrameTicker()
    private let haptics = HapticPlayer()
    private var viewport: CGSize = .zero
    private var laidOut = false
    private var dragging = false
    private var lastDrag: CGPoint = .zero
    private var lastDragTime: CFTimeInterval = 0
    private var peakYank: CGFloat = 0
    private var pullExtent: CGFloat = 0
    private var restHandleY: CGFloat = 0

    private var canopy: CGPoint {
        CGPoint(x: viewport.width * 0.5, y: ViewSpaceMotion.windowSafeAreaTop() + 74)
    }

    func updateViewport(size: CGSize) {
        viewport = size
        let rest: CGFloat = 22
        restHandleY = canopy.y + rest * 12
        if !laidOut {
            rope = VerletRope.hanging(count: 14, origin: canopy, restLength: rest, damping60: 0.975, iterations: 14)
            laidOut = true
        }
        rope.restLength = rest
        positions = rope.positions
        handle = rope.positions.last ?? canopy
    }

    func start() {
        ticker.onTick = { [weak self] dt in
            self?.step(dt: dt)
        }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func drag(to point: CGPoint) {
        if !dragging {
            let last = rope.positions.last ?? point
            guard hypot(point.x - last.x, point.y - last.y) < 80 else { return }
            dragging = true
            peakYank = 0
            pullExtent = 0
            lastDrag = point
            lastDragTime = CACurrentMediaTime()
            rope.beginDrag(at: last)
        }
        let now = CACurrentMediaTime()
        let dt = max(now - lastDragTime, 1.0 / 120.0)
        let vy = (point.y - lastDrag.y) / dt
        peakYank = max(peakYank, vy)
        pullExtent = max(pullExtent, point.y - restHandleY)
        lastDrag = point
        lastDragTime = now
        let clamped = CGPoint(x: point.x, y: max(point.y, canopy.y + 40))
        rope.moveDrag(to: clamped)
    }

    func release() {
        guard dragging else { return }
        dragging = false
        rope.endDrag()
        // Velocity-gated: need a snap (pts/s) and actual travel. Slow stretch fails.
        if peakYank > 1650 && pullExtent > 36 {
            isOn.toggle()
            haptics.clunk()
        } else if pullExtent > 10 {
            haptics.tick()
        }
        peakYank = 0
        pullExtent = 0
    }

    private func step(dt: CGFloat) {
        let g = CGVector(dx: 0, dy: 18000)
        let steps = 3
        let sub = dt / CGFloat(steps)
        for _ in 0..<steps {
            rope.integrate(gravity: g, dt: sub)
            rope.solveConstraints(anchor: canopy)
        }
        positions = rope.positions
        handle = rope.positions.last ?? handle
    }
}

private enum PullCordRenderer {
    static func draw(in context: inout GraphicsContext, sim: PullCordSimulation, size: CGSize) {
        let nodes = sim.positions
        guard nodes.count >= 2 else { return }
        let on = sim.isOn

        let canopy = nodes[0]
        let fixture = CGRect(x: canopy.x - 36, y: canopy.y - 18, width: 72, height: 16)
        context.fill(Path(roundedRect: fixture, cornerRadius: 3), with: .color(LabPalette.metal))

        let glow = on ? Color(red: 1, green: 0.9, blue: 0.55).opacity(0.55) : Color.clear
        let bulbRect = CGRect(x: canopy.x - 18, y: canopy.y - 58, width: 36, height: 48)
        context.fill(Path(ellipseIn: bulbRect), with: .color(on ? Color(red: 1, green: 0.92, blue: 0.7) : Color(white: 0.25)))
        context.fill(Path(ellipseIn: bulbRect.insetBy(dx: -22, dy: -22)), with: .color(glow))

        var cord = Path()
        cord.move(to: nodes[0])
        for p in nodes.dropFirst() { cord.addLine(to: p) }
        context.stroke(cord, with: .color(on ? Color(white: 0.25) : Color(white: 0.75)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

        let handle = nodes[nodes.count - 1]
        let knob = CGRect(x: handle.x - 11, y: handle.y - 4, width: 22, height: 38)
        context.fill(Path(roundedRect: knob, cornerRadius: 5), with: .color(Color(red: 0.35, green: 0.18, blue: 0.10)))
        context.stroke(Path(roundedRect: knob, cornerRadius: 5), with: .color(Color(red: 0.18, green: 0.08, blue: 0.04)), lineWidth: 1)
    }
}

#Preview { PullCordView() }
