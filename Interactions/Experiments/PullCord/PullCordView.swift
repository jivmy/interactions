import QuartzCore
import SwiftUI

/// Ceiling pull-cord. A slow tug stretches the rope and fails. A yank (velocity gate) toggles the bulb.
struct PullCordView: View {
    @StateObject private var sim = PullCordSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let positions = sim.positions
            let isOn = sim.isOn
            ZStack {
                (isOn
                    ? Color(red: 0.99, green: 0.93, blue: 0.78)
                    : Color(red: 0.075, green: 0.074, blue: 0.086))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.22), value: isOn)

                if isOn {
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.92, blue: 0.62).opacity(0.55), .clear],
                        center: .top,
                        startRadius: 10,
                        endRadius: 340
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                Canvas { context, size in
                    PullCordRenderer.draw(in: &context, nodes: positions, isOn: isOn)
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
                .accessibilityLabel(isOn ? "Pull-cord light, on" : "Pull-cord light, off")
                .accessibilityHint("Yank the handle to toggle")

                LabHintOverlay(text: isOn ? "Yank again to kill the light" : "Yank the handle — a limp tug fails")
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
        if peakYank > 1650 && pullExtent > 36 {
            isOn.toggle()
            haptics.success()
        } else if pullExtent > 10 {
            haptics.failure()
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
    static func draw(in context: inout GraphicsContext, nodes: [CGPoint], isOn on: Bool) {
        guard nodes.count >= 2 else { return }

        let canopy = nodes[0]
        let fixture = CGRect(x: canopy.x - 40, y: canopy.y - 20, width: 80, height: 18)
        context.fill(Path(roundedRect: fixture, cornerRadius: 4), with: .color(LabPalette.metal))
        context.fill(
            Path(roundedRect: CGRect(x: canopy.x - 28, y: canopy.y - 17, width: 24, height: 4), cornerRadius: 1),
            with: .color(.white.opacity(0.16))
        )

        let glow = on ? Color(red: 1, green: 0.9, blue: 0.55).opacity(0.42) : Color.clear
        let bulbRect = CGRect(x: canopy.x - 18, y: canopy.y - 62, width: 36, height: 50)
        context.fill(Path(ellipseIn: bulbRect.insetBy(dx: -26, dy: -26)), with: .color(glow))
        context.fill(
            Path(ellipseIn: bulbRect),
            with: .color(on ? Color(red: 1, green: 0.93, blue: 0.72) : Color(white: 0.22))
        )
        if on {
            context.fill(
                Path(ellipseIn: CGRect(x: canopy.x - 8, y: canopy.y - 52, width: 12, height: 16)),
                with: .color(.white.opacity(0.45))
            )
        } else {
            var filament = Path()
            filament.move(to: CGPoint(x: canopy.x - 6, y: canopy.y - 40))
            filament.addQuadCurve(to: CGPoint(x: canopy.x + 6, y: canopy.y - 40), control: CGPoint(x: canopy.x, y: canopy.y - 50))
            context.stroke(filament, with: .color(Color(white: 0.45)), lineWidth: 1)
        }

        var cord = Path()
        cord.move(to: nodes[0])
        for p in nodes.dropFirst() { cord.addLine(to: p) }
        context.stroke(
            cord,
            with: .color(on ? Color(white: 0.22) : Color(white: 0.78)),
            style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round)
        )

        let handle = nodes[nodes.count - 1]
        let knob = CGRect(x: handle.x - 12, y: handle.y - 4, width: 24, height: 40)
        context.fill(Path(roundedRect: knob, cornerRadius: 6), with: .color(Color(red: 0.38, green: 0.20, blue: 0.11)))
        context.fill(
            Path(roundedRect: CGRect(x: handle.x - 8, y: handle.y, width: 7, height: 22), cornerRadius: 2),
            with: .color(Color(red: 0.55, green: 0.32, blue: 0.16).opacity(0.55))
        )
        context.stroke(Path(roundedRect: knob, cornerRadius: 6), with: .color(Color(red: 0.18, green: 0.08, blue: 0.04)), lineWidth: 1)
    }
}

#Preview { PullCordView() }
