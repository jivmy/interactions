import SwiftUI

struct HangingChainView: View {
    @StateObject private var simulation = HangingChainSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let nodes = simulation.positions
            ZStack {
                LabPalette.paper.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.clear, LabPalette.paperDeep.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
                .accessibilityHint(hintText)

                LabHintOverlay(text: hintText)
            }
            .onAppear {
                simulation.updateViewport(size: geo.size)
                simulation.start()
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
        simulation.isUsingDeviceMotion ? "Tilt." : "Drag."
    }
}

private enum HangingChainPalette {
    static let metal = Color(red: 0.20, green: 0.21, blue: 0.23)
    static let metalSoft = Color(red: 0.40, green: 0.41, blue: 0.43)
    static let highlight = Color.white.opacity(0.28)
    static let hole = Color(red: 0.957, green: 0.949, blue: 0.929)
}

private enum HangingChainRenderer {
    static func draw(in context: inout GraphicsContext, nodes: [CGPoint], canvasSize: CGSize) {
        guard nodes.count >= 2 else { return }

        drawMount(in: &context, at: nodes[0], width: canvasSize.width)
        drawGroundingShadow(in: &context, nodes: nodes, size: canvasSize)
        drawLinks(in: &context, nodes: nodes)
        drawPin(in: &context, at: nodes[0])
        drawPendant(in: &context, at: nodes[nodes.count - 1], previous: nodes[nodes.count - 2])
    }

    private static func drawMount(in context: inout GraphicsContext, at point: CGPoint, width: CGFloat) {
        let plate = CGRect(x: point.x - 42, y: point.y - 18, width: 84, height: 14)
        context.fill(Path(roundedRect: plate, cornerRadius: 3), with: .color(HangingChainPalette.metal))
        context.fill(
            Path(roundedRect: CGRect(x: point.x - 36, y: point.y - 16, width: 28, height: 4), cornerRadius: 1),
            with: .color(HangingChainPalette.highlight)
        )
        let rail = CGRect(x: 24, y: point.y - 22, width: width - 48, height: 4)
        context.fill(Path(roundedRect: rail, cornerRadius: 2), with: .color(HangingChainPalette.metal.opacity(0.55)))
    }

    private static func drawGroundingShadow(in context: inout GraphicsContext, nodes: [CGPoint], size: CGSize) {
        guard let last = nodes.last else { return }
        let y = min(max(last.y, size.height * 0.4), size.height - 24)
        let oval = CGRect(x: last.x - 32, y: y + 12, width: 64, height: 11)
        context.fill(Path(ellipseIn: oval), with: .color(.black.opacity(0.07)))
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
            let linkLength = length + (facing ? 10 : 6)
            let linkWidth: CGFloat = facing ? 16 : 8.5

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
                    style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
                )
                context.stroke(
                    ellipse,
                    with: .color(HangingChainPalette.highlight),
                    style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                )
            } else {
                context.fill(ellipse, with: .color(HangingChainPalette.metalSoft))
                context.stroke(
                    ellipse,
                    with: .color(HangingChainPalette.metal),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
            }
        }
    }

    private static func drawPin(in context: inout GraphicsContext, at point: CGPoint) {
        let bar = CGRect(x: point.x - 16, y: point.y - 5, width: 32, height: 6)
        context.fill(Path(roundedRect: bar, cornerRadius: 3), with: .color(HangingChainPalette.metal))
        let outer = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
        context.fill(outer, with: .color(HangingChainPalette.metal))
        let inner = Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        context.fill(inner, with: .color(HangingChainPalette.hole))
    }

    private static func drawPendant(in context: inout GraphicsContext, at point: CGPoint, previous: CGPoint) {
        let dx = point.x - previous.x
        let dy = point.y - previous.y
        let angle = atan2(dy, dx)
        let radius: CGFloat = 10
        var disc = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        disc = disc.applying(CGAffineTransform(translationX: point.x, y: point.y))
        context.fill(disc, with: .color(HangingChainPalette.metal))
        var glint = Path(ellipseIn: CGRect(x: -3.4, y: -3.8, width: 5.4, height: 4.4))
        glint = glint.applying(CGAffineTransform(translationX: point.x, y: point.y).rotated(by: angle))
        context.fill(glint, with: .color(.white.opacity(0.34)))
    }
}

#Preview {
    HangingChainView()
}
