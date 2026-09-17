import SwiftUI

struct ZipperView: View {
    @StateObject private var model = ZipperModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.78, green: 0.74, blue: 0.68).ignoresSafeArea()
                Canvas { context, size in
                    ZipperRenderer.draw(in: &context, size: size, progress: model.progress)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.drag(y: value.location.y, height: geo.size.height)
                        }
                )
                LabHintOverlay(text: "Pull the slider. Each tooth ticks.")
            }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class ZipperModel: ObservableObject {
    static let teeth = 28
    @Published var progress: CGFloat = 0.18
    private var lastTooth = -1
    private let haptics = HapticPlayer()

    func drag(y: CGFloat, height: CGFloat) {
        let top = ViewSpaceMotion.windowSafeAreaTop() + 90
        let bottom = height - 80
        let t = (y - top) / max(bottom - top, 1)
        progress = min(max(t, 0), 1)
        let tooth = Int(progress * CGFloat(Self.teeth - 1))
        if tooth != lastTooth {
            lastTooth = tooth
            if tooth == Self.teeth - 1 || tooth == 0 {
                haptics.thud()
            } else {
                haptics.tick()
            }
        }
    }
}

private enum ZipperRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, progress: CGFloat) {
        let top = ViewSpaceMotion.windowSafeAreaTop() + 90
        let bottom = size.height - 80
        let x = size.width * 0.5
        let teeth = ZipperModel.teeth
        let sliderY = top + progress * (bottom - top)

        // Fabric panels
        context.fill(
            Path(CGRect(x: 0, y: 0, width: x - 6, height: size.height)),
            with: .color(Color(red: 0.22, green: 0.28, blue: 0.42))
        )
        context.fill(
            Path(CGRect(x: x + 6, y: 0, width: size.width - x - 6, height: size.height)),
            with: .color(Color(red: 0.20, green: 0.26, blue: 0.40))
        )

        for i in 0..<teeth {
            let ty = top + CGFloat(i) / CGFloat(teeth - 1) * (bottom - top)
            let open = ty > sliderY + 6
            let gap: CGFloat = open ? 16 : 0
            let left = CGRect(x: x - 18 - gap, y: ty - 6, width: 18, height: 11)
            let right = CGRect(x: x + gap, y: ty - 6, width: 18, height: 11)
            context.fill(Path(roundedRect: left, cornerRadius: 2), with: .color(Color(white: 0.72)))
            context.fill(Path(roundedRect: right, cornerRadius: 2), with: .color(Color(white: 0.66)))
        }

        var tape = Path()
        tape.move(to: CGPoint(x: x, y: top - 12))
        tape.addLine(to: CGPoint(x: x, y: sliderY))
        context.stroke(tape, with: .color(Color(white: 0.15)), lineWidth: 3)

        let pull = CGRect(x: x - 16, y: sliderY - 10, width: 32, height: 46)
        context.fill(Path(roundedRect: pull, cornerRadius: 6), with: .color(Color(red: 0.85, green: 0.72, blue: 0.25)))
        context.stroke(Path(roundedRect: pull, cornerRadius: 6), with: .color(Color(red: 0.45, green: 0.35, blue: 0.1)), lineWidth: 1.2)
        var hole = Path(ellipseIn: CGRect(x: x - 5, y: sliderY + 14, width: 10, height: 14))
        context.stroke(hole, with: .color(Color(red: 0.45, green: 0.35, blue: 0.1)), lineWidth: 2)
    }
}

#Preview { ZipperView() }
