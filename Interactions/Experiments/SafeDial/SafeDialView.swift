import SwiftUI

/// Combination dial with a haptic click per notch and a heavy clunk on the drop.
struct SafeDialView: View {
    @StateObject private var model = SafeDialModel()

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.52)
            let angle = model.angle
            let notch = model.notch
            let isOpen = model.isOpen
            let notches = SafeDialModel.notches
            ZStack {
                LabPalette.studio.ignoresSafeArea()
                RadialGradient(
                    colors: [Color.white.opacity(0.05), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 280
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                Canvas { context, size in
                    SafeDialRenderer.draw(in: &context, size: size, angle: angle, notch: notch, open: isOpen, notches: notches)
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
                .accessibilityLabel(isOpen ? "Safe dial, open" : "Safe dial, closed")
                .accessibilityHint("Turn the dial. Last notch clunks open.")
                .accessibilityValue("Notch \(notch)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.nudge(notches: 1)
                    case .decrement: model.nudge(notches: -1)
                    default: break
                    }
                }

                LabHintOverlay(text: isOpen ? "Open." : "Turn.")
            }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class SafeDialModel: ObservableObject {
    nonisolated static let notches = 40
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
                haptics.detent(isDrop: true)
                isOpen = true
                passedDrop = true
            } else {
                haptics.detent(isDecade: idx % 10 == 0)
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

    func nudge(notches delta: Int) {
        let n = SafeDialModel.notches
        let next = (notch + delta % n + n) % n
        guard next != notch else { return }
        let tau = Double.pi * 2
        angle = -Double(next) / Double(n) * tau
        lastNotch = next
        notch = next
        if next == dropNotch {
            haptics.detent(isDrop: true)
            isOpen = true
            passedDrop = true
        } else {
            haptics.detent(isDecade: next % 10 == 0)
            if passedDrop && abs(next - dropNotch) > 2 {
                isOpen = false
                passedDrop = false
            }
        }
    }
}

private enum SafeDialRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, angle: Double, notch: Int, open: Bool, notches: Int) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius: CGFloat = min(size.width, size.height) * 0.34

        let door = CGRect(x: center.x - radius - 40, y: center.y - radius - 52, width: (radius + 40) * 2, height: (radius + 52) * 2 + 24)
        context.fill(
            Path(roundedRect: door.offsetBy(dx: 0, dy: 10), cornerRadius: 22),
            with: .color(LabShadow.ground())
        )
        context.fill(Path(roundedRect: door, cornerRadius: 22), with: .color(Color(white: 0.16)))
        context.fill(
            Path(roundedRect: CGRect(x: door.minX + 18, y: door.minY + 12, width: door.width * 0.34, height: 16), cornerRadius: 6),
            with: .color(.white.opacity(0.04))
        )
        context.stroke(Path(roundedRect: door, cornerRadius: 22), with: .color(Color.white.opacity(0.06)), lineWidth: 1)

        let lamp = CGRect(x: center.x - 7, y: door.minY + 16, width: 14, height: 14)
        context.fill(Path(ellipseIn: lamp), with: .color(open ? Color(red: 0.55, green: 0.82, blue: 0.40) : Color(white: 0.28)))
        if open {
            context.fill(Path(ellipseIn: lamp.insetBy(dx: -6, dy: -6)), with: .color(Color(red: 0.55, green: 0.82, blue: 0.40).opacity(0.22)))
        }

        let boltX = center.x + radius + 12 + (open ? 30 : 0)
        context.fill(
            Path(roundedRect: CGRect(x: boltX, y: center.y - 11, width: 36, height: 22), cornerRadius: 4),
            with: .color(open ? Color(red: 0.55, green: 0.72, blue: 0.40) : Color(white: 0.48))
        )

        var dial = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius + 8, y: center.y - radius + 14, width: radius * 2, height: radius * 2)),
            with: .color(.black.opacity(0.28))
        )
        context.fill(dial, with: .color(Color(white: 0.11)))
        context.stroke(dial, with: .color(Color(white: 0.58)), lineWidth: 11)
        var rim = Path()
        rim.addArc(center: center, radius: radius - 4, startAngle: .degrees(210), endAngle: .degrees(260), clockwise: false)
        context.stroke(rim, with: .color(.white.opacity(0.10)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - radius + 10, y: center.y - radius + 10, width: (radius - 10) * 2, height: (radius - 10) * 2)),
            with: .color(Color.white.opacity(0.06)),
            lineWidth: 1
        )

        for i in 0..<notches {
            let t = Double(i) / Double(notches) * .pi * 2 + angle
            let outer = radius - 10
            let inner = i % 10 == 0 ? radius - 30 : radius - 20
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(t)) * inner, y: center.y + CGFloat(sin(t)) * inner))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(t)) * outer, y: center.y + CGFloat(sin(t)) * outer))
            let color: Color = i == 0 ? Color(red: 0.86, green: 0.22, blue: 0.18) : Color(white: i % 10 == 0 ? 0.88 : 0.52)
            context.stroke(tick, with: .color(color), lineWidth: i % 10 == 0 ? 2.5 : 1.15)
        }

        var marker = Path()
        marker.move(to: CGPoint(x: center.x, y: center.y - radius - 20))
        marker.addLine(to: CGPoint(x: center.x - 7, y: center.y - radius - 5))
        marker.addLine(to: CGPoint(x: center.x + 7, y: center.y - radius - 5))
        marker.closeSubpath()
        context.fill(marker, with: .color(LabPalette.brass))

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)),
            with: .color(Color(white: 0.28))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 6, width: 6, height: 5)),
            with: .color(.white.opacity(0.18))
        )
    }
}

#Preview { SafeDialView() }
