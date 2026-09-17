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
                LabHintOverlay(text: model.stamped ? "Sealed. Press again to melt a new pool." : "Press and hold. Release to stamp.")
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
    private var rumbleAcc: CGFloat = 0

    func start() {
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() { ticker.stop() }

    func press(at point: CGPoint) {
        if !pressing {
            pressing = true
            stamped = false
            impression = 0
            melt = 0.05
        }
        poolCenter = point
        stamp = point
    }

    func release() {
        guard pressing else { return }
        pressing = false
        if melt > 0.55 {
            stamped = true
            impression = 1
            haptics.thud()
        } else {
            haptics.tick()
            melt *= 0.4
        }
    }

    private func step(dt: CGFloat) {
        if pressing {
            melt = min(1, melt + dt * 0.45)
            rumbleAcc += dt
            if rumbleAcc > 0.08 {
                rumbleAcc = 0
                haptics.meltRumble(intensity: Float(melt))
            }
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
        // Paper
        let sheet = CGRect(x: size.width * 0.12, y: size.height * 0.28, width: size.width * 0.76, height: size.height * 0.44)
        context.fill(Path(roundedRect: sheet, cornerRadius: 4), with: .color(Color(red: 0.96, green: 0.93, blue: 0.86)))
        context.stroke(Path(roundedRect: sheet, cornerRadius: 4), with: .color(Color(red: 0.78, green: 0.72, blue: 0.62)), lineWidth: 1)

        let center = state.stamp ?? CGPoint(x: size.width * 0.5, y: size.height * 0.52)
        let radius = 22 + state.melt * 38
        let wax = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.86, width: radius * 2, height: radius * 1.72))
        let waxColor = Color(red: 0.70 + state.melt * 0.12, green: 0.12, blue: 0.14)
        if state.melt > 0.02 || state.stamped {
            context.fill(wax, with: .color(waxColor.opacity(0.55 + state.melt * 0.4)))
        }

        if state.stamped {
            let r = radius * 0.72
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.45, green: 0.08, blue: 0.1).opacity(0.85)),
                lineWidth: 3
            )
            var star = Path()
            for i in 0..<8 {
                let a = Double(i) / 8 * .pi * 2 - .pi / 2
                let p = CGPoint(x: center.x + CGFloat(cos(a)) * r * 0.45, y: center.y + CGFloat(sin(a)) * r * 0.45)
                if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            context.stroke(star, with: .color(Color(red: 0.4, green: 0.08, blue: 0.1)), lineWidth: 2)
        }

        if state.pressing {
            let stampRect = CGRect(x: center.x - 34, y: center.y - 80 - (1 - state.melt) * 20, width: 68, height: 36)
            context.fill(Path(roundedRect: stampRect, cornerRadius: 4), with: .color(LabPalette.metal))
        }
    }
}

#Preview { WaxSealView() }
