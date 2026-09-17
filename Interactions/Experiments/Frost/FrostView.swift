import SwiftUI

struct FrostView: View {
    @StateObject private var model = FrostModel()

    var body: some View {
        GeometryReader { geo in
            let crystals = model.crystals
            ZStack {
                Color(red: 0.08, green: 0.11, blue: 0.16).ignoresSafeArea()
                Canvas { context, size in
                    FrostRenderer.draw(in: &context, crystals: crystals)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.seed(at: value.location)
                        }
                )
                LabHintOverlay(text: "Touch the pane. Ice ferns out.")
            }
            .onAppear { model.start() }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

private struct Crystal {
    var points: [CGPoint]
    var heading: CGFloat
    var alive: Bool
    var width: CGFloat
}

@MainActor
final class FrostModel: ObservableObject {
    @Published var crystals: [[CGPoint]] = []

    private var growing: [Crystal] = []
    private let ticker = FrameTicker()
    private var lastSeed = CGPoint(x: -999, y: -999)
    private var cooldown: CGFloat = 0

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func seed(at point: CGPoint) {
        guard cooldown <= 0 || hypot(point.x - lastSeed.x, point.y - lastSeed.y) > 28 else { return }
        lastSeed = point
        cooldown = 0.08
        let count = 5 + Int.random(in: 0...3)
        for i in 0..<count {
            let heading = CGFloat(i) / CGFloat(count) * .pi * 2 + CGFloat.random(in: -0.2...0.2)
            growing.append(Crystal(points: [point], heading: heading, alive: true, width: CGFloat.random(in: 0.8...1.8)))
        }
    }

    private func step(dt: CGFloat) {
        cooldown = max(0, cooldown - dt)
        let speed: CGFloat = 46
        var spawned: [Crystal] = []
        for i in growing.indices where growing[i].alive {
            var heading = growing[i].heading + CGFloat.random(in: -0.18...0.18)
            if Bool.random() && growing[i].points.count > 4 && growing[i].points.count < 80 && Float.random(in: 0...1) < 0.045 {
                spawned.append(Crystal(
                    points: [growing[i].points.last!],
                    heading: heading + CGFloat.random(in: 0.5...1.1) * (Bool.random() ? 1 : -1),
                    alive: true,
                    width: growing[i].width * 0.7
                ))
            }
            let last = growing[i].points.last!
            let next = CGPoint(x: last.x + cos(heading) * speed * dt, y: last.y + sin(heading) * speed * dt)
            growing[i].heading = heading
            growing[i].points.append(next)
            if growing[i].points.count > 90 { growing[i].alive = false }
        }
        growing.append(contentsOf: spawned)
        if growing.count > 180 {
            growing.removeFirst(growing.count - 180)
        }
        crystals = growing.map(\.points)
    }
}

private enum FrostRenderer {
    static func draw(in context: inout GraphicsContext, crystals: [[CGPoint]]) {
        for points in crystals where points.count >= 2 {
            var path = Path()
            path.move(to: points[0])
            for p in points.dropFirst() { path.addLine(to: p) }
            context.stroke(
                path,
                with: .color(Color(red: 0.82, green: 0.90, blue: 1.0).opacity(0.7)),
                style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

#Preview { FrostView() }
