import SwiftUI

struct ParallaxDioramaView: View {
    @StateObject private var model = DioramaModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { _ in
            let offset = model.offset
            ZStack {
                Color(red: 0.06, green: 0.07, blue: 0.09).ignoresSafeArea()
                Canvas { context, size in
                    DioramaRenderer.draw(in: &context, size: size, offset: offset)
                }
                .accessibilityLabel("Parallax diorama")
                .accessibilityHint(hint)

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: model.faceTracking ? "Head tracking" : "Tilt fallback")
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .allowsHitTesting(false)

                LabHintOverlay(text: hint)
            }
            .onAppear { model.start() }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }

    private var hint: String {
        if model.faceTracking {
            "Move your head — the room is an off-axis projection"
        } else {
            "Tilt — Face ID head tracking unavailable"
        }
    }
}

@MainActor
final class DioramaModel: ObservableObject {
    @Published var offset = CGSize.zero
    @Published var faceTracking = false

    private let face = FaceTrackingSource()
    private let motion = DeviceMotionSource()
    private let ticker = FrameTicker()
    private var displayed = CGSize.zero

    func start() {
        face.start()
        motion.start()
        ticker.onTick = { [weak self] _ in self?.step() }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        face.stop()
        motion.stop()
    }

    private func step() {
        faceTracking = face.isTracking
        let target: CGSize
        if face.isTracking {
            target = face.offset
        } else {
            let a = ViewSpaceMotion.acceleration(motion.acceleration, interface: ViewSpaceMotion.currentInterfaceOrientation())
            target = CGSize(width: a.dx * 0.7, height: (a.dy - 1) * 0.45)
        }
        displayed.width += (target.width - displayed.width) * 0.16
        displayed.height += (target.height - displayed.height) * 0.16
        offset = displayed
    }
}

private enum DioramaRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, offset: CGSize) {
        let cx = size.width / 2
        let cy = size.height * 0.52
        func layer(_ depth: CGFloat) -> CGSize {
            CGSize(width: offset.width * depth * 28, height: offset.height * depth * 22)
        }

        let far = layer(0.12)
        context.fill(
            Path(CGRect(x: 8 + far.width, y: 90 + far.height, width: size.width - 16, height: size.height - 170)),
            with: .color(Color(red: 0.22, green: 0.28, blue: 0.36))
        )

        let back = layer(0.28)
        context.fill(
            Path(CGRect(x: 28 + back.width, y: 118 + back.height, width: size.width - 56, height: size.height - 214)),
            with: .color(Color(red: 0.36, green: 0.50, blue: 0.64))
        )
        let win = CGRect(x: cx - 72 + back.width, y: cy - 118 + back.height, width: 144, height: 94)
        context.fill(Path(roundedRect: win, cornerRadius: 5), with: .color(Color(red: 0.78, green: 0.90, blue: 0.96)))
        var muntin = Path()
        muntin.move(to: CGPoint(x: win.midX, y: win.minY))
        muntin.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        muntin.move(to: CGPoint(x: win.minX, y: win.midY))
        muntin.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        context.stroke(muntin, with: .color(Color.white.opacity(0.7)), lineWidth: 2)
        context.stroke(Path(roundedRect: win, cornerRadius: 5), with: .color(Color.white.opacity(0.55)), lineWidth: 3)

        let mid = layer(0.72)
        context.fill(
            Path(CGRect(x: 40 + mid.width, y: cy + 70 + mid.height, width: size.width - 80, height: 10)),
            with: .color(Color(red: 0.38, green: 0.30, blue: 0.24))
        )
        context.fill(
            Path(CGRect(x: cx - 96 + mid.width, y: cy + 38 + mid.height, width: 192, height: 16)),
            with: .color(Color(red: 0.48, green: 0.30, blue: 0.17))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 16 + mid.width, y: cy - 12 + mid.height, width: 32, height: 52)),
            with: .color(Color(red: 0.72, green: 0.20, blue: 0.24))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx + 42 + mid.width, y: cy + 6 + mid.height, width: 38, height: 38)),
            with: .color(Color(red: 0.90, green: 0.78, blue: 0.34))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 78 + mid.width, y: cy + 18 + mid.height, width: 22, height: 22)),
            with: .color(Color(red: 0.28, green: 0.42, blue: 0.36))
        )

        let front = layer(1.28)
        var frame = Path(roundedRect: CGRect(x: 16 + front.width, y: 104 + front.height, width: size.width - 32, height: size.height - 196), cornerRadius: 12)
        context.stroke(frame, with: .color(Color(red: 0.14, green: 0.09, blue: 0.07)), lineWidth: 24)
        context.fill(
            Path(CGRect(x: 6 + front.width, y: 96 + front.height, width: 30, height: size.height - 184)),
            with: .color(Color(red: 0.46, green: 0.08, blue: 0.12))
        )
        context.fill(
            Path(CGRect(x: size.width - 36 + front.width, y: 96 + front.height, width: 30, height: size.height - 184)),
            with: .color(Color(red: 0.46, green: 0.08, blue: 0.12))
        )
        context.fill(
            Path(CGRect(x: 6 + front.width, y: 96 + front.height, width: size.width - 12, height: 18)),
            with: .color(Color(red: 0.40, green: 0.07, blue: 0.10))
        )
    }
}

#Preview { ParallaxDioramaView() }
