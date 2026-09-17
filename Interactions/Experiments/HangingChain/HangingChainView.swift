import SwiftUI

struct HangingChainView: View {
    @StateObject private var simulation = HangingChainSimulation()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHint = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HangingChainPalette.background
                    .ignoresSafeArea()

                Canvas { context, size in
                    HangingChainRenderer.draw(in: &context, nodes: simulation.positions, canvasSize: size)
                }
                .animation(nil, value: simulation.positions)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if simulation.isDragging {
                                simulation.moveDrag(to: value.location)
                            } else {
                                simulation.beginDrag(at: value.startLocation)
                            }
                        }
                        .onEnded { _ in
                            simulation.endDrag()
                        }
                )

                VStack(spacing: 0) {
                    HStack {
                        Text("\(ExperimentCatalog.hangingChain.code)  ·  \(ExperimentCatalog.hangingChain.title)")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(HangingChainPalette.caption)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, ViewSpaceMotion.windowSafeAreaTop() + 6)
                    Spacer()
                    if showHint {
                        Text(hintText)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(HangingChainPalette.caption)
                            .padding(.bottom, max(geo.safeAreaInsets.bottom, 28))
                            .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                simulation.updateViewport(size: geo.size)
                simulation.start()
                fadeHint()
            }
            .onChange(of: geo.size) { _, newSize in
                simulation.updateViewport(size: newSize)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    simulation.start()
                default:
                    simulation.stop()
                }
            }
            .onDisappear {
                simulation.stop()
            }
        }
        .ignoresSafeArea()
    }

    private var hintText: String {
        if simulation.isUsingDeviceMotion {
            "Tilt or swing the phone"
        } else {
            "Drag a link — tilt needs a real iPhone"
        }
    }

    private func fadeHint() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.5))
            withAnimation(.easeOut(duration: 0.8)) {
                showHint = false
            }
        }
    }
}

private enum HangingChainPalette {
    static let background = Color(red: 0.925, green: 0.914, blue: 0.890)
    static let caption = Color(red: 0.28, green: 0.27, blue: 0.25).opacity(0.55)
    static let metal = Color(red: 0.22, green: 0.23, blue: 0.25)
    static let metalSoft = Color(red: 0.38, green: 0.38, blue: 0.40)
    static let hole = Color(red: 0.925, green: 0.914, blue: 0.890)
}

private enum HangingChainRenderer {
    static func draw(in context: inout GraphicsContext, nodes: [CGPoint], canvasSize: CGSize) {
        guard nodes.count >= 2 else { return }

        drawGroundingShadow(in: &context, nodes: nodes, size: canvasSize)
        drawLinks(in: &context, nodes: nodes)
        drawPin(in: &context, at: nodes[0])
        drawPendant(in: &context, at: nodes[nodes.count - 1], previous: nodes[nodes.count - 2])
    }

    private static func drawGroundingShadow(in context: inout GraphicsContext, nodes: [CGPoint], size: CGSize) {
        guard let last = nodes.last else { return }
        let y = min(max(last.y, size.height * 0.4), size.height - 24)
        let oval = CGRect(x: last.x - 28, y: y + 10, width: 56, height: 10)
        context.fill(
            Path(ellipseIn: oval),
            with: .color(.black.opacity(0.06))
        )
    }

    private static func drawLinks(in context: inout GraphicsContext, nodes: [CGPoint]) {
        for index in 0..<(nodes.count - 1) {
            let a = nodes[index]
            let b = nodes[index + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let length = max(hypot(dx, dy), 1)
            let angle = atan2(dy, dx)
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let facing = index % 2 == 0
            let linkLength = length + (facing ? 9 : 6)
            let linkWidth: CGFloat = facing ? 15 : 8

            var ellipse = Path(ellipseIn: CGRect(
                x: -linkLength / 2,
                y: -linkWidth / 2,
                width: linkLength,
                height: linkWidth
            ))
            ellipse = ellipse.applying(
                CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle)
            )

            if facing {
                context.stroke(
                    ellipse,
                    with: .color(HangingChainPalette.metal),
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round)
                )
            } else {
                context.fill(ellipse, with: .color(HangingChainPalette.metalSoft))
                context.stroke(
                    ellipse,
                    with: .color(HangingChainPalette.metal),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
            }
        }
    }

    private static func drawPin(in context: inout GraphicsContext, at point: CGPoint) {
        let bar = CGRect(x: point.x - 16, y: point.y - 5, width: 32, height: 6)
        context.fill(
            Path(roundedRect: bar, cornerRadius: 3),
            with: .color(HangingChainPalette.metal)
        )
        let outer = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        context.fill(outer, with: .color(HangingChainPalette.metal))
        let inner = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        context.fill(inner, with: .color(HangingChainPalette.hole))
    }

    private static func drawPendant(in context: inout GraphicsContext, at point: CGPoint, previous: CGPoint) {
        let dx = point.x - previous.x
        let dy = point.y - previous.y
        let angle = atan2(dy, dx)
        let radius: CGFloat = 9
        var disc = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        disc = disc.applying(CGAffineTransform(translationX: point.x, y: point.y))
        context.fill(disc, with: .color(HangingChainPalette.metal))
        var glint = Path(ellipseIn: CGRect(x: -3.2, y: -3.6, width: 5, height: 4.2))
        glint = glint.applying(
            CGAffineTransform(translationX: point.x, y: point.y).rotated(by: angle)
        )
        context.fill(glint, with: .color(.white.opacity(0.28)))
    }
}

#Preview {
    HangingChainView()
}
