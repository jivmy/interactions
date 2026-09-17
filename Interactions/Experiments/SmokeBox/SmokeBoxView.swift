import SwiftUI

/// Jos Stam-style stable fluids on a small grid. Tilt injects gravity; a finger injects force + density.
struct SmokeBoxView: View {
    @StateObject private var sim = SmokeSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let density = sim.density
            let n = sim.n
            ZStack {
                Color.black.ignoresSafeArea()
                Canvas { context, size in
                    SmokeRenderer.draw(in: &context, size: size, density: density, n: n)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            sim.splat(at: value.location, size: geo.size)
                        }
                        .onEnded { _ in
                            sim.endSplat()
                        }
                )
                .accessibilityLabel("Smoke box")
                .accessibilityValue(sim.usingMotion ? "Tilt" : "Drag")
                .accessibilityHint(sim.usingMotion ? "Tilt and drag" : "Drag to stir")

                LabHintOverlay(text: sim.usingMotion ? "Stir." : "Drag.")
            }
            .onAppear { sim.start() }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? sim.start() : sim.stop()
            }
            .onDisappear { sim.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class SmokeSimulation: ObservableObject {
    let n = 48
    @Published var density: [Float] = []
    @Published var usingMotion = false

    private var u: [Float]
    private var v: [Float]
    private var u0: [Float]
    private var v0: [Float]
    private var d: [Float]
    private var d0: [Float]
    private let ticker = FrameTicker()
    private let motion = DeviceMotionSource()
    private var lastSplat: CGPoint?
    private var publishAccum: CGFloat = 0
    private var seeded = false

    init() {
        let count = 48 * 48
        u = Array(repeating: 0, count: count)
        v = Array(repeating: 0, count: count)
        u0 = Array(repeating: 0, count: count)
        v0 = Array(repeating: 0, count: count)
        d = Array(repeating: 0, count: count)
        d0 = Array(repeating: 0, count: count)
        density = d
    }

    func start() {
        if !seeded {
            let c = n / 2
            d[c * n + c] = 0.42
            d[c * n + c + 1] = 0.22
            d[(c + 1) * n + c] = 0.18
            seeded = true
        }
        motion.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        motion.stop()
    }

    func splat(at point: CGPoint, size: CGSize) {
        let n = self.n
        let x = Int(point.x / max(size.width, 1) * CGFloat(n))
        let y = Int(point.y / max(size.height, 1) * CGFloat(n))
        var fx: Float = 0
        var fy: Float = 0
        if let last = lastSplat {
            fx = Float(point.x - last.x) * 0.35
            fy = Float(point.y - last.y) * 0.35
        }
        lastSplat = point
        for j in (y - 2)...(y + 2) {
            for i in (x - 2)...(x + 2) {
                guard i > 0, j > 0, i < n - 1, j < n - 1 else { continue }
                let idx = j * n + i
                d[idx] = min(1, d[idx] + 0.35)
                u[idx] += fx
                v[idx] += fy
            }
        }
    }

    func endSplat() { lastSplat = nil }

    private func idx(_ i: Int, _ j: Int) -> Int { j * n + i }

    private func step(dt: CGFloat) {
        usingMotion = motion.isUsingHardware
        let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
        let gx = Float(a.dx) * 6
        let gy = Float(a.dy) * 6
        let n = self.n
        for j in 1..<(n - 1) {
            for i in 1..<(n - 1) {
                let k = idx(i, j)
                u[k] += gx * Float(dt)
                v[k] += gy * Float(dt)
            }
        }
        velStep(dt: Float(dt))
        densStep(dt: Float(dt))
        publishAccum += dt
        if publishAccum >= 1.0 / 60.0 {
            publishAccum = 0
            density = d
        }
    }

    private func setBound(_ b: Int, _ x: inout [Float]) {
        let n = self.n
        for i in 1..<(n - 1) {
            x[idx(0, i)] = b == 1 ? -x[idx(1, i)] : x[idx(1, i)]
            x[idx(n - 1, i)] = b == 1 ? -x[idx(n - 2, i)] : x[idx(n - 2, i)]
            x[idx(i, 0)] = b == 2 ? -x[idx(i, 1)] : x[idx(i, 1)]
            x[idx(i, n - 1)] = b == 2 ? -x[idx(i, n - 2)] : x[idx(i, n - 2)]
        }
        x[idx(0, 0)] = 0.5 * (x[idx(1, 0)] + x[idx(0, 1)])
        x[idx(0, n - 1)] = 0.5 * (x[idx(1, n - 1)] + x[idx(0, n - 2)])
        x[idx(n - 1, 0)] = 0.5 * (x[idx(n - 2, 0)] + x[idx(n - 1, 1)])
        x[idx(n - 1, n - 1)] = 0.5 * (x[idx(n - 2, n - 1)] + x[idx(n - 1, n - 2)])
    }

    private func linSolve(_ b: Int, _ x: inout [Float], _ x0: [Float], a: Float, c: Float) {
        let n = self.n
        for _ in 0..<8 {
            for j in 1..<(n - 1) {
                for i in 1..<(n - 1) {
                    x[idx(i, j)] = (x0[idx(i, j)] + a * (x[idx(i - 1, j)] + x[idx(i + 1, j)] + x[idx(i, j - 1)] + x[idx(i, j + 1)])) / c
                }
            }
            setBound(b, &x)
        }
    }

    private func diffuse(_ b: Int, _ x: inout [Float], _ x0: [Float], diff: Float, dt: Float) {
        let a = dt * diff * Float((n - 2) * (n - 2))
        linSolve(b, &x, x0, a: a, c: 1 + 4 * a)
    }

    private func advect(_ b: Int, _ d: inout [Float], _ d0: [Float], u: [Float], v: [Float], dt: Float) {
        let n = self.n
        let dt0 = dt * Float(n - 2)
        for j in 1..<(n - 1) {
            for i in 1..<(n - 1) {
                var x = Float(i) - dt0 * u[idx(i, j)]
                var y = Float(j) - dt0 * v[idx(i, j)]
                x = min(max(x, 0.5), Float(n - 1) - 0.5)
                y = min(max(y, 0.5), Float(n - 1) - 0.5)
                let i0 = Int(x)
                let i1 = i0 + 1
                let j0 = Int(y)
                let j1 = j0 + 1
                let s1 = x - Float(i0)
                let s0 = 1 - s1
                let t1 = y - Float(j0)
                let t0 = 1 - t1
                d[idx(i, j)] = s0 * (t0 * d0[idx(i0, j0)] + t1 * d0[idx(i0, j1)])
                    + s1 * (t0 * d0[idx(i1, j0)] + t1 * d0[idx(i1, j1)])
            }
        }
        setBound(b, &d)
    }

    private func project(_ u: inout [Float], _ v: inout [Float], _ p: inout [Float], _ div: inout [Float]) {
        let n = self.n
        for j in 1..<(n - 1) {
            for i in 1..<(n - 1) {
                div[idx(i, j)] = -0.5 * (u[idx(i + 1, j)] - u[idx(i - 1, j)] + v[idx(i, j + 1)] - v[idx(i, j - 1)]) / Float(n)
                p[idx(i, j)] = 0
            }
        }
        setBound(0, &div)
        setBound(0, &p)
        linSolve(0, &p, div, a: 1, c: 4)
        for j in 1..<(n - 1) {
            for i in 1..<(n - 1) {
                u[idx(i, j)] -= 0.5 * Float(n) * (p[idx(i + 1, j)] - p[idx(i - 1, j)])
                v[idx(i, j)] -= 0.5 * Float(n) * (p[idx(i, j + 1)] - p[idx(i, j - 1)])
            }
        }
        setBound(1, &u)
        setBound(2, &v)
    }

    private func velStep(dt: Float) {
        u0 = u
        v0 = v
        diffuse(1, &u, u0, diff: 0.00012, dt: dt)
        diffuse(2, &v, v0, diff: 0.00012, dt: dt)
        project(&u, &v, &u0, &v0)
        let oldU = u
        let oldV = v
        advect(1, &u, oldU, u: oldU, v: oldV, dt: dt)
        advect(2, &v, oldV, u: oldU, v: oldV, dt: dt)
        project(&u, &v, &u0, &v0)
    }

    private func densStep(dt: Float) {
        d0 = d
        diffuse(0, &d, d0, diff: 0.00008, dt: dt)
        d0 = d
        advect(0, &d, d0, u: u, v: v, dt: dt)
        for i in d.indices { d[i] *= 0.994 }
    }
}

private enum SmokeRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, density: [Float], n: Int) {
        guard density.count == n * n else { return }
        let inset: CGFloat = 16
        let box = CGRect(x: inset, y: 80, width: size.width - inset * 2, height: size.height - 150)
        context.fill(Path(roundedRect: box, cornerRadius: 12), with: .color(Color(red: 0.04, green: 0.045, blue: 0.05)))
        context.stroke(Path(roundedRect: box, cornerRadius: 12), with: .color(Color.white.opacity(0.10)), lineWidth: 2.5)
        context.stroke(Path(roundedRect: box.insetBy(dx: 3, dy: 3), cornerRadius: 10), with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        context.fill(
            Path(roundedRect: CGRect(x: box.minX + 14, y: box.minY + 10, width: box.width * 0.36, height: 12), cornerRadius: 3),
            with: .color(.white.opacity(0.04))
        )

        let cw = box.width / CGFloat(n)
        let ch = box.height / CGFloat(n)
        context.drawLayer { inner in
            inner.clip(to: Path(roundedRect: box.insetBy(dx: 2, dy: 2), cornerRadius: 10))
            for j in 0..<n {
                var i = 0
                while i < n {
                    let v = density[j * n + i]
                    if v < 0.02 {
                        i += 1
                        continue
                    }
                    let start = i
                    i += 1
                    while i < n && density[j * n + i] >= 0.02 { i += 1 }
                    let dens = Double(min(1, density[j * n + start] * 1.45))
                    let warm = dens * 0.28
                    inner.fill(
                        Path(CGRect(x: box.minX + CGFloat(start) * cw, y: box.minY + CGFloat(j) * ch, width: CGFloat(i - start) * cw + 0.5, height: ch + 0.5)),
                        with: .color(Color(red: 0.86 + warm * 0.12, green: 0.80, blue: 0.74 - warm * 0.18).opacity(dens))
                    )
                }
            }
        }
    }
}

#Preview { SmokeBoxView() }
