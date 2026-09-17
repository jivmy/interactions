import SwiftUI

/// Lift the phone and a balloon climbs. Drag is the Simulator / no-barometer fallback.
struct BarometricBalloonView: View {
    @StateObject private var sim = BalloonSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let balloonY = sim.balloonY
            let groundY = sim.groundY
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.52, green: 0.72, blue: 0.90),
                        Color(red: 0.76, green: 0.87, blue: 0.94),
                        Color(red: 0.93, green: 0.94, blue: 0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Canvas { context, size in
                    BalloonRenderer.draw(in: &context, size: size, y: balloonY, stringTo: groundY)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !sim.isHardware {
                                sim.dragY = value.location.y
                            }
                        }
                )
                .accessibilityLabel("Barometric balloon")
                .accessibilityHint(hint)

                LabHintOverlay(text: hint)
            }
            .onAppear {
                sim.updateViewport(size: geo.size)
                sim.start()
            }
            .onChange(of: geo.size) { _, size in sim.updateViewport(size: size) }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? sim.start() : sim.stop()
            }
            .onDisappear { sim.stop() }
        }
        .ignoresSafeArea()
    }

    private var hint: String {
        sim.isHardware ? "Lift." : "Drag."
    }
}

@MainActor
final class BalloonSimulation: ObservableObject {
    @Published var balloonY: CGFloat = 0
    @Published var groundY: CGFloat = 0
    @Published var isHardware = false
    var dragY: CGFloat?

    private let altimeter = AltimeterSource()
    private let ticker = FrameTicker()
    private var viewport: CGSize = .zero
    private var displayed: CGFloat = 0
    private var restY: CGFloat = 0

    func updateViewport(size: CGSize) {
        viewport = size
        groundY = size.height - 36
        restY = size.height * 0.58
        if displayed == 0 { displayed = restY }
        balloonY = displayed
    }

    func start() {
        altimeter.start()
        ticker.onTick = { [weak self] _ in self?.step() }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        altimeter.stop()
    }

    private func step() {
        isHardware = altimeter.isHardware
        let minY = ViewSpaceMotion.windowSafeAreaTop() + 96
        let maxY = restY + 40
        let target: CGFloat
        if altimeter.isHardware {
            let meters = CGFloat(altimeter.relativeMeters)
            let t = min(max(meters / 0.45, -0.3), 1.15)
            target = maxY - t * (maxY - minY)
        } else if let dragY {
            target = min(max(dragY, minY), maxY)
        } else {
            target = restY
        }
        displayed += (target - displayed) * 0.11
        balloonY = displayed
    }
}

private enum BalloonRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, y: CGFloat, stringTo: CGFloat) {
        let sun = CGPoint(x: size.width * 0.78, y: size.height * 0.14)
        context.fill(Path(ellipseIn: CGRect(x: sun.x - 38, y: sun.y - 38, width: 76, height: 76)), with: .color(Color(red: 1, green: 0.96, blue: 0.78).opacity(0.18)))
        context.fill(Path(ellipseIn: CGRect(x: sun.x - 16, y: sun.y - 16, width: 32, height: 32)), with: .color(Color(red: 1, green: 0.95, blue: 0.78).opacity(0.9)))

        let lift = max(0, min(1, (stringTo - y - 70) / max(stringTo - 180, 1)))
        let parallax = (1 - lift) * 10
        let clouds: [(CGFloat, CGFloat, CGFloat)] = [
            (0.16, 0.20, 38), (0.70, 0.16, 30), (0.40, 0.26, 22), (0.86, 0.24, 18)
        ]
        for (fx, fy, r) in clouds {
            let c = CGPoint(x: size.width * fx + parallax * 0.4, y: size.height * fy)
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.55, width: r * 2, height: r * 1.1)), with: .color(.white.opacity(0.34)))
            context.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.4, y: c.y - r * 0.78, width: r * 1.1, height: r * 0.9)), with: .color(.white.opacity(0.26)))
        }

        var far = Path()
        far.move(to: CGPoint(x: 0, y: size.height - 70))
        far.addQuadCurve(to: CGPoint(x: size.width, y: size.height - 58), control: CGPoint(x: size.width * 0.5, y: size.height - 124))
        far.addLine(to: CGPoint(x: size.width, y: size.height))
        far.addLine(to: CGPoint(x: 0, y: size.height))
        far.closeSubpath()
        context.fill(far, with: .color(Color(red: 0.58, green: 0.70, blue: 0.50).opacity(0.52)))

        context.fill(
            Path(CGRect(x: 0, y: size.height - 150, width: size.width, height: 70)),
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.0), Color.white.opacity(0.18)]),
                startPoint: CGPoint(x: 0, y: size.height - 150),
                endPoint: CGPoint(x: 0, y: size.height - 80)
            )
        )

        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: size.height - 16))
        hills.addQuadCurve(to: CGPoint(x: size.width * 0.36, y: size.height - 46), control: CGPoint(x: size.width * 0.16, y: size.height - 78))
        hills.addQuadCurve(to: CGPoint(x: size.width, y: size.height - 22), control: CGPoint(x: size.width * 0.72, y: size.height - 6))
        hills.addLine(to: CGPoint(x: size.width, y: size.height))
        hills.addLine(to: CGPoint(x: 0, y: size.height))
        hills.closeSubpath()
        context.fill(hills, with: .color(Color(red: 0.46, green: 0.62, blue: 0.38)))

        let sway = sin(y * 0.035) * (4 + lift * 6)
        let x = size.width * 0.5 + sway
        let shadowW = 26 + (1 - lift) * 26
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.5 - shadowW / 2, y: stringTo - 8, width: shadowW, height: 8)),
            with: .color(.black.opacity(0.10 + (1 - lift) * 0.10))
        )

        var string = Path()
        string.move(to: CGPoint(x: x, y: y + 50))
        string.addQuadCurve(
            to: CGPoint(x: size.width * 0.5 + 3, y: stringTo - 10),
            control: CGPoint(x: x - 20 + lift * 10, y: (y + stringTo) * 0.52)
        )
        context.stroke(string, with: .color(.white.opacity(0.88)), lineWidth: 1.1)

        let squash: CGFloat = 1 + (1 - lift) * 0.07
        let balloon = CGRect(x: x - 36 * squash, y: y - 56 / squash, width: 72 * squash, height: 92 / squash)
        context.fill(Path(ellipseIn: balloon), with: .color(Color(red: 0.86, green: 0.15, blue: 0.20)))
        context.fill(
            Path(ellipseIn: CGRect(x: x - 18 * squash, y: y - 44 / squash, width: 16 * squash, height: 24 / squash)),
            with: .color(.white.opacity(0.34))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: x + 10 * squash, y: y - 18 / squash, width: 9 * squash, height: 15 / squash)),
            with: .color(Color.black.opacity(0.06))
        )
        context.stroke(Path(ellipseIn: balloon), with: .color(Color.white.opacity(0.20)), lineWidth: 1)

        var knot = Path()
        knot.move(to: CGPoint(x: x - 6, y: y + 44))
        knot.addLine(to: CGPoint(x: x + 6, y: y + 44))
        knot.addLine(to: CGPoint(x: x + 3, y: y + 56))
        knot.addLine(to: CGPoint(x: x - 3, y: y + 56))
        knot.closeSubpath()
        context.fill(knot, with: .color(Color(red: 0.70, green: 0.14, blue: 0.18)))
        context.fill(
            Path(ellipseIn: CGRect(x: x - 3.5, y: y + 52, width: 7, height: 6)),
            with: .color(Color(red: 0.55, green: 0.10, blue: 0.14))
        )
    }
}

#Preview { BarometricBalloonView() }
