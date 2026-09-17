import SwiftUI

struct ChladniPlateView: View {
    @StateObject private var model = ChladniModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let grains = model.grains
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.11).ignoresSafeArea()
                Canvas { context, size in
                    ChladniRenderer.draw(in: &context, size: size, grains: grains)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !model.isListening {
                                let t = min(max(value.location.y / max(geo.size.height, 1), 0), 1)
                                model.manualHz = 80 + t * 520
                            }
                        }
                )
                .accessibilityLabel("Chladni plate")
                .accessibilityHint(hint)

                VStack {
                    HStack {
                        Spacer()
                        LabFallbackChip(text: status)
                    }
                    .padding(.top, 58)
                    .padding(.trailing, 16)
                    Spacer()
                }
                .allowsHitTesting(false)

                LabHintOverlay(text: hint)
            }
            .onAppear {
                model.update(size: geo.size)
                model.start()
            }
            .onChange(of: geo.size) { _, size in model.update(size: size) }
            .onChange(of: scenePhase) { _, phase in
                phase == .active ? model.start() : model.stop()
            }
            .onDisappear { model.stop() }
        }
        .ignoresSafeArea()
    }

    private var hint: String {
        if model.denied {
            "Mic denied — drag vertically to change the mode"
        } else if model.isListening {
            "Hum or play a tone — sand finds the nodes"
        } else {
            "Drag to pick a frequency — mic needs a real device"
        }
    }

    private var status: String {
        if model.denied { return "Mic denied" }
        if model.isListening { return "Listening" }
        return "Drag for tone"
    }
}

private struct Grain {
    var p: CGPoint
}

@MainActor
final class ChladniModel: ObservableObject {
    @Published var grains: [CGPoint] = []
    @Published var n = 2
    @Published var m = 3
    @Published var isListening = false
    @Published var denied = false
    var manualHz: Double = 180

    private var particles: [Grain] = []
    private let mic = MicrophoneFFT()
    private let ticker = FrameTicker()
    private var size: CGSize = .zero

    func update(size: CGSize) {
        self.size = size
        if particles.isEmpty {
            let inset = min(size.width, size.height) * 0.12
            particles = (0..<720).map { _ in
                Grain(p: CGPoint(
                    x: inset + CGFloat.random(in: 0...(size.width - inset * 2)),
                    y: inset + CGFloat.random(in: 0...(size.height - inset * 2))
                ))
            }
            grains = particles.map(\.p)
        }
    }

    func start() {
        mic.start()
        ticker.onTick = { [weak self] dt in self?.step(dt: dt) }
        ticker.start()
    }

    func stop() {
        ticker.stop()
        mic.stop()
    }

    private func step(dt: CGFloat) {
        mic.publish()
        isListening = mic.isListening
        denied = mic.denied
        let hz = mic.isListening && mic.amplitude > 0.002 ? mic.dominantHz : manualHz
        let mode = max(1, Int(hz / 70))
        n = 1 + mode % 5
        m = 1 + (mode / 2) % 5
        let amp = mic.isListening ? min(mic.amplitude * 18, 1.4) : 0.8
        let inset: CGFloat = 40
        let w = max(size.width - inset * 2, 1)
        let h = max(size.height - inset * 2, 1)
        let nn = CGFloat(n)
        let mm = CGFloat(m)
        for i in particles.indices {
            var p = particles[i].p
            let nx = (p.x - inset) / w
            let ny = (p.y - inset) / h
            let psi = cos(nn * .pi * nx) * cos(mm * .pi * ny)
            let gx = -sin(nn * .pi * nx) * nn * .pi / w * cos(mm * .pi * ny)
            let gy = -cos(nn * .pi * nx) * sin(mm * .pi * ny) * mm * .pi / h
            let kick = CGFloat(psi * psi) * 420 * CGFloat(amp) * dt
            p.x += gx * kick + CGFloat.random(in: -0.4...0.4)
            p.y += gy * kick + CGFloat.random(in: -0.4...0.4)
            p.x = min(max(p.x, inset), size.width - inset)
            p.y = min(max(p.y, inset), size.height - inset)
            particles[i].p = p
        }
        grains = particles.map(\.p)
    }
}

private enum ChladniRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, grains: [CGPoint]) {
        let plate = CGRect(x: 22, y: 92, width: size.width - 44, height: size.height - 156)
        context.fill(Path(roundedRect: plate, cornerRadius: 10), with: .color(Color(red: 0.20, green: 0.18, blue: 0.14)))
        context.stroke(Path(roundedRect: plate, cornerRadius: 10), with: .color(LabPalette.brass.opacity(0.7)), lineWidth: 7)
        context.stroke(Path(roundedRect: plate.insetBy(dx: 5, dy: 5), cornerRadius: 7), with: .color(Color.white.opacity(0.06)), lineWidth: 1)

        var sand = Path()
        for g in grains {
            sand.addEllipse(in: CGRect(x: g.x - 1.15, y: g.y - 1.15, width: 2.3, height: 2.3))
        }
        context.fill(sand, with: .color(Color(red: 0.84, green: 0.76, blue: 0.52)))
    }
}

#Preview { ChladniPlateView() }
