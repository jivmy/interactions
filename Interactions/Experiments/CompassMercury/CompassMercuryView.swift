import SwiftUI

/// Mercury blob locked to true (or magnetic) north inside a dish.
struct CompassMercuryView: View {
    @StateObject private var model = CompassMercuryModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { _ in
            let heading = model.heading
            let isHardware = model.isHardware
            ZStack {
                LabPaperBackground()
                Canvas { context, size in
                    CompassMercuryRenderer.draw(in: &context, size: size, heading: heading, hardware: isHardware, aligned: model.aligned)
                }
                .accessibilityLabel("Mercury compass")
                .accessibilityValue(statusText)
                .accessibilityHint("Turn the phone so the blob sits on north")

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
        if model.isHardware {
            model.isTrueNorth ? "Turn." : "Magnetic."
        } else {
            "Phone."
        }
    }

    private var statusText: String {
        if model.isHardware {
            model.isTrueNorth ? "True north" : "Magnetic north"
        } else {
            "Simulator"
        }
    }
}

@MainActor
final class CompassMercuryModel: ObservableObject {
    @Published var heading: Double = 0
    @Published var isHardware = false
    @Published var isTrueNorth = false
    @Published var aligned = false

    private let source = HeadingSource()
    private let ticker = FrameTicker()
    private let haptics = HapticPlayer()
    private var displayed: Double = 0
    private var wasAligned = false

    func start() {
        haptics.startEngine()
        source.start()
        ticker.onTick = { [weak self] _ in
            guard let self else { return }
            self.source.pullMotionIfNeeded()
            let hardware = self.source.isHardware
            let trueNorth = self.source.isTrueNorth
            var target = self.source.degrees
            while target - self.displayed > 180 { target -= 360 }
            while target - self.displayed < -180 { target += 360 }
            self.displayed += (target - self.displayed) * 0.16
            var wrapped = self.displayed.truncatingRemainder(dividingBy: 360)
            if wrapped < 0 { wrapped += 360 }
            let offset = min(wrapped, 360 - wrapped)
            let nowAligned = hardware && offset < 6
            if nowAligned && !self.wasAligned {
                self.haptics.tick()
            }
            self.wasAligned = nowAligned
            if abs(self.heading - self.displayed) > 0.08
                || hardware != self.isHardware
                || trueNorth != self.isTrueNorth
                || nowAligned != self.aligned {
                self.isHardware = hardware
                self.isTrueNorth = trueNorth
                self.aligned = nowAligned
                self.heading = self.displayed
            }
        }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        source.stop()
        haptics.shutdown()
    }
}

private enum CompassMercuryRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, heading: Double, hardware: Bool, aligned: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius = min(size.width, size.height) * 0.33

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius + 10, y: center.y - radius + 18, width: radius * 2, height: radius * 2)),
            with: .color(.black.opacity(0.10))
        )

        let dish = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dish, with: .color(Color(red: 0.70, green: 0.56, blue: 0.32)))
        context.stroke(dish, with: .color(Color(red: 0.42, green: 0.32, blue: 0.16)), lineWidth: 8)

        let ring = Path(ellipseIn: CGRect(x: center.x - radius + 8, y: center.y - radius + 8, width: (radius - 8) * 2, height: (radius - 8) * 2))
        context.stroke(ring, with: .color(Color(red: 0.88, green: 0.76, blue: 0.48)), lineWidth: 2.4)

        let inner = Path(ellipseIn: CGRect(x: center.x - radius + 14, y: center.y - radius + 14, width: (radius - 14) * 2, height: (radius - 14) * 2))
        context.fill(inner, with: .color(Color(red: 0.07, green: 0.08, blue: 0.09)))
        let well = Path(ellipseIn: CGRect(x: center.x - radius + 22, y: center.y - radius + 24, width: (radius - 22) * 2, height: (radius - 20) * 2))
        context.fill(well, with: .color(Color(red: 0.045, green: 0.05, blue: 0.055)))

        let screws: [CGFloat] = [0.28, 0.72, 1.28, 1.72]
        for a in screws {
            let sx = center.x + LabMath.cos(a * .pi) * (radius - 4)
            let sy = center.y + LabMath.sin(a * .pi) * (radius - 4)
            context.fill(Path(ellipseIn: CGRect(x: sx - 2.4, y: sy - 2.4, width: 4.8, height: 4.8)), with: .color(Color(red: 0.42, green: 0.32, blue: 0.16)))
            context.fill(Path(ellipseIn: CGRect(x: sx - 0.8, y: sy - 0.8, width: 1.6, height: 1.6)), with: .color(Color(red: 0.22, green: 0.16, blue: 0.08)))
        }

        for i in 0..<60 {
            let a = Double(i) / 60 * .pi * 2 - .pi / 2
            let major = i % 5 == 0
            let outerR = radius - 20
            let innerR = major ? radius - 34 : radius - 26
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(a)) * innerR, y: center.y + CGFloat(sin(a)) * innerR))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * outerR, y: center.y + CGFloat(sin(a)) * outerR))
            context.stroke(tick, with: .color(i == 0 ? LabPalette.rust : Color.white.opacity(major ? 0.32 : 0.12)), lineWidth: major ? 1.6 : 0.7)
        }

        let nPoint = CGPoint(x: center.x, y: center.y - radius + 48)
        if aligned {
            context.fill(
                Path(ellipseIn: CGRect(x: nPoint.x - 14, y: nPoint.y - 12, width: 28, height: 24)),
                with: .color(LabPalette.rust.opacity(0.22))
            )
        }
        context.draw(
            Text("N")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(aligned ? LabPalette.rust : LabPalette.rust.opacity(0.86)),
            at: nPoint
        )

        let radians = (-heading) * .pi / 180.0
        let rest: CGFloat = hardware ? radius * 0.44 : 0
        let blob = CGPoint(
            x: center.x + CGFloat(sin(radians)) * rest,
            y: center.y - CGFloat(cos(radians)) * rest
        )
        let along = CGVector(dx: blob.x - center.x, dy: blob.y - center.y)
        let len = max(hypot(along.dx, along.dy), 1)
        let nx = along.dx / len
        let ny = along.dy / len
        let blobR: CGFloat = 26
        let stretch: CGFloat = hardware ? 1.12 : 1
        var mercury = Path(ellipseIn: CGRect(x: -blobR * stretch, y: -blobR * 0.78, width: blobR * 2 * stretch, height: blobR * 1.56))
        let angle = atan2(ny, nx)
        mercury = mercury.applying(CGAffineTransform(translationX: blob.x, y: blob.y).rotated(by: angle))
        context.fill(
            Path(ellipseIn: CGRect(x: blob.x - blobR * 0.7, y: blob.y + blobR * 0.35, width: blobR * 1.5, height: blobR * 0.55)),
            with: .color(.black.opacity(0.18))
        )
        context.fill(mercury, with: .color(Color(red: 0.68, green: 0.71, blue: 0.74)))
        context.fill(
            Path(ellipseIn: CGRect(x: blob.x - 11, y: blob.y - 17, width: 14, height: 9)),
            with: .color(.white.opacity(0.52))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: blob.x + 4, y: blob.y - 4, width: 7, height: 5)),
            with: .color(.white.opacity(0.16))
        )
        context.stroke(mercury, with: .color(Color.white.opacity(0.18)), lineWidth: 1)

        var glass = Path()
        glass.addArc(
            center: center,
            radius: radius - 18,
            startAngle: .degrees(220),
            endAngle: .degrees(300),
            clockwise: false
        )
        context.stroke(glass, with: .color(.white.opacity(0.14)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        if !hardware {
            var puddle = Path(ellipseIn: CGRect(x: center.x - 22, y: center.y - 12, width: 44, height: 26))
            context.fill(puddle, with: .color(Color(red: 0.68, green: 0.71, blue: 0.74).opacity(0.92)))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 14, width: 12, height: 7)),
                with: .color(.white.opacity(0.28))
            )
        }
    }
}

#Preview { CompassMercuryView() }
