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
                    ? Color(red: 0.99, green: 0.93, blue: 0.76)
                    : Color(red: 0.048, green: 0.046, blue: 0.056))
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.32), value: isOn)

                if !isOn {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.26, blue: 0.34).opacity(0.55),
                                    Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.22)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 78, height: 112)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 1, height: 112)
                        )
                        .offset(x: geo.size.width * 0.28, y: -geo.size.height * 0.18)
                        .allowsHitTesting(false)
                }

                if isOn {
                    RadialGradient(
                        colors: [
                            Color(red: 1, green: 0.94, blue: 0.68).opacity(0.70),
                            Color(red: 1, green: 0.84, blue: 0.46).opacity(0.20),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.16),
                        startRadius: 6,
                        endRadius: 420
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    LinearGradient(
                        colors: [.clear, Color(red: 0.86, green: 0.62, blue: 0.28).opacity(0.16)],
                        startPoint: .center,
                        endPoint: .bottom
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

                LabHintOverlay(text: isOn ? "Again." : "Yank.")
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
        CGPoint(x: viewport.width * 0.5, y: ViewSpaceMotion.windowSafeAreaTop() + 78)
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
            haptics.tick()
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
        let rose = Path(ellipseIn: CGRect(x: canopy.x - 22, y: canopy.y - 36, width: 44, height: 18))
        context.fill(rose, with: .color(on ? Color(white: 0.38) : Color(white: 0.16)))
        let plate = CGRect(x: canopy.x - 58, y: canopy.y - 26, width: 116, height: 9)
        context.fill(Path(roundedRect: plate, cornerRadius: 2), with: .color(on ? Color(white: 0.44) : Color(white: 0.18)))
        context.fill(
            Path(roundedRect: CGRect(x: canopy.x - 20, y: canopy.y - 25, width: 14, height: 3), cornerRadius: 1),
            with: .color(.white.opacity(on ? 0.22 : 0.10))
        )

        let fixture = CGRect(x: canopy.x - 36, y: canopy.y - 20, width: 72, height: 15)
        context.fill(Path(roundedRect: fixture, cornerRadius: 3), with: .color(LabPalette.metal))
        context.fill(
            Path(roundedRect: CGRect(x: canopy.x - 24, y: canopy.y - 17, width: 20, height: 3.5), cornerRadius: 1),
            with: .color(.white.opacity(0.20))
        )

        let bulbRect = CGRect(x: canopy.x - 17, y: canopy.y - 64, width: 34, height: 48)
        if on {
            context.fill(Path(ellipseIn: bulbRect.insetBy(dx: -34, dy: -30)), with: .color(Color(red: 1, green: 0.9, blue: 0.55).opacity(0.22)))
            context.fill(Path(ellipseIn: bulbRect.insetBy(dx: -10, dy: -8)), with: .color(Color(red: 1, green: 0.92, blue: 0.62).opacity(0.4)))
        }
        context.fill(
            Path(ellipseIn: bulbRect),
            with: .color(on ? Color(red: 1, green: 0.94, blue: 0.74) : Color(white: 0.20))
        )
        let neck = CGRect(x: canopy.x - 8, y: canopy.y - 22, width: 16, height: 10)
        context.fill(Path(roundedRect: neck, cornerRadius: 2), with: .color(LabPalette.metalSoft))

        if on {
            context.fill(
                Path(ellipseIn: CGRect(x: canopy.x - 7, y: canopy.y - 54, width: 11, height: 14)),
                with: .color(.white.opacity(0.5))
            )
        } else {
            var filament = Path()
            filament.move(to: CGPoint(x: canopy.x - 6, y: canopy.y - 42))
            filament.addQuadCurve(to: CGPoint(x: canopy.x + 6, y: canopy.y - 42), control: CGPoint(x: canopy.x, y: canopy.y - 52))
            context.stroke(filament, with: .color(Color(white: 0.42)), lineWidth: 1)
        }

        if nodes.count > 3 {
            var shadow = Path()
            shadow.move(to: CGPoint(x: nodes[1].x + 3, y: nodes[1].y + 4))
            for p in nodes.dropFirst() {
                shadow.addLine(to: CGPoint(x: p.x + 3, y: p.y + 4))
            }
            context.stroke(shadow, with: .color(.black.opacity(on ? 0.08 : 0.18)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        var cord = Path()
        cord.move(to: nodes[0])
        for p in nodes.dropFirst() { cord.addLine(to: p) }
        context.stroke(
            cord,
            with: .color(on ? Color(white: 0.20) : Color(white: 0.80)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )

        let handle = nodes[nodes.count - 1]
        let knob = CGRect(x: handle.x - 12, y: handle.y - 3, width: 24, height: 42)
        context.fill(Path(roundedRect: knob, cornerRadius: 7), with: .color(Color(red: 0.40, green: 0.22, blue: 0.12)))
        context.fill(
            Path(roundedRect: CGRect(x: handle.x - 8, y: handle.y + 2, width: 7, height: 24), cornerRadius: 2),
            with: .color(Color(red: 0.60, green: 0.36, blue: 0.20).opacity(0.58))
        )
        context.fill(
            Path(roundedRect: CGRect(x: handle.x + 3, y: handle.y + 6, width: 2.2, height: 18), cornerRadius: 1),
            with: .color(Color.black.opacity(0.16))
        )
        context.stroke(Path(roundedRect: knob, cornerRadius: 7), with: .color(Color(red: 0.16, green: 0.07, blue: 0.04)), lineWidth: 1)
        context.fill(
            Path(ellipseIn: CGRect(x: handle.x - 3, y: handle.y - 1, width: 6, height: 4)),
            with: .color(LabPalette.metalSoft)
        )
    }
}

#Preview { PullCordView() }
