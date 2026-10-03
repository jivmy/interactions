import SwiftUI

struct FireballsView: View {
    @StateObject private var simulation = FireballsSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let frame = simulation.frame
        let firepower = simulation.firepower

        ZStack {
            Canvas { context, size in
                FireballsRenderer.draw(in: &context, size: size, frame: frame, firepower: firepower)
            }
            .animation(nil, value: frame.time)
            .animation(nil, value: firepower)
            .accessibilityLabel("Fire")
            .accessibilityValue(firepowerLabel(firepower))

            VStack {
                Spacer()
                Slider(value: $simulation.firepower, in: 0...1)
                    .tint(Color(red: 0.20, green: 0.14, blue: 0.10).opacity(0.55))
                    .padding(.horizontal, 62)
                    .padding(.bottom, 54)
                    .accessibilityLabel("Firepower")
            }
        }
        .onAppear { simulation.start() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                simulation.start()
            default:
                simulation.stop()
            }
        }
        .onDisappear { simulation.stop() }
        .ignoresSafeArea()
    }

    private func firepowerLabel(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded())) percent"
    }
}

private enum FireballKind: Int, CaseIterable, Sendable {
    case candle
    case pixel
    case embers
    case plasma
    case ribbons
    case jet
    case molten
    case vortex
}

private struct FireCell: Sendable {
    var kind: FireballKind
    var hearth: CGPoint
    var width: CGFloat
    var height: CGFloat
}

/// Nonisolated draw. Callers snapshot MainActor frame + firepower before entering Canvas.
private enum FireballsRenderer {
    static func draw(in context: inout GraphicsContext, size: CGSize, frame: FireballsFrame, firepower: CGFloat) {
        let power = max(0, min(1, firepower))
        let roar = power * power
        for cell in cells(in: size) {
            stain(in: &context, cell: cell, power: power)
            switch cell.kind {
            case .candle:
                drawCandle(in: &context, cell: cell, time: frame.time, power: power, roar: roar)
            case .pixel:
                drawPixel(in: &context, cell: cell, frame: frame, power: power)
            case .embers:
                drawEmbers(in: &context, cell: cell, frame: frame, power: power)
            case .plasma:
                drawPlasma(in: &context, cell: cell, time: frame.time, power: power, roar: roar)
            case .ribbons:
                drawRibbons(in: &context, cell: cell, time: frame.time, power: power)
            case .jet:
                drawJet(in: &context, cell: cell, time: frame.time, power: power, roar: roar)
            case .molten:
                drawMolten(in: &context, cell: cell, frame: frame, power: power, roar: roar)
            case .vortex:
                drawVortex(in: &context, cell: cell, frame: frame, power: power)
            }
        }
    }

    static func cells(in size: CGSize) -> [FireCell] {
        let cols = 2
        let rows = 4
        let top = size.height * 0.075
        let bottom = max(118, size.height * 0.145)
        let usableH = max(size.height - top - bottom, 240)
        let cellW = size.width / CGFloat(cols)
        let cellH = usableH / CGFloat(rows)
        return FireballKind.allCases.enumerated().map { index, kind in
            let col = index % cols
            let row = index / cols
            let hearth = CGPoint(
                x: cellW * (CGFloat(col) + 0.5),
                y: top + cellH * (CGFloat(row) + 0.84)
            )
            return FireCell(
                kind: kind,
                hearth: hearth,
                width: cellW * 0.78,
                height: cellH * 0.74
            )
        }
    }

    private static func stain(in context: inout GraphicsContext, cell: FireCell, power: CGFloat) {
        let radius = mix(cell.width * 0.18, cell.width * 0.48, power)
        let rect = CGRect(
            x: cell.hearth.x - radius,
            y: cell.hearth.y - radius * 1.15,
            width: radius * 2,
            height: radius * 2.05
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    stainColor(for: cell.kind).opacity(mix(0.05, 0.22, power)),
                    stainColor(for: cell.kind).opacity(0)
                ]),
                center: cell.hearth,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private static func stainColor(for kind: FireballKind) -> Color {
        switch kind {
        case .candle: return rgb(1.00, 0.45, 0.08)
        case .pixel: return rgb(0.90, 0.18, 0.04)
        case .embers: return rgb(0.95, 0.42, 0.10)
        case .plasma: return rgb(0.45, 0.20, 0.95)
        case .ribbons: return rgb(0.92, 0.22, 0.12)
        case .jet: return rgb(0.18, 0.42, 1.00)
        case .molten: return rgb(0.85, 0.16, 0.04)
        case .vortex: return rgb(1.00, 0.50, 0.08)
        }
    }

    // MARK: - Candle: layered organic teardrop

    private static func drawCandle(
        in context: inout GraphicsContext,
        cell: FireCell,
        time: CGFloat,
        power: CGFloat,
        roar: CGFloat
    ) {
        let flicker = 0.80 + 0.20 * sin(time * 11.2) * sin(time * 6.7 + 0.4)
        let lean = sin(time * 2.35) * mix(0.02, 0.16, power)
        let height = mix(16, cell.height * 0.92, power) * flicker
        let width = mix(9, cell.width * 0.42, power)

        var local = context
        local.translateBy(x: cell.hearth.x, y: cell.hearth.y)
        local.rotate(by: .radians(lean))

        fillFlame(in: &local, width: width * 1.55, height: height * 1.12, color: rgb(0.95, 0.22, 0.04).opacity(mix(0.16, 0.42, power)))
        fillFlame(in: &local, width: width * 1.12, height: height, color: rgb(1.00, 0.42, 0.06).opacity(0.92))
        fillFlame(in: &local, width: width * 0.70, height: height * 0.78, color: rgb(1.00, 0.78, 0.16).opacity(0.95))
        fillFlame(in: &local, width: width * 0.34, height: height * 0.42, color: rgb(1.00, 0.97, 0.82).opacity(0.96))

        let coreH = mix(4, 14 + roar * 10, power)
        let core = CGRect(x: -width * 0.10, y: -coreH * 0.55, width: width * 0.20, height: coreH)
        local.fill(Path(ellipseIn: core), with: .color(rgb(0.65, 0.82, 1.00).opacity(mix(0.15, 0.75, power))))

        let coalW = mix(5, 13, power)
        local.fill(
            Path(ellipseIn: CGRect(x: -coalW * 0.5, y: -2.2, width: coalW, height: 5)),
            with: .color(rgb(0.28, 0.08, 0.04).opacity(0.85))
        )
    }

    // MARK: - Pixel: Doom-style heat grid, circular fireball

    private static func drawPixel(
        in context: inout GraphicsContext,
        cell: FireCell,
        frame: FireballsFrame,
        power: CGFloat
    ) {
        let width = frame.pixelWidth
        let height = frame.pixelHeight
        guard width > 0, height > 0, frame.pixels.count >= width * height else { return }

        let fieldW = mix(cell.width * 0.28, cell.width * 0.72, power)
        let fieldH = mix(cell.height * 0.28, cell.height * 0.95, power)
        let origin = CGPoint(x: cell.hearth.x - fieldW / 2, y: cell.hearth.y - fieldH + 4)
        let cellW = fieldW / CGFloat(width)
        let cellH = fieldH / CGFloat(height)
        let clip = CGRect(x: origin.x, y: origin.y, width: fieldW, height: fieldH)

        var local = context
        local.clip(to: Path(ellipseIn: clip.insetBy(dx: -cellW * 0.2, dy: -cellH * 0.1)))

        let gap: CGFloat = 0.55
        let heatMul = mix(0.22, 1.0, power)
        for y in 0..<height {
            for x in 0..<width {
                let raw = frame.pixels[y * width + x]
                let heat = min(1, CGFloat(raw) / 255 * heatMul)
                guard heat > 0.04 else { continue }
                let rect = CGRect(
                    x: origin.x + CGFloat(x) * cellW + gap,
                    y: origin.y + CGFloat(y) * cellH + gap,
                    width: max(0.6, cellW - gap * 2),
                    height: max(0.6, cellH - gap * 2)
                )
                local.fill(Path(roundedRect: rect, cornerRadius: 0.7), with: .color(pixelColor(heat)))
            }
        }
    }

    private static func pixelColor(_ heat: CGFloat) -> Color {
        if heat < 0.28 {
            let t = heat / 0.28
            return rgb(0.35 * t, 0.02, 0.01).opacity(0.35 + 0.55 * t)
        }
        if heat < 0.58 {
            let t = (heat - 0.28) / 0.30
            return rgb(0.75 + 0.25 * t, 0.08 + 0.28 * t, 0.02).opacity(0.95)
        }
        if heat < 0.84 {
            let t = (heat - 0.58) / 0.26
            return rgb(1.0, 0.42 + 0.45 * t, 0.05 + 0.20 * t)
        }
        let t = (heat - 0.84) / 0.16
        return rgb(1.0, 0.92 + 0.08 * t, 0.55 + 0.40 * t)
    }

    // MARK: - Embers: rising spark fountain

    private static func drawEmbers(
        in context: inout GraphicsContext,
        cell: FireCell,
        frame: FireballsFrame,
        power: CGFloat
    ) {
        let bedW = mix(10, cell.width * 0.46, power)
        context.fill(
            Path(ellipseIn: CGRect(x: cell.hearth.x - bedW / 2, y: cell.hearth.y - 3, width: bedW, height: 7)),
            with: .color(rgb(0.55, 0.12, 0.04).opacity(mix(0.25, 0.8, power)))
        )
        for i in 0..<Int(mix(2, 7, power)) {
            let ox = CGFloat(i) / max(mix(2, 7, power) - 1, 1) - 0.5
            let r = mix(2.2, 5.4, power)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: cell.hearth.x + ox * bedW * 0.7 - r / 2,
                    y: cell.hearth.y - r * 0.4,
                    width: r,
                    height: r * 0.72
                )),
                with: .color(rgb(1.0, mix(0.35, 0.7, CGFloat(i) / 7), 0.08).opacity(0.9))
            )
        }

        let rise = mix(cell.height * 0.22, cell.height * 1.05, power)
        let spread = cell.width * 0.5
        for ember in frame.embers {
            let alpha = max(0, ember.life)
            let x = cell.hearth.x + ember.x * spread
            let y = cell.hearth.y - ember.y * rise
            let w = ember.size * mix(0.55, 1.35, power)
            let h = w * mix(1.4, 2.8, power)
            let color = rgb(1.0, 0.35 + ember.warmth * 0.55, 0.06 + ember.warmth * 0.18)
            context.fill(
                Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)),
                with: .color(color.opacity(0.22 + 0.78 * alpha))
            )
        }
    }

    // MARK: - Plasma: sphere + electric filaments

    private static func drawPlasma(
        in context: inout GraphicsContext,
        cell: FireCell,
        time: CGFloat,
        power: CGFloat,
        roar: CGFloat
    ) {
        let radius = mix(12, cell.width * 0.36, power)
        let center = CGPoint(x: cell.hearth.x, y: cell.hearth.y - radius * 0.72)
        let pulse = 0.88 + 0.12 * sin(time * 7.4)

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 1.25, y: center.y - radius * 1.25, width: radius * 2.5, height: radius * 2.5)),
            with: .radialGradient(
                Gradient(colors: [
                    rgb(0.55, 0.20, 1.00).opacity(mix(0.10, 0.38, power)),
                    rgb(0.20, 0.55, 1.00).opacity(0)
                ]),
                center: center,
                startRadius: radius * 0.2,
                endRadius: radius * 1.35
            )
        )

        let tendrils = 4 + Int(power * 8)
        for i in 0..<tendrils {
            var path = Path()
            let base = (CGFloat(i) / CGFloat(tendrils)) * .pi * 2 + time * mix(0.6, 2.4, power)
            let steps = 18
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let wave = sin(t * 9 + time * 9 + CGFloat(i) * 0.7) * mix(0.08, 0.42, power) * t
                let angle = base + wave
                let r = radius * pulse * t
                let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
                if s == 0 { path.move(to: center) } else { path.addLine(to: point) }
            }
            let hue = i.isMultiple(of: 2)
            let color = hue ? rgb(0.45, 0.85, 1.00) : rgb(0.82, 0.35, 1.00)
            context.stroke(
                path,
                with: .color(color.opacity(mix(0.25, 0.88, power))),
                style: StrokeStyle(lineWidth: mix(0.7, 2.4, power), lineCap: .round)
            )
        }

        let coreR = radius * mix(0.22, 0.42 + roar * 0.12, power) * pulse
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(
                Gradient(colors: [rgb(0.95, 0.98, 1.00), rgb(0.35, 0.75, 1.00).opacity(0.85), rgb(0.55, 0.15, 0.95).opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: coreR
            )
        )
    }

    // MARK: - Ribbons: calligraphy silk tongues

    private static func drawRibbons(
        in context: inout GraphicsContext,
        cell: FireCell,
        time: CGFloat,
        power: CGFloat
    ) {
        let count = 3 + Int(power * 4)
        let length = mix(cell.height * 0.22, cell.height * 0.98, power)
        for i in 0..<count {
            var path = Path()
            let phase = CGFloat(i) * 1.17
            let freq = 1.6 + CGFloat(i) * 0.45
            let steps = 30
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let y = cell.hearth.y - t * length
                let envelope = sin(t * .pi)
                let x = cell.hearth.x
                    + sin(t * freq * .pi + time * mix(2.2, 6.8, power) + phase) * cell.width * mix(0.06, 0.28, power) * envelope
                    + CGFloat(i - count / 2) * mix(2, 7, power)
                let point = CGPoint(x: x, y: y)
                if s == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            let colors = [
                rgb(0.78, 0.08, 0.10),
                rgb(1.00, 0.32, 0.06),
                rgb(1.00, 0.62, 0.12),
                rgb(1.00, 0.85, 0.28),
                rgb(0.62, 0.04, 0.12)
            ]
            let color = colors[i % colors.count]
            context.stroke(
                path,
                with: .color(color.opacity(mix(0.35, 0.95, power))),
                style: StrokeStyle(
                    lineWidth: mix(1.6, 7.2, power) * (1 - CGFloat(i) * 0.09),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    // MARK: - Jet: blue gas torch

    private static func drawJet(
        in context: inout GraphicsContext,
        cell: FireCell,
        time: CGFloat,
        power: CGFloat,
        roar: CGFloat
    ) {
        let shimmer = 0.90 + 0.10 * sin(time * 28) * power
        let height = mix(18, cell.height * 0.98, power) * shimmer
        let width = mix(6, cell.width * 0.18 + roar * cell.width * 0.06, power)

        var local = context
        local.translateBy(x: cell.hearth.x, y: cell.hearth.y)

        fillFlame(in: &local, width: width * 1.65, height: height, color: rgb(0.15, 0.38, 1.00).opacity(mix(0.28, 0.72, power)))
        fillFlame(in: &local, width: width * 1.05, height: height * 0.86, color: rgb(0.25, 0.72, 1.00).opacity(0.9))
        fillFlame(in: &local, width: width * 0.48, height: height * 0.72, color: rgb(0.92, 0.98, 1.00).opacity(0.95))

        let inner = Path(ellipseIn: CGRect(x: -width * 0.10, y: -height * 0.55, width: width * 0.20, height: height * 0.42))
        local.fill(inner, with: .color(Color.white.opacity(mix(0.2, 0.85, power))))

        let nozzle = CGRect(x: -mix(5, 9, power), y: -2, width: mix(10, 18, power), height: 6)
        local.fill(Path(roundedRect: nozzle, cornerRadius: 1.6), with: .color(rgb(0.22, 0.22, 0.24)))
        local.fill(
            Path(ellipseIn: CGRect(x: -mix(3.2, 5.5, power), y: -4.2, width: mix(6.4, 11, power), height: 3.4)),
            with: .color(rgb(0.12, 0.12, 0.13))
        )
    }

    // MARK: - Molten: heavy lava with falling drips

    private static func drawMolten(
        in context: inout GraphicsContext,
        cell: FireCell,
        frame: FireballsFrame,
        power: CGFloat,
        roar: CGFloat
    ) {
        let wobbleA = 1 + 0.08 * sin(frame.time * 3.1)
        let wobbleB = 1 + 0.08 * sin(frame.time * 2.2 + 1.1)
        let baseW = mix(16, cell.width * 0.58, power)
        let baseH = mix(10, cell.height * 0.28 + roar * cell.height * 0.08, power)

        let a = CGRect(
            x: cell.hearth.x - baseW * 0.52 * wobbleA,
            y: cell.hearth.y - baseH * 0.72,
            width: baseW * wobbleA,
            height: baseH
        )
        let b = CGRect(
            x: cell.hearth.x - baseW * 0.28 * wobbleB,
            y: cell.hearth.y - baseH * 0.95,
            width: baseW * 0.62 * wobbleB,
            height: baseH * 0.85
        )
        context.fill(Path(ellipseIn: a.insetBy(dx: -6, dy: -5)), with: .color(rgb(0.45, 0.05, 0.02).opacity(mix(0.18, 0.45, power))))
        context.fill(Path(ellipseIn: a), with: .color(rgb(0.62, 0.08, 0.03)))
        context.fill(Path(ellipseIn: b), with: .color(rgb(0.95, 0.28, 0.04)))
        context.fill(
            Path(ellipseIn: b.insetBy(dx: b.width * 0.28, dy: b.height * 0.30)),
            with: .color(rgb(1.00, 0.82, 0.28).opacity(mix(0.35, 0.95, power)))
        )

        let drop = mix(cell.height * 0.18, cell.height * 0.85, power)
        let spread = cell.width * 0.42
        for drip in frame.drips {
            let x = cell.hearth.x + drip.x * spread
            let y = cell.hearth.y + drip.y * drop
            let w = drip.width * mix(0.7, 1.25, power)
            let h = w * 1.55
            context.fill(
                Path(ellipseIn: CGRect(x: x - w / 2, y: y, width: w, height: h)),
                with: .color(rgb(0.95, 0.32, 0.05).opacity(0.3 + 0.7 * drip.life))
            )
            context.fill(
                Path(ellipseIn: CGRect(x: x - w * 0.22, y: y + h * 0.15, width: w * 0.45, height: h * 0.4)),
                with: .color(rgb(1.00, 0.85, 0.30).opacity(0.55 * drip.life))
            )
        }
    }

    // MARK: - Vortex: fire whirl

    private static func drawVortex(
        in context: inout GraphicsContext,
        cell: FireCell,
        frame: FireballsFrame,
        power: CGFloat
    ) {
        let center = CGPoint(x: cell.hearth.x, y: cell.hearth.y - mix(10, cell.height * 0.28, power))
        let maxR = mix(cell.width * 0.16, cell.width * 0.46, power)

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - maxR * 0.35, y: center.y - 4, width: maxR * 0.7, height: 9)),
            with: .color(rgb(0.35, 0.08, 0.02).opacity(mix(0.2, 0.65, power)))
        )

        for spark in frame.vortex {
            let r = spark.radius * maxR
            let x = center.x + cos(spark.angle) * r
            let y = center.y + sin(spark.angle) * r * 0.42 - spark.radius * cell.height * mix(0.15, 0.55, power)
            let size = spark.size * mix(0.6, 1.3, power)
            let color = rgb(1.0, 0.32 + spark.warmth * 0.55, spark.arm == 1 ? 0.18 : 0.05)
            context.fill(
                Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size * 1.25)),
                with: .color(color.opacity(0.2 + 0.8 * spark.life))
            )
        }

        let core = mix(3.5, 11, power)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - core / 2, y: center.y - core / 2, width: core, height: core)),
            with: .color(rgb(1.00, 0.92, 0.55).opacity(mix(0.25, 0.9, power)))
        )
    }

    private static func fillFlame(in context: inout GraphicsContext, width: CGFloat, height: CGFloat, color: Color) {
        context.fill(flamePath(width: width, height: height), with: .color(color))
    }

    private static func flamePath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let tip = CGPoint(x: 0, y: -height)
        let left = CGPoint(x: -width * 0.5, y: -height * 0.22)
        let right = CGPoint(x: width * 0.5, y: -height * 0.22)
        let bottom = CGPoint(x: 0, y: width * 0.10)
        path.move(to: tip)
        path.addQuadCurve(to: left, control: CGPoint(x: -width * 0.58, y: -height * 0.58))
        path.addQuadCurve(to: bottom, control: CGPoint(x: -width * 0.40, y: width * 0.28))
        path.addQuadCurve(to: right, control: CGPoint(x: width * 0.40, y: width * 0.28))
        path.addQuadCurve(to: tip, control: CGPoint(x: width * 0.58, y: -height * 0.58))
        path.closeSubpath()
        return path
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    private static func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

#Preview {
    FireballsView()
}
