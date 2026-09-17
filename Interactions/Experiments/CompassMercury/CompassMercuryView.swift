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
                    CompassMercuryRenderer.draw(in: &context, size: size, heading: heading, hardware: isHardware)
                }
                .accessibilityLabel("Mercury compass")
                .accessibilityValue(statusText)
                .accessibilityHint("Turn the phone so the blob sits on north")

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: statusText)
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
        if model.isHardware {
            model.isTrueNorth ? "The blob holds true north" : "Magnetic north — location unlocks true north"
        } else {
            "Needs a magnetometer. Rotate on a real iPhone."
        }
    }

    private var statusText: String {
        if model.isHardware {
            model.isTrueNorth ? "True north" : "Magnetic north"
        } else {
            "Simulator — blob rests"
        }
    }
}

@MainActor
final class CompassMercuryModel: ObservableObject {
    @Published var heading: Double = 0
    @Published var isHardware = false
    @Published var isTrueNorth = false

    private let source = HeadingSource()
    private let ticker = FrameTicker()
    private var displayed: Double = 0

    func start() {
        source.start()
        ticker.onTick = { [weak self] _ in
            guard let self else { return }
            self.source.pullMotionIfNeeded()
            self.isHardware = self.source.isHardware
            self.isTrueNorth = self.source.isTrueNorth
            var target = self.source.degrees
            while target - self.displayed > 180 { target -= 360 }
            while target - self.displayed < -180 { target += 360 }
            self.displayed += (target - self.displayed) * 0.18
            self.heading = self.displayed
        }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        source.stop()
    }
}

private enum CompassMercuryRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, heading: Double, hardware: Bool) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.52)
        let radius = min(size.width, size.height) * 0.32

        let shadow = Path(ellipseIn: CGRect(x: center.x - radius + 8, y: center.y - radius + 16, width: radius * 2, height: radius * 2))
        context.fill(shadow, with: .color(.black.opacity(0.08)))

        let dish = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dish, with: .color(Color(red: 0.72, green: 0.58, blue: 0.34)))
        context.stroke(dish, with: .color(LabPalette.metal), lineWidth: 7)

        let ring = Path(ellipseIn: CGRect(x: center.x - radius + 7, y: center.y - radius + 7, width: (radius - 7) * 2, height: (radius - 7) * 2))
        context.stroke(ring, with: .color(Color(red: 0.86, green: 0.74, blue: 0.46)), lineWidth: 3)

        let inner = Path(ellipseIn: CGRect(x: center.x - radius + 12, y: center.y - radius + 12, width: (radius - 12) * 2, height: (radius - 12) * 2))
        context.fill(inner, with: .color(Color(red: 0.09, green: 0.10, blue: 0.11)))

        for i in 0..<12 {
            let a = Double(i) / 12 * .pi * 2 - .pi / 2
            let outerR = radius - 18
            let innerR = i % 3 == 0 ? radius - 32 : radius - 26
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(a)) * innerR, y: center.y + CGFloat(sin(a)) * innerR))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * outerR, y: center.y + CGFloat(sin(a)) * outerR))
            context.stroke(tick, with: .color(i == 0 ? LabPalette.rust : Color.white.opacity(0.28)), lineWidth: i % 3 == 0 ? 2 : 1)
        }

        let north = CGPoint(x: center.x, y: center.y - radius + 22)
        context.fill(Path(ellipseIn: CGRect(x: north.x - 3.5, y: north.y - 3.5, width: 7, height: 7)), with: .color(LabPalette.rust))

        let radians = (-heading) * .pi / 180.0
        let rest: CGFloat = hardware ? radius * 0.46 : 0
        let blob = CGPoint(
            x: center.x + CGFloat(sin(radians)) * rest,
            y: center.y - CGFloat(cos(radians)) * rest
        )
        let blobR: CGFloat = 28
        context.fill(
            Path(ellipseIn: CGRect(x: blob.x - blobR, y: blob.y - blobR * 0.82, width: blobR * 2, height: blobR * 1.64)),
            with: .color(Color(red: 0.70, green: 0.73, blue: 0.76))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: blob.x - 11, y: blob.y - 17, width: 15, height: 11)),
            with: .color(.white.opacity(0.48))
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: blob.x - blobR, y: blob.y - blobR * 0.82, width: blobR * 2, height: blobR * 1.64)),
            with: .color(Color.white.opacity(0.18)),
            lineWidth: 1
        )

        if !hardware {
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 22, y: center.y - 16, width: 44, height: 32)),
                with: .color(Color(red: 0.70, green: 0.73, blue: 0.76).opacity(0.88))
            )
        }
    }
}

#Preview { CompassMercuryView() }
