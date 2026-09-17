import SwiftUI

struct HangingChainView: View {
    @StateObject private var simulation = HangingChainSimulation()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHint = true
    @State private var hintToken = UUID()

    var body: some View {
        GeometryReader { geo in
            let nodes = simulation.positions
            let hint = simulation.isUsingDeviceMotion ? "Tilt." : "Drag."

            ZStack {
                HangingChainPalette.background
                    .ignoresSafeArea()

                Canvas { context, size in
                    HangingChainRenderer.draw(in: &context, nodes: nodes, canvasSize: size)
                }
                .animation(nil, value: nodes)
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
                .accessibilityLabel("Hanging metal chain")
                .accessibilityValue(simulation.isUsingDeviceMotion ? "Tilt" : "Drag")
                .accessibilityHint(hint)

                if showHint {
                    Text(hint)
                        .font(.system(.footnote, weight: .regular))
                        .foregroundStyle(HangingChainPalette.caption)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 72)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear {
                simulation.updateViewport(size: geo.size)
                simulation.start()
                scheduleHintFade()
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
            .onChange(of: hint) { _, _ in
                showHint = true
                scheduleHintFade()
            }
            .onDisappear {
                simulation.stop()
            }
        }
        .ignoresSafeArea()
    }

    private func scheduleHintFade() {
        let token = UUID()
        hintToken = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard hintToken == token else { return }
            if reduceMotion {
                showHint = false
            } else {
                withAnimation(.easeOut(duration: 0.7)) {
                    showHint = false
                }
            }
        }
    }
}

private enum HangingChainPalette {
    static let background = Color(red: 0.965, green: 0.961, blue: 0.953)
    static let caption = Color(red: 0.22, green: 0.21, blue: 0.20).opacity(0.38)

    static func metal(_ opacity: Double = 1) -> Color {
        Color(red: 0.18, green: 0.19, blue: 0.21).opacity(opacity)
    }

    static func metalMid(_ opacity: Double = 1) -> Color {
        Color(red: 0.34, green: 0.35, blue: 0.37).opacity(opacity)
    }

    static func metalSoft(_ opacity: Double = 1) -> Color {
        Color(red: 0.46, green: 0.47, blue: 0.49).opacity(opacity)
    }

    static func highlight(_ opacity: Double = 0.34) -> Color {
        Color.white.opacity(opacity)
    }
}

/// Nonisolated draw. Callers snapshot MainActor node positions before entering Canvas.
private enum HangingChainRenderer {
    static func draw(in context: inout GraphicsContext, nodes: [CGPoint], canvasSize: CGSize) {
        guard nodes.count >= 2 else { return }

        drawGroundingShadow(in: &context, nodes: nodes, size: canvasSize)
        drawEdgeLinks(in: &context, nodes: nodes)
        drawFaceLinks(in: &context, nodes: nodes)
        drawPin(in: &context, at: nodes[0])
        drawWeight(in: &context, at: nodes[nodes.count - 1], previous: nodes[nodes.count - 2])
    }

    private static func drawGroundingShadow(in context: inout GraphicsContext, nodes: [CGPoint], size: CGSize) {
        guard let last = nodes.last else { return }
        let y = min(max(last.y, size.height * 0.42), size.height - 22)
        let oval = CGRect(x: last.x - 30, y: y + 14, width: 60, height: 9)
        context.fill(Path(ellipseIn: oval), with: .color(.black.opacity(0.055)))
    }

    private static func drawEdgeLinks(in context: inout GraphicsContext, nodes: [CGPoint]) {
        for index in 0..<(nodes.count - 1) where index % 2 == 1 {
            drawLink(in: &context, from: nodes[index], to: nodes[index + 1], facing: false)
        }
    }

    private static func drawFaceLinks(in context: inout GraphicsContext, nodes: [CGPoint]) {
        for index in 0..<(nodes.count - 1) where index % 2 == 0 {
            drawLink(in: &context, from: nodes[index], to: nodes[index + 1], facing: true)
        }
    }

    private static func drawLink(
        in context: inout GraphicsContext,
        from a: CGPoint,
        to b: CGPoint,
        facing: Bool
    ) {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max(hypot(dx, dy), 1)
        let angle = atan2(dy, dx)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let transform = CGAffineTransform(translationX: mid.x, y: mid.y).rotated(by: angle)

        if facing {
            let linkLength = length + 11
            let linkWidth: CGFloat = 15.5
            let gauge: CGFloat = 3.7
            let outer = CGRect(x: -linkLength / 2, y: -linkWidth / 2, width: linkLength, height: linkWidth)
            let inner = outer.insetBy(dx: gauge, dy: gauge)
            var ring = Path()
            ring.addEllipse(in: outer)
            ring.addEllipse(in: inner)
            ring = ring.applying(transform)
            context.fill(ring, with: .color(HangingChainPalette.metal()), style: FillStyle(eoFill: true))

            var shine = Path()
            shine.addEllipse(in: outer.insetBy(dx: 0.6, dy: 0.6))
            shine = shine.applying(transform)
            context.stroke(
                shine,
                with: .color(HangingChainPalette.highlight()),
                style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
            )
        } else {
            let linkLength = length + 6
            let linkWidth: CGFloat = 7.2
            var body = Path(ellipseIn: CGRect(
                x: -linkLength / 2,
                y: -linkWidth / 2,
                width: linkLength,
                height: linkWidth
            ))
            body = body.applying(transform)
            context.fill(body, with: .color(HangingChainPalette.metalMid()))
            context.stroke(
                body,
                with: .color(HangingChainPalette.metal()),
                style: StrokeStyle(lineWidth: 1.15, lineCap: .round)
            )
            var ridge = Path(ellipseIn: CGRect(
                x: -linkLength / 2 + 2,
                y: -1.1,
                width: linkLength - 4,
                height: 1.8
            ))
            ridge = ridge.applying(transform)
            context.fill(ridge, with: .color(HangingChainPalette.metalSoft(0.7)))
        }
    }

    private static func drawPin(in context: inout GraphicsContext, at point: CGPoint) {
        let stem = CGRect(x: point.x - 5.5, y: point.y - 13, width: 11, height: 16)
        context.fill(Path(roundedRect: stem, cornerRadius: 3.5), with: .color(HangingChainPalette.metal()))
        let head = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        context.fill(head, with: .color(HangingChainPalette.metal()))
        let hole = Path(ellipseIn: CGRect(x: point.x - 2.4, y: point.y - 2.4, width: 4.8, height: 4.8))
        context.fill(hole, with: .color(HangingChainPalette.background))
        let glint = Path(ellipseIn: CGRect(x: point.x - 3.6, y: point.y - 4.2, width: 3.2, height: 2.4))
        context.fill(glint, with: .color(HangingChainPalette.highlight()))
    }

    private static func drawWeight(in context: inout GraphicsContext, at point: CGPoint, previous: CGPoint) {
        let dx = point.x - previous.x
        let dy = point.y - previous.y
        let angle = atan2(dy, dx)
        let transform = CGAffineTransform(translationX: point.x, y: point.y).rotated(by: angle)

        var body = Path(ellipseIn: CGRect(x: -8.5, y: -7.2, width: 17, height: 14.4))
        body = body.applying(transform)
        context.fill(body, with: .color(HangingChainPalette.metal()))

        var rim = Path(ellipseIn: CGRect(x: -8.5, y: -7.2, width: 17, height: 14.4))
        rim = rim.applying(transform)
        context.stroke(rim, with: .color(HangingChainPalette.metalSoft(0.45)), style: StrokeStyle(lineWidth: 0.8))

        var glint = Path(ellipseIn: CGRect(x: -3.6, y: -3.8, width: 5.2, height: 3.8))
        glint = glint.applying(transform)
        context.fill(glint, with: .color(HangingChainPalette.highlight()))
    }
}

#Preview {
    HangingChainView()
}
