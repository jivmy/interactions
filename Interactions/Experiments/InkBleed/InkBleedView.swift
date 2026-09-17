import SwiftUI

struct InkBleedView: View {
    @StateObject private var model = InkBleedModel()

    var body: some View {
        GeometryReader { geo in
            let field = model.field
            let cols = model.cols
            let rows = model.rows
            ZStack {
                Color(red: 0.90, green: 0.86, blue: 0.78).ignoresSafeArea()
                Canvas { context, size in
                    InkBleedRenderer.draw(in: &context, size: size, field: field, cols: cols, rows: rows)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.stamp(at: value.location, size: geo.size)
                        }
                )
                LabHintOverlay(text: "Touch the paper. Ink wicks along the grain.")
            }
            .onAppear {
                model.ensure(size: geo.size)
                model.start()
            }
            .onChange(of: geo.size) { _, size in model.ensure(size: size) }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class InkBleedModel: ObservableObject {
    let cols = 72
    let rows = 128
    @Published var field: [Float] = []
    private var grain: [Float] = []
    private let ticker = FrameTicker()
    private var size: CGSize = .zero
    private var wet: [Float] = []

    func ensure(size: CGSize) {
        self.size = size
        if field.count != cols * rows {
            field = Array(repeating: 0, count: cols * rows)
            wet = Array(repeating: 0, count: cols * rows)
            grain = (0..<(cols * rows)).map { _ in Float.random(in: 0.65...1.35) }
        }
    }

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func stamp(at point: CGPoint, size: CGSize) {
        let x = Int(point.x / max(size.width, 1) * CGFloat(cols))
        let y = Int(point.y / max(size.height, 1) * CGFloat(rows))
        for dy in -2...2 {
            for dx in -2...2 {
                let xx = x + dx
                let yy = y + dy
                if xx >= 0 && xx < cols && yy >= 0 && yy < rows {
                    let i = yy * cols + xx
                    let falloff = 1 - Float(dx * dx + dy * dy) / 12
                    field[i] = min(1, field[i] + 0.55 * max(0, falloff))
                    wet[i] = min(1, wet[i] + 0.8)
                }
            }
        }
    }

    private func step(dt: CGFloat) {
        guard field.count == cols * rows else { return }
        var next = field
        var nextWet = wet
        let k = Float(dt) * 3.2
        for y in 1..<(rows - 1) {
            for x in 1..<(cols - 1) {
                let i = y * cols + x
                // Anisotropic: stronger along horizontal paper fibers, modulated by grain.
                let g = grain[i]
                let lap = (field[i - 1] + field[i + 1] - 2 * field[i]) * 1.35 * g
                    + (field[i - cols] + field[i + cols] - 2 * field[i]) * 0.55
                next[i] = min(1, max(0, field[i] + lap * k * (0.25 + wet[i])))
                nextWet[i] = max(0, wet[i] - Float(dt) * 0.22)
            }
        }
        field = next
        wet = nextWet
    }
}

private enum InkBleedRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, field: [Float], cols: Int, rows: Int) {
        guard field.count == cols * rows else { return }
        let cw = size.width / CGFloat(cols)
        let rh = size.height / CGFloat(rows)
        for y in 0..<rows {
            for x in 0..<cols {
                let v = field[y * cols + x]
                if v < 0.04 { continue }
                let alpha = Double(min(1, v * 1.15))
                context.fill(
                    Path(CGRect(x: CGFloat(x) * cw, y: CGFloat(y) * rh, width: cw + 0.5, height: rh + 0.5)),
                    with: .color(Color(red: 0.12, green: 0.14, blue: 0.32).opacity(alpha))
                )
            }
        }
    }
}

#Preview { InkBleedView() }
