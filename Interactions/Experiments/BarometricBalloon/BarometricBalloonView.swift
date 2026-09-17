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
                        Color(red: 0.55, green: 0.74, blue: 0.90),
                        Color(red: 0.78, green: 0.88, blue: 0.94),
                        Color(red: 0.91, green: 0.93, blue: 0.86)
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

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: sim.isHardware ? "Barometer live" : "Drag fallback")
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .allowsHitTesting(false)

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
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: size.height - 18))
        hills.addQuadCurve(to: CGPoint(x: size.width * 0.38, y: size.height - 42), control: CGPoint(x: size.width * 0.18, y: size.height - 70))
        hills.addQuadCurve(to: CGPoint(x: size.width, y: size.height - 24), control: CGPoint(x: size.width * 0.72, y: size.height - 8))
        hills.addLine(to: CGPoint(x: size.width, y: size.height))
        hills.addLine(to: CGPoint(x: 0, y: size.height))
        hills.closeSubpath()
        context.fill(hills, with: .color(Color(red: 0.48, green: 0.62, blue: 0.40)))

        let x = size.width * 0.5
        var string = Path()
        string.move(to: CGPoint(x: x, y: y + 48))
        string.addQuadCurve(to: CGPoint(x: x + 6, y: stringTo - 12), control: CGPoint(x: x - 20, y: (y + stringTo) / 2))
        context.stroke(string, with: .color(.white.opacity(0.88)), lineWidth: 1.15)

        context.fill(
            Path(roundedRect: CGRect(x: x - 5, y: y + 42, width: 10, height: 12), cornerRadius: 2),
            with: .color(Color(red: 0.72, green: 0.16, blue: 0.20))
        )

        let balloon = CGRect(x: x - 36, y: y - 54, width: 72, height: 90)
        context.fill(Path(ellipseIn: balloon), with: .color(Color(red: 0.86, green: 0.16, blue: 0.22)))
        context.fill(
            Path(ellipseIn: CGRect(x: x - 18, y: y - 42, width: 16, height: 24)),
            with: .color(.white.opacity(0.30))
        )
        context.stroke(Path(ellipseIn: balloon), with: .color(Color.white.opacity(0.16)), lineWidth: 1)
    }
}

#Preview { BarometricBalloonView() }
