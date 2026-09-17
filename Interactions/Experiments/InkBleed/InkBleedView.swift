import SwiftUI

struct InkBleedView: View {
    @StateObject private var model = InkBleedModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let field = model.field
            let cols = model.cols
            let rows = model.rows
            ZStack {
                LabPalette.paperDeep.ignoresSafeArea()
                Canvas { context, size in
                    InkBleedRenderer.draw(in: &context, size: size, field: field, cols: cols, rows: rows)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.stamp(at: value.location, size: geo.size)
                        }
                )
                .accessibilityLabel("Ink bleed paper")
                .accessibilityHint("Touch the paper. Ink wicks along the grain.")

                LabHintOverlay(text: "Touch.")
            }
            .onAppear {
                model.ensure(size: geo.size)
                model.start()
            }
            .onChange(of: geo.size) { _, size in model.ensure(size: size) }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class InkBleedModel: ObservableObject {
    let cols = 64
    let rows = 112
    @Published var field: [Float] = []
    private var cells: [Float] = []
    private var grain: [Float] = []
    private let ticker = FrameTicker()
    private var size: CGSize = .zero
    private var wet: [Float] = []
    private var publishAccum: CGFloat = 0

    func ensure(size: CGSize) {
        self.size = size
        if cells.count != cols * rows {
            cells = Array(repeating: 0, count: cols * rows)
            field = cells
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
                    cells[i] = min(1, cells[i] + 0.55 * max(0, falloff))
                    wet[i] = min(1, wet[i] + 0.8)
                }
            }
        }
        field = cells
    }

    private func step(dt: CGFloat) {
        guard cells.count == cols * rows else { return }
        var next = cells
        var nextWet = wet
        let k = Float(dt) * 3.2
        for y in 1..<(rows - 1) {
            for x in 1..<(cols - 1) {
                let i = y * cols + x
                let g = grain[i]
                let lap = (cells[i - 1] + cells[i + 1] - 2 * cells[i]) * 1.35 * g
                    + (cells[i - cols] + cells[i + cols] - 2 * cells[i]) * 0.55
                next[i] = min(1, max(0, cells[i] + lap * k * (0.25 + wet[i])))
                nextWet[i] = max(0, wet[i] - Float(dt) * 0.22)
            }
        }
        cells = next
        wet = nextWet
        publishAccum += dt
        if publishAccum >= 1.0 / 60.0 {
            publishAccum = 0
            field = cells
        }
    }
}

private enum InkBleedRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, field: [Float], cols: Int, rows: Int) {
        guard field.count == cols * rows else { return }
        let sheet = CGRect(x: size.width * 0.06, y: size.height * 0.14, width: size.width * 0.88, height: size.height * 0.70)
        context.fill(
            Path(roundedRect: CGRect(x: sheet.minX + 4, y: sheet.maxY - 2, width: sheet.width, height: 6), cornerRadius: 2),
            with: .color(.black.opacity(0.06))
        )
        context.fill(Path(roundedRect: sheet, cornerRadius: 4), with: .color(Color(red: 0.96, green: 0.93, blue: 0.86)))
        context.stroke(Path(roundedRect: sheet, cornerRadius: 4), with: .color(Color(red: 0.78, green: 0.72, blue: 0.62)), lineWidth: 1)
        for i in 0..<18 {
            let yy = sheet.minY + 10 + CGFloat(i) * (sheet.height - 20) / 17
            var fiber = Path()
            fiber.move(to: CGPoint(x: sheet.minX + 8, y: yy))
            fiber.addLine(to: CGPoint(x: sheet.maxX - 8, y: yy))
            context.stroke(fiber, with: .color(Color(red: 0.78, green: 0.70, blue: 0.56).opacity(0.10)), lineWidth: 0.6)
        }

        context.drawLayer { inner in
            inner.clip(to: Path(roundedRect: sheet.insetBy(dx: 3, dy: 3), cornerRadius: 3))
            drawInk(in: &inner, size: size, field: field, cols: cols, rows: rows)
        }
    }

    private static func drawInk(in context: inout GraphicsContext, size: CGSize, field: [Float], cols: Int, rows: Int) {
        let cw = size.width / CGFloat(cols)
        let rh = size.height / CGFloat(rows)
        for y in 0..<rows {
            var x = 0
            while x < cols {
                let v = field[y * cols + x]
                if v < 0.04 {
                    x += 1
                    continue
                }
                let start = x
                x += 1
                while x < cols && field[y * cols + x] >= 0.04 { x += 1 }
                let avg = field[y * cols + start]
                let alpha = Double(min(1, avg * 1.15))
                context.fill(
                    Path(CGRect(x: CGFloat(start) * cw, y: CGFloat(y) * rh, width: CGFloat(x - start) * cw + 0.4, height: rh + 0.4)),
                    with: .color(Color(red: 0.10, green: 0.13, blue: 0.32).opacity(alpha))
                )
            }
        }
    }
}

#Preview { InkBleedView() }
