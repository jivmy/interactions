import SwiftUI

/// Combination dial with a haptic click per notch and a heavy clunk on the drop.
struct SafeDialView: View {
    @StateObject private var model = SafeDialModel()

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.52)
            ZStack {
                Color(red: 0.13, green: 0.13, blue: 0.14).ignoresSafeArea()
                Canvas { context, size in
                    SafeDialRenderer.draw(in: &context, size: size, angle: model.angle, notch: model.notch, open: model.isOpen)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.drag(to: value.location, center: center)
                        }
                        .onEnded { _ in
                            model.endDrag()
                        }
                )
                LabHintOverlay(text: model.isOpen ? "Open. Spin off the drop to close." : "Turn the dial. Last notch clunks.")
            }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class SafeDialModel: ObservableObject {
    static let notches = 40
    /// Unlock sits on notch 0 — the drop.
    let dropNotch = 0

    @Published var angle: Double = 0
    @Published var notch: Int = 0
    @Published var isOpen = false

    private let haptics = HapticPlayer()
    private var lastNotch = 0
    private var lastFingerAngle: Double?
    private var passedDrop = false

    func drag(to point: CGPoint, center: CGPoint) {
        let finger = atan2(Double(point.y - center.y), Double(point.x - center.x))
        if let last = lastFingerAngle {
            var delta = finger - last
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            angle += delta
        }
        lastFingerAngle = finger
        let tau = Double.pi * 2
        let n = SafeDialModel.notches
        var idx = Int(floor(((-angle / tau).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * Double(n)))
        idx = (idx + n) % n
        if idx != lastNotch {
            lastNotch = idx
            notch = idx
            if idx == dropNotch {
                haptics.clunk()
                isOpen = true
                passedDrop = true
            } else {
                haptics.click(intensity: 0.5, sharpness: 0.9)
                if passedDrop && abs(idx - dropNotch) > 2 {
                    isOpen = false
                    passedDrop = false
                }
            }
        } else {
            notch = idx
        }
    }

    func endDrag() {
        lastFingerAngle = nil
    }
}

private enum SafeDialRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, angle: Double, notch: Int, open: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius: CGFloat = min(size.width, size.height) * 0.34

        let door = CGRect(x: center.x - radius - 36, y: center.y - radius - 48, width: (radius + 36) * 2, height: (radius + 48) * 2 + 20)
        context.fill(Path(roundedRect: door, cornerRadius: 18), with: .color(Color(white: 0.18)))

        // Bolt
        let boltX = center.x + radius + 10 + (open ? 28 : 0)
        context.fill(
            Path(roundedRect: CGRect(x: boltX, y: center.y - 10, width: 34, height: 20), cornerRadius: 3),
            with: .color(open ? Color(red: 0.55, green: 0.7, blue: 0.4) : Color(white: 0.45))
        )

        var dial = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dial, with: .color(Color(white: 0.12)))
        context.stroke(dial, with: .color(Color(white: 0.55)), lineWidth: 10)

        for i in 0..<SafeDialModel.notches {
            let t = Double(i) / Double(SafeDialModel.notches) * .pi * 2 + angle
            let outer = radius - 8
            let inner = i % 10 == 0 ? radius - 28 : radius - 18
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(t)) * inner, y: center.y + CGFloat(sin(t)) * inner))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(t)) * outer, y: center.y + CGFloat(sin(t)) * outer))
            let color: Color = i == 0 ? Color(red: 0.85, green: 0.2, blue: 0.18) : Color(white: i % 10 == 0 ? 0.85 : 0.55)
            context.stroke(tick, with: .color(color), lineWidth: i % 10 == 0 ? 2.4 : 1.2)
        }

        // Fixed drop marker at 12 o'clock
        var marker = Path()
        marker.move(to: CGPoint(x: center.x, y: center.y - radius - 18))
        marker.addLine(to: CGPoint(x: center.x - 7, y: center.y - radius - 4))
        marker.addLine(to: CGPoint(x: center.x + 7, y: center.y - radius - 4))
        marker.closeSubpath()
        context.fill(marker, with: .color(Color(red: 0.9, green: 0.75, blue: 0.35)))

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)),
            with: .color(Color(white: 0.3))
        )
    }
}

#Preview { SafeDialView() }
