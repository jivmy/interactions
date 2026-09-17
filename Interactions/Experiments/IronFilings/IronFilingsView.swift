import SwiftUI

struct IronFilingsView: View {
    @StateObject private var model = FilingsModel()

    var body: some View {
        GeometryReader { geo in
            let filings = model.filings
            let pole = model.pole
            let poleActive = model.poleActive
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.10).ignoresSafeArea()
                Canvas { context, size in
                    FilingsRenderer.draw(in: &context, size: size, filings: filings, pole: pole, active: poleActive)
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
                .accessibilityLabel("Iron filings")
                .accessibilityHint("Hold a pole. Filings align to the field.")

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
    static func draw(in context: inout GraphicsContext, size: CGSize, filings: [Filing], pole: CGPoint, active: Bool) {
        let tray = CGRect(x: 16, y: 84, width: size.width - 32, height: size.height - 148)
        context.fill(Path(roundedRect: tray, cornerRadius: 10), with: .color(Color(red: 0.13, green: 0.12, blue: 0.11)))
        context.stroke(Path(roundedRect: tray, cornerRadius: 10), with: .color(Color.white.opacity(0.06)), lineWidth: 1)

        if active {
            context.fill(
                Path(ellipseIn: CGRect(x: pole.x - 18, y: pole.y - 18, width: 36, height: 36)),
                with: .color(LabPalette.rust.opacity(0.22))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: pole.x - 9, y: pole.y - 9, width: 18, height: 18)),
                with: .color(LabPalette.rust)
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: pole.x - 15, y: pole.y - 15, width: 30, height: 30)),
                with: .color(LabPalette.rust.opacity(0.45)),
                lineWidth: 1.5
            )
        }
        for f in filings {
            let len: CGFloat = 7.2
            var path = Path()
            path.move(to: CGPoint(x: f.p.x - cos(f.angle) * len, y: f.p.y - sin(f.angle) * len))
            path.addLine(to: CGPoint(x: f.p.x + cos(f.angle) * len, y: f.p.y + sin(f.angle) * len))
            context.stroke(path, with: .color(Color(white: 0.74)), style: StrokeStyle(lineWidth: 1.35, lineCap: .round))
        }
    }
}

#Preview { IronFilingsView() }
