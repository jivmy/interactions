import SwiftUI

struct FireballsView: View {
    var style: Float
    var styleName: String

    @StateObject private var simulation = FireballsSimulation()

    var body: some View {
        let firepower = simulation.firepower
        var uniforms = FireUniforms()
        uniforms.intensity = Float(firepower)
        uniforms.style = style

        return ZStack {
            FireMetalView(fragmentName: "fireballsFragment", uniforms: uniforms)
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
        .ignoresSafeArea()
    }

    private func firepowerLabel(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded())) percent"
    }
}

#Preview {
    FireballsView(style: 0, styleName: "Candle")
}
