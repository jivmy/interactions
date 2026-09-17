import SwiftUI

/// Lift the phone and a balloon climbs. Drag is the Simulator / no-barometer fallback.
struct BarometricBalloonView: View {
    @StateObject private var sim = BalloonSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.80, blue: 0.92),
                        Color(red: 0.90, green: 0.93, blue: 0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Canvas { context, size in
                    BalloonRenderer.draw(in: &context, size: size, y: sim.balloonY, stringTo: sim.groundY)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !sim.isHardware {
                                sim.dragY = value.location.y
                            }
                        }
                )

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
        if sim.isHardware {
            "Lift the phone — the balloon follows altitude"
        } else {
            "Drag the balloon — barometer needs a real iPhone"
        }
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
        groundY = size.height - 40
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
        let minY = ViewSpaceMotion.windowSafeAreaTop() + 90
        let maxY = restY + 40
        let target: CGFloat
        if altimeter.isHardware {
            // ~40 cm of lift fills most of the screen.
            let meters = CGFloat(altimeter.relativeMeters)
            let t = min(max(meters / 0.45, -0.3), 1.15)
            target = maxY - t * (maxY - minY)
        } else if let dragY {
            target = min(max(dragY, minY), maxY)
        } else {
            target = restY
        }
        displayed += (target - displayed) * 0.12
        balloonY = displayed
    }
}

private enum BalloonRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, y: CGFloat, stringTo: CGFloat) {
        let x = size.width * 0.5
        let top = CGPoint(x: x, y: y)
        var string = Path()
        string.move(to: CGPoint(x: x, y: y + 46))
        string.addQuadCurve(to: CGPoint(x: x + 8, y: stringTo - 10), control: CGPoint(x: x - 18, y: (y + stringTo) / 2))
        context.stroke(string, with: .color(.white.opacity(0.85)), lineWidth: 1.2)

        let knot = CGRect(x: x - 4, y: y + 40, width: 8, height: 10)
        context.fill(Path(roundedRect: knot, cornerRadius: 2), with: .color(Color(red: 0.75, green: 0.2, blue: 0.22)))

        let balloon = CGRect(x: x - 34, y: y - 52, width: 68, height: 86)
        context.fill(Path(ellipseIn: balloon), with: .color(Color(red: 0.86, green: 0.18, blue: 0.22)))
        context.fill(
            Path(ellipseIn: CGRect(x: x - 16, y: y - 40, width: 16, height: 22)),
            with: .color(.white.opacity(0.28))
        )

        // Ground
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: size.height - 28))
        ground.addLine(to: CGPoint(x: size.width, y: size.height - 28))
        context.stroke(ground, with: .color(Color(red: 0.45, green: 0.55, blue: 0.38)), lineWidth: 6)
    }
}

#Preview { BarometricBalloonView() }
