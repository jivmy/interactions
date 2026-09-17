import SwiftUI

struct ClothPanelView: View {
    @StateObject private var sim = ClothSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let positions = sim.positions
            let cols = sim.cols
            let rows = sim.rows
            ZStack {
                Color(red: 0.12, green: 0.13, blue: 0.14).ignoresSafeArea()
                Canvas { context, size in
                    ClothRenderer.draw(in: &context, positions: positions, cols: cols, rows: rows)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sim.drag(to: value.location)
                        }
                        .onEnded { _ in
                            sim.endDrag()
                        }
                )
                .accessibilityLabel("Cloth panel")
                .accessibilityHint(sim.usingMotion ? "Tilt or drag the cloth" : "Drag the cloth")

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: sim.usingMotion ? "Tilt live" : "Drag only")
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .allowsHitTesting(false)

                LabHintOverlay(text: sim.usingMotion ? "Tilt or drag the cloth" : "Drag the cloth — tilt needs a real iPhone")
            }
            .onAppear {
                sim.layout(size: geo.size)
                sim.start()
            }
            .onChange(of: geo.size) { _, size in sim.layout(size: size) }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? sim.start() : sim.stop()
            }
            .onDisappear { sim.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class ClothSimulation: ObservableObject {
    let cols = 13
    let rows = 10
    @Published var positions: [CGPoint] = []
    @Published var usingMotion = false

    private var particles: [VerletParticle] = []
    private var restH: CGFloat = 20
    private var restV: CGFloat = 20
    private var dragIndex: Int?
    private let ticker = FrameTicker()
    private let motion = DeviceMotionSource()
    private var viewport: CGSize = .zero

    func layout(size: CGSize) {
        viewport = size
        let width = size.width * 0.78
        let origin = CGPoint(x: (size.width - width) / 2, y: ViewSpaceMotion.windowSafeAreaTop() + 88)
        restH = width / CGFloat(cols - 1)
        restV = restH * 0.92
        if particles.count != cols * rows {
            particles = (0..<rows).flatMap { r in
                (0..<cols).map { c -> VerletParticle in
                    let p = CGPoint(x: origin.x + CGFloat(c) * restH, y: origin.y + CGFloat(r) * restV)
                    return VerletParticle(position: p, oldPosition: p, pinned: r == 0)
                }
            }
        } else {
            for c in 0..<cols {
                let p = CGPoint(x: origin.x + CGFloat(c) * restH, y: origin.y)
                particles[c].position = p
                particles[c].oldPosition = p
                particles[c].pinned = true
            }
        }
        positions = particles.map(\.position)
    }

    func start() {
        motion.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        motion.stop()
    }

    func drag(to point: CGPoint) {
        if dragIndex == nil {
            var best: Int?
            var bestD = CGFloat.greatestFiniteMagnitude
            for i in particles.indices where !particles[i].pinned {
                let d = hypot(particles[i].position.x - point.x, particles[i].position.y - point.y)
                if d < 48 && d < bestD {
                    bestD = d
                    best = i
                }
            }
            dragIndex = best
        }
        if let dragIndex {
            particles[dragIndex].oldPosition = particles[dragIndex].position
            particles[dragIndex].position = point
        }
    }

    func endDrag() { dragIndex = nil }

    private func step(dt: CGFloat) {
        usingMotion = motion.isUsingHardware
        let mapped = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
        let g = CGVector(dx: mapped.dx * 14000, dy: mapped.dy * 14000)
        let damp = pow(0.985, dt * 60)
        let ax = g.dx * dt * dt
        let ay = g.dy * dt * dt
        for i in particles.indices {
            if particles[i].pinned || i == dragIndex { continue }
            let p = particles[i].position
            let o = particles[i].oldPosition
            let vx = (p.x - o.x) * damp
            let vy = (p.y - o.y) * damp
            particles[i].oldPosition = p
            particles[i].position = CGPoint(x: p.x + vx + ax, y: p.y + vy + ay)
        }
        for _ in 0..<8 {
            satisfy()
        }
        positions = particles.map(\.position)
    }

    private func satisfy() {
        func link(_ a: Int, _ b: Int, rest: CGFloat) {
            let pa = particles[a].position
            let pb = particles[b].position
            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            let dist = hypot(dx, dy)
            guard dist > 0.0001 else { return }
            let w1: CGFloat = particles[a].pinned || a == dragIndex ? 0 : 1
            let w2: CGFloat = particles[b].pinned || b == dragIndex ? 0 : 1
            let w = w1 + w2
            guard w > 0 else { return }
            let corr = (dist - rest) / dist
            if w1 > 0 {
                particles[a].position.x += dx * corr * (w1 / w)
                particles[a].position.y += dy * corr * (w1 / w)
            }
            if w2 > 0 {
                particles[b].position.x -= dx * corr * (w2 / w)
                particles[b].position.y -= dy * corr * (w2 / w)
            }
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let i = r * cols + c
                if c + 1 < cols { link(i, i + 1, rest: restH) }
                if r + 1 < rows { link(i, i + cols, rest: restV) }
                if c + 1 < cols && r + 1 < rows { link(i, i + cols + 1, rest: hypot(restH, restV)) }
            }
        }
    }
}

private enum ClothRenderer {
    static func draw(in context: inout GraphicsContext, positions: [CGPoint], cols: Int, rows: Int) {
        guard positions.count == cols * rows else { return }

        for r in 0..<(rows - 1) {
            for c in 0..<(cols - 1) {
                let i = r * cols + c
                let a = positions[i]
                let b = positions[i + 1]
                let d = positions[i + cols]
                let e = positions[i + cols + 1]
                let ux = b.x - a.x
                let uy = b.y - a.y
                let vx = d.x - a.x
                let vy = d.y - a.y
                let cross = ux * vy - uy * vx
                let shade = min(max(0.38 + cross / 900, 0.22), 0.78)
                var quad = Path()
                quad.move(to: a)
                quad.addLine(to: b)
                quad.addLine(to: e)
                quad.addLine(to: d)
                quad.closeSubpath()
                context.fill(quad, with: .color(Color(red: 0.72 * shade + 0.08, green: 0.48 * shade + 0.06, blue: 0.28 * shade + 0.04)))
            }
        }

        for r in 0..<rows {
            for c in 0..<cols {
                let i = r * cols + c
                let p = positions[i]
                if c + 1 < cols {
                    var path = Path()
                    path.move(to: p)
                    path.addLine(to: positions[i + 1])
                    context.stroke(path, with: .color(Color(red: 0.78, green: 0.58, blue: 0.34).opacity(0.35)), lineWidth: 0.7)
                }
                if r + 1 < rows {
                    var path = Path()
                    path.move(to: p)
                    path.addLine(to: positions[i + cols])
                    context.stroke(path, with: .color(Color(red: 0.62, green: 0.44, blue: 0.26).opacity(0.28)), lineWidth: 0.7)
                }
            }
        }
        for c in 0..<cols {
            let p = positions[c]
            context.fill(Path(ellipseIn: CGRect(x: p.x - 3.2, y: p.y - 3.2, width: 6.4, height: 6.4)), with: .color(LabPalette.metal))
        }
    }
}

#Preview { ClothPanelView() }
