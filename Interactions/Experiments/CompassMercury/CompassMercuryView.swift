import SwiftUI

/// Mercury blob locked to true (or magnetic) north inside a dish.
struct CompassMercuryView: View {
    @StateObject private var model = CompassMercuryModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let heading = model.heading
            let isHardware = model.isHardware
            ZStack {
                LabPalette.paper.ignoresSafeArea()
                Canvas { context, size in
                    CompassMercuryRenderer.draw(in: &context, size: size, heading: heading, hardware: isHardware)
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
        if model.isHardware {
            model.isTrueNorth ? "The blob holds true north — turn the phone" : "Magnetic north — true north needs location"
        } else {
            "Needs a magnetometer. Rotate on a real iPhone."
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
            // Unwrap toward the displayed angle so the blob doesn't jump 359→0.
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

        let dish = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dish, with: .color(Color(red: 0.78, green: 0.76, blue: 0.72)))
        context.stroke(dish, with: .color(LabPalette.metal), lineWidth: 8)
        let inner = Path(ellipseIn: CGRect(x: center.x - radius + 10, y: center.y - radius + 10, width: (radius - 10) * 2, height: (radius - 10) * 2))
        context.fill(inner, with: .color(Color(red: 0.12, green: 0.13, blue: 0.14)))

        // North tick on the dish (device frame: up is heading 0 when phone points north).
        let north = CGPoint(x: center.x, y: center.y - radius + 18)
        context.fill(Path(ellipseIn: CGRect(x: north.x - 3, y: north.y - 3, width: 6, height: 6)), with: .color(LabPalette.rust))

        // Blob sits toward geographic north: opposite of device heading.
        let radians = (-heading) * .pi / 180.0
        let rest: CGFloat = hardware ? radius * 0.46 : 0
        let blob = CGPoint(
            x: center.x + CGFloat(sin(radians)) * rest,
            y: center.y - CGFloat(cos(radians)) * rest
        )
        let blobR: CGFloat = 28
        var mercury = Path(ellipseIn: CGRect(x: blob.x - blobR, y: blob.y - blobR * 0.82, width: blobR * 2, height: blobR * 1.64))
        context.fill(mercury, with: .color(Color(red: 0.72, green: 0.74, blue: 0.76)))
        var glint = Path(ellipseIn: CGRect(x: blob.x - 10, y: blob.y - 16, width: 14, height: 10))
        context.fill(glint, with: .color(.white.opacity(0.45)))

        if !hardware {
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - 22, y: center.y - 16, width: 44, height: 32)),
                with: .color(Color(red: 0.72, green: 0.74, blue: 0.76).opacity(0.85))
            )
        }
    }
}

#Preview { CompassMercuryView() }
