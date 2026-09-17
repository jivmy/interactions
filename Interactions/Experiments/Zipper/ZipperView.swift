import SwiftUI

struct ZipperView: View {
    @StateObject private var model = ZipperModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let progress = model.progress
            let teeth = ZipperModel.teeth
            let safeAreaTop = ViewSpaceMotion.windowSafeAreaTop()
            ZStack {
                Color(red: 0.74, green: 0.70, blue: 0.64).ignoresSafeArea()
                Canvas { context, size in
                    ZipperRenderer.draw(in: &context, size: size, progress: progress, teeth: teeth, safeAreaTop: safeAreaTop)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.drag(y: value.location.y, height: geo.size.height)
                        }
                        .onEnded { _ in
                            model.endDrag()
                        }
                )
                .accessibilityLabel("Zipper")
                .accessibilityValue("\(Int(progress * 100)) percent closed")
                .accessibilityHint("Pull the slider. Each tooth ticks.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.nudge(teeth: 1)
                    case .decrement: model.nudge(teeth: -1)
                    default: break
                    }
                }

                LabHintOverlay(text: "Pull.")
            }
        }
        .onAppear { model.wake() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.sleep() } else { model.wake() }
        }
        .onDisappear { model.sleep() }
        .ignoresSafeArea()
    }
}

@MainActor
final class ZipperModel: ObservableObject {
    nonisolated static let teeth = 28
    @Published var progress: CGFloat = 0.18
    private var lastTooth = -1
    private let haptics = HapticPlayer()

    func drag(y: CGFloat, height: CGFloat) {
        if lastTooth < 0 {
            haptics.startZipper()
        }
        let top = ViewSpaceMotion.windowSafeAreaTop() + 90
        let bottom = height - 80
        let t = (y - top) / max(bottom - top, 1)
        progress = min(max(t, 0), 1)
        let tooth = Int(progress * CGFloat(Self.teeth - 1))
        if tooth != lastTooth {
            lastTooth = tooth
            haptics.zipperTick(at: tooth, of: Self.teeth)
        }
    }

    func endDrag() {
        haptics.stopZipper()
        lastTooth = -1
    }

    func wake() { haptics.startEngine() }

    func sleep() {
        endDrag()
        haptics.shutdown()
    }

    func nudge(teeth delta: Int) {
        let current = Int((progress * CGFloat(Self.teeth - 1)).rounded())
        let next = min(max(current + delta, 0), Self.teeth - 1)
        guard next != current else { return }
        progress = CGFloat(next) / CGFloat(Self.teeth - 1)
        lastTooth = next
        haptics.zipperTick(at: next, of: Self.teeth)
    }
}

private enum ZipperRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, progress: CGFloat, teeth: Int, safeAreaTop: CGFloat) {
        let top = safeAreaTop + 90
        let bottom = size.height - 80
        let x = size.width * 0.5
        let sliderY = top + progress * (bottom - top)

        context.fill(
            Path(CGRect(x: 0, y: 0, width: x - 6, height: size.height)),
            with: .color(Color(red: 0.20, green: 0.27, blue: 0.40))
        )
        context.fill(
            Path(CGRect(x: x + 6, y: 0, width: size.width - x - 6, height: size.height)),
            with: .color(Color(red: 0.17, green: 0.24, blue: 0.37))
        )

        for i in stride(from: 0, through: Int(size.height), by: 10) {
            var stitch = Path()
            stitch.move(to: CGPoint(x: x - 22, y: CGFloat(i)))
            stitch.addLine(to: CGPoint(x: x - 16, y: CGFloat(i) + 4))
            context.stroke(stitch, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            var stitchR = Path()
            stitchR.move(to: CGPoint(x: x + 16, y: CGFloat(i)))
            stitchR.addLine(to: CGPoint(x: x + 22, y: CGFloat(i) + 4))
            context.stroke(stitchR, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
        }

        for i in 0..<teeth {
            let ty = top + CGFloat(i) / CGFloat(teeth - 1) * (bottom - top)
            let open = ty > sliderY + 6
            let gap: CGFloat = open ? 15 : 0
            let left = CGRect(x: x - 17 - gap, y: ty - 5.5, width: 17, height: 10)
            let right = CGRect(x: x + gap, y: ty - 5.5, width: 17, height: 10)
            context.fill(Path(roundedRect: left, cornerRadius: 1.5), with: .color(Color(white: 0.78)))
            context.fill(Path(roundedRect: CGRect(x: left.minX + 2, y: left.minY + 1.5, width: 6, height: 3), cornerRadius: 1), with: .color(.white.opacity(0.28)))
            context.fill(Path(roundedRect: right, cornerRadius: 1.5), with: .color(Color(white: 0.70)))
            context.fill(Path(roundedRect: CGRect(x: right.minX + 2, y: right.minY + 1.5, width: 5, height: 3), cornerRadius: 1), with: .color(.white.opacity(0.16)))
            if !open {
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 2, y: ty - 2, width: 4, height: 4)),
                    with: .color(Color(white: 0.55))
                )
            }
        }

        var tape = Path()
        tape.move(to: CGPoint(x: x, y: top - 14))
        tape.addLine(to: CGPoint(x: x, y: sliderY))
        context.stroke(tape, with: .color(Color(white: 0.12)), lineWidth: 3.2)

        context.fill(
            Path(ellipseIn: CGRect(x: x - 16, y: sliderY + 28, width: 32, height: 10)),
            with: .color(LabShadow.ground())
        )
        let pull = CGRect(x: x - 15, y: sliderY - 8, width: 30, height: 48)
        context.fill(Path(roundedRect: pull, cornerRadius: 7), with: .color(LabPalette.brass))
        context.fill(
            Path(roundedRect: CGRect(x: x - 10, y: sliderY - 4, width: 8, height: 20), cornerRadius: 2),
            with: .color(Color.white.opacity(0.22))
        )
        context.stroke(Path(roundedRect: pull, cornerRadius: 7), with: .color(Color(red: 0.42, green: 0.32, blue: 0.10)), lineWidth: 1.1)
        context.stroke(
            Path(ellipseIn: CGRect(x: x - 5, y: sliderY + 16, width: 10, height: 14)),
            with: .color(Color(red: 0.42, green: 0.32, blue: 0.10)),
            lineWidth: 2
        )
    }
}

#Preview { ZipperView() }
