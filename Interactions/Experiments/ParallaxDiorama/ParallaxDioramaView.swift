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
                .accessibilityValue(model.faceTracking ? "Face tracking" : "Tilt")
                .accessibilityHint(hint)

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
        model.faceTracking ? "Lean." : "Tilt."
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

        let far = layer(0.10)
        context.fill(
            Path(CGRect(x: 4 + far.width, y: 86 + far.height, width: size.width - 8, height: size.height - 164)),
            with: .color(Color(red: 0.17, green: 0.22, blue: 0.30))
        )

        let back = layer(0.30)
        let backRect = CGRect(x: 36 + back.width, y: 124 + back.height, width: size.width - 72, height: size.height - 228)
        context.fill(Path(backRect), with: .color(Color(red: 0.40, green: 0.54, blue: 0.66)))
        context.fill(
            Path(CGRect(x: backRect.minX, y: backRect.minY, width: backRect.width, height: 22)),
            with: .color(Color(red: 0.30, green: 0.40, blue: 0.50))
        )
        let win = CGRect(x: cx - 68 + back.width, y: cy - 126 + back.height, width: 136, height: 90)
        context.fill(Path(roundedRect: win, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Color(red: 0.90, green: 0.95, blue: 0.99), Color(red: 0.68, green: 0.82, blue: 0.93)]),
            startPoint: CGPoint(x: win.minX, y: win.minY),
            endPoint: CGPoint(x: win.maxX, y: win.maxY)
        ))
        var muntin = Path()
        muntin.move(to: CGPoint(x: win.midX, y: win.minY))
        muntin.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        muntin.move(to: CGPoint(x: win.minX, y: win.midY))
        muntin.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        context.stroke(muntin, with: .color(Color.white.opacity(0.74)), lineWidth: 2)
        context.stroke(Path(roundedRect: win, cornerRadius: 4), with: .color(Color.white.opacity(0.52)), lineWidth: 3)
        let frame = CGRect(x: backRect.minX + 18 + back.width * 0.02, y: cy - 40 + back.height, width: 36, height: 28)
        context.fill(Path(roundedRect: frame, cornerRadius: 1), with: .color(Color(red: 0.72, green: 0.58, blue: 0.36)))
        context.fill(Path(roundedRect: frame.insetBy(dx: 3, dy: 3), cornerRadius: 1), with: .color(Color(red: 0.55, green: 0.62, blue: 0.48)))

        let mid = layer(0.74)
        var shaft = Path()
        shaft.move(to: CGPoint(x: win.minX + 8, y: win.maxY))
        shaft.addLine(to: CGPoint(x: win.maxX - 8, y: win.maxY))
        shaft.addLine(to: CGPoint(x: cx + 70 + mid.width, y: cy + 78 + mid.height))
        shaft.addLine(to: CGPoint(x: cx - 40 + mid.width, y: cy + 78 + mid.height))
        shaft.closeSubpath()
        context.fill(shaft, with: .color(Color.white.opacity(0.07)))

        var floor = Path()
        floor.move(to: CGPoint(x: 48 + mid.width, y: cy + 78 + mid.height))
        floor.addLine(to: CGPoint(x: size.width - 48 + mid.width, y: cy + 78 + mid.height))
        floor.addLine(to: CGPoint(x: size.width - 28 + mid.width, y: cy + 118 + mid.height))
        floor.addLine(to: CGPoint(x: 28 + mid.width, y: cy + 118 + mid.height))
        floor.closeSubpath()
        context.fill(floor, with: .color(Color(red: 0.36, green: 0.28, blue: 0.22)))
        for i in 0..<5 {
            let t = CGFloat(i) / 4
            var plank = Path()
            plank.move(to: CGPoint(x: 48 + t * (size.width - 96) + mid.width, y: cy + 78 + mid.height))
            plank.addLine(to: CGPoint(x: 28 + t * (size.width - 56) + mid.width, y: cy + 118 + mid.height))
            context.stroke(plank, with: .color(Color.black.opacity(0.12)), lineWidth: 1)
        }
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 52 + mid.width, y: cy + 92 + mid.height, width: 104, height: 16)),
            with: .color(Color(red: 0.42, green: 0.18, blue: 0.16).opacity(0.55))
        )
        let table = CGRect(x: cx - 94 + mid.width, y: cy + 36 + mid.height, width: 188, height: 15)
        context.fill(Path(table), with: .color(Color(red: 0.50, green: 0.32, blue: 0.18)))
        context.fill(Path(CGRect(x: table.minX + 16, y: table.maxY, width: 6, height: 28)), with: .color(Color(red: 0.38, green: 0.24, blue: 0.14)))
        context.fill(Path(CGRect(x: table.maxX - 22, y: table.maxY, width: 6, height: 28)), with: .color(Color(red: 0.38, green: 0.24, blue: 0.14)))
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 15 + mid.width, y: cy - 16 + mid.height, width: 30, height: 50)),
            with: .color(Color(red: 0.72, green: 0.18, blue: 0.22))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 8 + mid.width, y: cy - 20 + mid.height, width: 8, height: 10)),
            with: .color(.white.opacity(0.14))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx + 44 + mid.width, y: cy + 4 + mid.height, width: 36, height: 36)),
            with: .color(Color(red: 0.90, green: 0.78, blue: 0.34))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx + 52 + mid.width, y: cy + 8 + mid.height, width: 10, height: 8)),
            with: .color(.white.opacity(0.22))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: cx - 80 + mid.width, y: cy + 16 + mid.height, width: 20, height: 20)),
            with: .color(Color(red: 0.26, green: 0.42, blue: 0.36))
        )

        let front = layer(1.30)
        context.stroke(
            Path(roundedRect: CGRect(x: 14 + front.width, y: 102 + front.height, width: size.width - 28, height: size.height - 192), cornerRadius: 12),
            with: .color(Color(red: 0.13, green: 0.08, blue: 0.06)),
            lineWidth: 22
        )
        context.fill(Path(CGRect(x: 4 + front.width, y: 94 + front.height, width: 28, height: size.height - 180)), with: .color(Color(red: 0.46, green: 0.08, blue: 0.12)))
        context.fill(Path(CGRect(x: size.width - 32 + front.width, y: 94 + front.height, width: 28, height: size.height - 180)), with: .color(Color(red: 0.46, green: 0.08, blue: 0.12)))
        context.fill(Path(CGRect(x: 4 + front.width, y: 94 + front.height, width: size.width - 8, height: 16)), with: .color(Color(red: 0.40, green: 0.07, blue: 0.10)))
    }
}

#Preview { ParallaxDioramaView() }
