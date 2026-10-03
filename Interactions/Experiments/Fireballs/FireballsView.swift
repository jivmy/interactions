import SwiftUI

struct FireballsView: View {
    @StateObject private var simulation = FireballsSimulation()

    var body: some View {
        let firepower = simulation.firepower
        var uniforms = FireUniforms()
        uniforms.intensity = Float(firepower)

        return ZStack {
            FireMetalView(fragmentName: "fireballsFragment", uniforms: uniforms)
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
        .ignoresSafeArea()
    }

    private func firepowerLabel(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded())) percent"
    }
}

#Preview {
    FireballsView()
}
