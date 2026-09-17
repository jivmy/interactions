import SwiftUI

struct WaxSealView: View {
    @StateObject private var model = WaxSealModel()

    var body: some View {
        GeometryReader { geo in
            let drawState = WaxSealDrawState(model)
            ZStack {
                Color(red: 0.90, green: 0.86, blue: 0.78).ignoresSafeArea()
                Canvas { context, size in
                    WaxSealRenderer.draw(in: &context, size: size, state: drawState)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.press(at: value.location)
                        }
                        .onEnded { _ in
                            model.release()
                        }
                )
                .accessibilityLabel(drawState.stamped ? "Wax seal, stamped" : "Wax seal")
                .accessibilityHint("Press and hold to melt, release to stamp")

                LabHintOverlay(text: model.stamped ? "Again." : "Hold.")
            }
            .onAppear { model.start() }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class WaxSealModel: ObservableObject {
    @Published var melt: CGFloat = 0
    @Published var pressing = false
    @Published var stamp: CGPoint?
    @Published var stamped = false
    @Published var poolCenter = CGPoint.zero
    @Published var impression: CGFloat = 0

    private let haptics = HapticPlayer()
    private let ticker = FrameTicker()

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        haptics.stopMelt()
        ticker.stop()
    }

    func press(at point: CGPoint) {
        if !pressing {
            pressing = true
            stamped = false
            impression = 0
            melt = 0.05
            haptics.startMelt(intensity: 0.12)
        }
        poolCenter = point
        stamp = point
    }

    func release() {
        guard pressing else { return }
        pressing = false
        haptics.stopMelt()
        if melt > 0.55 {
            stamped = true
            impression = 1
            haptics.thud()
        } else {
            haptics.failure()
            melt *= 0.4
        }
    }

    private func step(dt: CGFloat) {
        if pressing {
            melt = min(1, melt + dt * 0.45)
            haptics.updateMelt(intensity: Float(melt))
        } else if !stamped {
            melt = max(0, melt - dt * 0.15)
        }
        if stamped {
            impression = min(1, impression + dt * 2.5)
        }
    }
}

private struct WaxSealDrawState: Sendable {
    var melt: CGFloat
    var pressing: Bool
    var stamp: CGPoint?
    var stamped: Bool

    @MainActor
    init(_ model: WaxSealModel) {
        melt = model.melt
        pressing = model.pressing
        stamp = model.stamp
        stamped = model.stamped
    }
}

private enum WaxSealRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, state: WaxSealDrawState) {
        let sheet = CGRect(x: size.width * 0.12, y: size.height * 0.28, width: size.width * 0.76, height: size.height * 0.44)
        context.fill(
            Path(roundedRect: CGRect(x: sheet.minX + 5, y: sheet.maxY - 2, width: sheet.width, height: 8), cornerRadius: 3),
            with: .color(LabShadow.ground().opacity(0.45))
        )
        context.fill(Path(roundedRect: sheet, cornerRadius: 5), with: .color(Color(red: 0.965, green: 0.94, blue: 0.87)))
        context.stroke(Path(roundedRect: sheet, cornerRadius: 5), with: .color(Color(red: 0.78, green: 0.72, blue: 0.62)), lineWidth: 1)
        for i in 0..<7 {
            let y = sheet.minY + 28 + CGFloat(i) * 16
            var line = Path()
            line.move(to: CGPoint(x: sheet.minX + 22, y: y))
            line.addLine(to: CGPoint(x: sheet.maxX - 22, y: y))
            context.stroke(line, with: .color(Color(red: 0.78, green: 0.72, blue: 0.62).opacity(0.35)), lineWidth: 1)
        }

        let center = state.stamp ?? CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        let radius = 22 + state.melt * 38
        let wax = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.86, width: radius * 2, height: radius * 1.72))
        let waxColor = Color(red: 0.70 + state.melt * 0.10, green: 0.11, blue: 0.14)
        if state.melt > 0.02 || state.stamped {
            context.fill(wax, with: .color(waxColor.opacity(0.58 + state.melt * 0.38)))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius * 0.35, y: center.y - radius * 0.55, width: radius * 0.4, height: radius * 0.28)),
                with: .color(Color.white.opacity(0.16 + state.melt * 0.12))
            )
        }

        if state.stamped {
            let r = radius * 0.72
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.42, green: 0.07, blue: 0.09).opacity(0.88)),
                lineWidth: 3
            )
            var star = Path()
            for i in 0..<8 {
                let a = Double(i) / 8 * .pi * 2 - .pi / 2
                let p = CGPoint(x: center.x + CGFloat(cos(a)) * r * 0.45, y: center.y + CGFloat(sin(a)) * r * 0.45)
                if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            context.stroke(star, with: .color(Color(red: 0.38, green: 0.07, blue: 0.09)), lineWidth: 2)
        }

        if state.pressing {
            let stampRect = CGRect(x: center.x - 34, y: center.y - 82 - (1 - state.melt) * 18, width: 68, height: 36)
            context.fill(Path(roundedRect: stampRect, cornerRadius: 5), with: .color(LabPalette.metal))
            context.fill(
                Path(roundedRect: CGRect(x: stampRect.minX + 8, y: stampRect.minY + 5, width: 22, height: 6), cornerRadius: 2),
                with: .color(.white.opacity(0.16))
            )
        }
    }
}

#Preview { WaxSealView() }
