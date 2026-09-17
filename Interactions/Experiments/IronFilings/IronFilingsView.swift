import SwiftUI

struct IronFilingsView: View {
    @StateObject private var model = FilingsModel()

    var body: some View {
        GeometryReader { geo in
            let filings = model.filings
            let pole = model.pole
            let poleActive = model.poleActive
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.11).ignoresSafeArea()
                Canvas { context, size in
                    FilingsRenderer.draw(in: &context, filings: filings, pole: pole, active: poleActive)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.pole = value.location
                            model.poleActive = true
                        }
                        .onEnded { _ in
                            model.poleActive = false
                        }
                )
                LabHintOverlay(text: "Hold a pole. Filings align to the field.")
            }
            .onAppear {
                model.seed(size: geo.size)
                model.start()
            }
            .onChange(of: geo.size) { _, size in model.seed(size: size) }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

struct Filing: Sendable {
    var p: CGPoint
    var angle: CGFloat
}

@MainActor
final class FilingsModel: ObservableObject {
    @Published var filings: [Filing] = []
    @Published var pole = CGPoint.zero
    @Published var poleActive = false

    private let ticker = FrameTicker()
    private var size: CGSize = .zero
    private var seeded = false

    func seed(size: CGSize) {
        self.size = size
        if seeded && filings.count > 0 { return }
        seeded = true
        let cols = 22
        let rows = 36
        let inset: CGFloat = 28
        filings = (0..<rows).flatMap { r -> [Filing] in
            (0..<cols).map { c in
                let x = inset + (size.width - inset * 2) * CGFloat(c) / CGFloat(cols - 1) + CGFloat.random(in: -3...3)
                let y = inset + (size.height - inset * 2) * CGFloat(r) / CGFloat(rows - 1) + CGFloat.random(in: -3...3)
                return Filing(p: CGPoint(x: x, y: y), angle: CGFloat.random(in: 0...(.pi)))
            }
        }
        pole = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    private func step(dt: CGFloat) {
        let pole = poleActive ? self.pole : CGPoint(x: size.width / 2, y: size.height * 0.2)
        let strength: CGFloat = poleActive ? 1 : 0.25
        for i in filings.indices {
            let p = filings[i].p
            let dx = p.x - pole.x
            let dy = p.y - pole.y
            let r2 = max(dx * dx + dy * dy, 80)
            // 2D dipole-ish field pointing out of a north pole.
            let bx = dx / (r2 * sqrt(r2)) * 90000 * strength
            let by = dy / (r2 * sqrt(r2)) * 90000 * strength
            let target = atan2(by, bx)
            var delta = target - filings[i].angle
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            filings[i].angle += delta * min(1, 10 * dt)
            if poleActive {
                let pull = 18 * dt * strength / (sqrt(r2) / 40)
                filings[i].p.x -= dx / max(sqrt(r2), 1) * min(pull, 2.2)
                filings[i].p.y -= dy / max(sqrt(r2), 1) * min(pull, 2.2)
            }
        }
    }
}

private enum FilingsRenderer {
    static func draw(in context: inout GraphicsContext, filings: [Filing], pole: CGPoint, active: Bool) {
        if active {
            context.fill(Path(ellipseIn: CGRect(x: pole.x - 10, y: pole.y - 10, width: 20, height: 20)), with: .color(Color(red: 0.75, green: 0.18, blue: 0.16)))
            context.stroke(Path(ellipseIn: CGRect(x: pole.x - 16, y: pole.y - 16, width: 32, height: 32)), with: .color(Color.red.opacity(0.35)), lineWidth: 2)
        }
        for f in filings {
            let len: CGFloat = 7
            var path = Path()
            path.move(to: CGPoint(x: f.p.x - cos(f.angle) * len, y: f.p.y - sin(f.angle) * len))
            path.addLine(to: CGPoint(x: f.p.x + cos(f.angle) * len, y: f.p.y + sin(f.angle) * len))
            context.stroke(path, with: .color(Color(white: 0.72)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
    }
}

#Preview { IronFilingsView() }
