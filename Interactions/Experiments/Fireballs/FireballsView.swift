import SwiftUI

/// Two swipeable 2×3 grids. Each cell is its own Metal fragment shader.
struct FireballsView: View {
    var style: Float
    var styleName: String

    @StateObject private var simulation = FireballsSimulation()

    private static let gridA = [
        "fireShadeCandle",
        "fireShadeSpine",
        "fireShadeColumn",
        "fireShadeBowl",
        "fireShadeBlade",
        "fireShadeOrb"
    ]

    private static let gridB = [
        "fireShadeVolume",
        "fireShadeCurl",
        "fireShadePolar",
        "fireShadeForge",
        "fireShadeWick",
        "fireShadeBloom"
    ]

    var body: some View {
        let firepower = simulation.firepower
        let names = style < 0.5 ? Self.gridA : Self.gridB

        return ZStack {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { col in
                            cell(names[row * 2 + col], firepower: firepower)
                        }
                    }
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 118)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 48)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy), abs(dx) > 56 else { return }
                        RoomPaging.request(forward: dx < 0)
                    }
            )
            .accessibilityLabel("Fire")
            .accessibilityValue(firepowerLabel(firepower))
            .accessibilityHint(styleName)

            VStack {
                Spacer()
                Slider(value: $simulation.firepower, in: 0...1)
                    .tint(Color(red: 0.20, green: 0.14, blue: 0.10).opacity(0.55))
                    .padding(.horizontal, 62)
                    .padding(.bottom, 54)
                    .accessibilityLabel("Firepower")
            }
        }
        .background(Color(white: Stage.fieldWhite))
        .ignoresSafeArea()
    }

    private func cell(_ fragmentName: String, firepower: CGFloat) -> some View {
        var uniforms = FireUniforms()
        uniforms.intensity = Float(firepower)
        return FireMetalView(fragmentName: fragmentName, uniforms: uniforms)
    }

    private func firepowerLabel(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded())) percent"
    }
}

#Preview {
    FireballsView(style: 0, styleName: "Grid A")
}
