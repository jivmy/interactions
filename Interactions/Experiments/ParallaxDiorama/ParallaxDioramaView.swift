import SwiftUI

struct ParallaxDioramaView: View {
    @StateObject private var model = DioramaModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.10).ignoresSafeArea()
                Canvas { context, size in
                    DioramaRenderer.draw(in: &context, size: size, offset: model.offset)
                }
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

        let back = layer(0.25)
        context.fill(
            Path(CGRect(x: 24 + back.width, y: 120 + back.height, width: size.width - 48, height: size.height - 220)),
            with: .color(Color(red: 0.35, green: 0.48, blue: 0.62))
        )
        // Window
        let win = CGRect(x: cx - 70 + back.width, y: cy - 110 + back.height, width: 140, height: 90)
        context.fill(Path(roundedRect: win, cornerRadius: 4), with: .color(Color(red: 0.75, green: 0.88, blue: 0.95)))
        context.stroke(Path(roundedRect: win, cornerRadius: 4), with: .color(Color.white.opacity(0.5)), lineWidth: 3)

        let mid = layer(0.7)
        // Table
        context.fill(
            Path(CGRect(x: cx - 90 + mid.width, y: cy + 40 + mid.height, width: 180, height: 14)),
            with: .color(Color(red: 0.45, green: 0.28, blue: 0.16))
        )
        // Vase
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 16 + mid.width, y: cy - 10 + mid.height, width: 32, height: 50)),
            with: .color(Color(red: 0.72, green: 0.22, blue: 0.25))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx + 40 + mid.width, y: cy + 8 + mid.height, width: 36, height: 36)),
            with: .color(Color(red: 0.9, green: 0.78, blue: 0.35))
        )

        let front = layer(1.25)
        // Frame / proscenium
        var frame = Path(roundedRect: CGRect(x: 18 + front.width, y: 108 + front.height, width: size.width - 36, height: size.height - 200), cornerRadius: 10)
        context.stroke(frame, with: .color(Color(red: 0.15, green: 0.1, blue: 0.08)), lineWidth: 22)
        // Curtain edges
        context.fill(
            Path(CGRect(x: 8 + front.width, y: 100 + front.height, width: 28, height: size.height - 190)),
            with: .color(Color(red: 0.45, green: 0.08, blue: 0.12))
        )
        context.fill(
            Path(CGRect(x: size.width - 36 + front.width, y: 100 + front.height, width: 28, height: size.height - 190)),
            with: .color(Color(red: 0.45, green: 0.08, blue: 0.12))
        )
    }
}

#Preview { ParallaxDioramaView() }
