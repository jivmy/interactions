import QuartzCore
import SwiftUI

struct MatchbookView: View {
    @StateObject private var model = MatchbookModel()

    var body: some View {
        GeometryReader { geo in
            let drawState = MatchbookDrawState(model)
            ZStack {
                Color(red: 0.13, green: 0.09, blue: 0.08).ignoresSafeArea()
                if drawState.lit {
                    RadialGradient(
                        colors: [Color.orange.opacity(0.18 * Double(drawState.flame)), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 220
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
                Canvas { context, size in
                    MatchbookRenderer.draw(in: &context, size: size, state: drawState)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.drag(to: value.location, size: geo.size)
                        }
                        .onEnded { _ in
                            model.endDrag()
                        }
                )
                .accessibilityLabel(drawState.lit ? "Matchbook, burning" : "Matchbook")
                .accessibilityHint("Strike fast along the grit")

                LabHintOverlay(text: model.lit ? "Burning. Strike again after it dies." : "Strike fast along the grit. Slow is a scrape.")
            }
            .onAppear { model.start() }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class MatchbookModel: ObservableObject {
    @Published var matchTip = CGPoint.zero
    @Published var dragging = false
    @Published var lit = false
    @Published var flame: CGFloat = 0
    @Published var sparks: [CGPoint] = []
    @Published var failFlash: CGFloat = 0

    private let haptics = HapticPlayer()
    private let ticker = FrameTicker()
    private var lastPoint = CGPoint.zero
    private var lastTime: CFTimeInterval = 0
    private var peakSpeed: CGFloat = 0
    private var contacted = false
    private var burn: CGFloat = 0

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func striker(size: CGSize) -> CGRect {
        CGRect(x: size.width * 0.18, y: size.height * 0.62, width: size.width * 0.64, height: 26)
    }

    func drag(to point: CGPoint, size: CGSize) {
        if !dragging {
            dragging = true
            lastPoint = point
            lastTime = CACurrentMediaTime()
            peakSpeed = 0
            contacted = false
            if !lit { flame = 0; burn = 0 }
        }
        let now = CACurrentMediaTime()
        let dt = max(now - lastTime, 1 / 120)
        let speed = hypot(point.x - lastPoint.x, point.y - lastPoint.y) / dt
        peakSpeed = max(peakSpeed, speed)
        lastPoint = point
        lastTime = now
        matchTip = point
        if striker(size: size).insetBy(dx: -8, dy: -14).contains(point) {
            contacted = true
        }
    }

    func endDrag() {
        guard dragging else { return }
        dragging = false
        if contacted && peakSpeed > 2100 && !lit {
            lit = true
            flame = 1
            burn = 1
            haptics.ignite()
        } else if contacted && !lit {
            failFlash = 1
            sparks = (0..<10).map { _ in
                CGPoint(x: matchTip.x + CGFloat.random(in: -12...12), y: matchTip.y + CGFloat.random(in: -18...4))
            }
            haptics.scrape()
        }
        peakSpeed = 0
        contacted = false
    }

    private func step(dt: CGFloat) {
        if lit {
            burn = max(0, burn - dt * 0.22)
            flame = burn
            if burn <= 0 { lit = false }
        }
        failFlash = max(0, failFlash - dt * 3.2)
        if failFlash == 0 { sparks = [] }
    }
}

private struct MatchbookDrawState: Sendable {
    var matchTip: CGPoint
    var dragging: Bool
    var lit: Bool
    var flame: CGFloat
    var sparks: [CGPoint]
    var failFlash: CGFloat

    @MainActor
    init(_ model: MatchbookModel) {
        matchTip = model.matchTip
        dragging = model.dragging
        lit = model.lit
        flame = model.flame
        sparks = model.sparks
        failFlash = model.failFlash
    }
}

private enum MatchbookRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, state: MatchbookDrawState) {
        let book = CGRect(x: size.width * 0.16, y: size.height * 0.38, width: size.width * 0.68, height: size.height * 0.32)
        context.fill(Path(roundedRect: book, cornerRadius: 12), with: .color(Color(red: 0.70, green: 0.16, blue: 0.14)))
        context.stroke(Path(roundedRect: book, cornerRadius: 12), with: .color(Color(red: 0.42, green: 0.08, blue: 0.08)), lineWidth: 1)
        let cover = CGRect(x: book.minX + 12, y: book.minY + 14, width: book.width * 0.42, height: book.height - 28)
        context.fill(Path(roundedRect: cover, cornerRadius: 5), with: .color(Color(red: 0.58, green: 0.12, blue: 0.11)))

        let strip = CGRect(x: size.width * 0.18, y: size.height * 0.62, width: size.width * 0.64, height: 26)
        context.fill(Path(roundedRect: strip, cornerRadius: 4), with: .color(Color(red: 0.26, green: 0.16, blue: 0.11)))
        for i in 0..<22 {
            let x = strip.minX + 6 + CGFloat(i) * (strip.width - 12) / 21
            var grit = Path()
            grit.move(to: CGPoint(x: x, y: strip.minY + 4))
            grit.addLine(to: CGPoint(x: x + 2.2, y: strip.maxY - 4))
            context.stroke(grit, with: .color(Color(white: 0.42)), lineWidth: 1)
        }

        let rest = CGPoint(x: book.minX + 30, y: book.midY)
        let tip = state.dragging || state.lit ? state.matchTip : rest
        let shaftEnd = CGPoint(x: tip.x - 56, y: tip.y + 8)
        var shaft = Path()
        shaft.move(to: shaftEnd)
        shaft.addLine(to: tip)
        context.stroke(shaft, with: .color(Color(red: 0.86, green: 0.74, blue: 0.48)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        context.fill(
            Path(ellipseIn: CGRect(x: tip.x - 5.5, y: tip.y - 5.5, width: 11, height: 11)),
            with: .color(state.lit ? Color.orange : Color(red: 0.32, green: 0.10, blue: 0.07))
        )

        if state.lit && state.flame > 0 {
            let h = 18 + state.flame * 30
            let flame = CGRect(x: tip.x - 9, y: tip.y - h, width: 18, height: h)
            context.fill(Path(ellipseIn: flame.insetBy(dx: -8, dy: -8)), with: .color(Color.orange.opacity(0.22)))
            context.fill(Path(ellipseIn: flame), with: .color(Color.orange.opacity(0.92)))
            context.fill(Path(ellipseIn: flame.insetBy(dx: 4.5, dy: 7)), with: .color(Color.yellow.opacity(0.92)))
        }

        if state.failFlash > 0 {
            for s in state.sparks {
                context.fill(
                    Path(ellipseIn: CGRect(x: s.x, y: s.y, width: 3, height: 3)),
                    with: .color(Color.yellow.opacity(Double(state.failFlash)))
                )
            }
        }
    }
}

#Preview { MatchbookView() }
