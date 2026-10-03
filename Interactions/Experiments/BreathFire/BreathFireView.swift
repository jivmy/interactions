import SwiftUI

struct BreathFireView: View {
    @StateObject private var simulation = BreathFireSimulation()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let frame = simulation.frame
        var uniforms = FireUniforms()
        uniforms.intensity = Float(frame.heat)

        return FireMetalView(fragmentName: "breathFireFragment", uniforms: uniforms)
            .accessibilityLabel("Fire")
            .accessibilityValue(valueLabel(frame))
            .accessibilityHint("Blow into the microphone")
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

    private func valueLabel(_ frame: BreathFireFrame) -> String {
        if frame.denied { return "Microphone off" }
        return "\(Int((frame.heat * 100).rounded())) percent"
    }
}

#Preview {
    BreathFireView()
}
