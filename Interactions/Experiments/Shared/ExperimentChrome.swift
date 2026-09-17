import SwiftUI

struct ExperimentDestination: View {
    let experiment: ExperimentDescriptor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            experiment.makeView()

            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(LabPalette.ink.opacity(0.72))
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to catalog")

                Text("\(experiment.code)  ·  \(experiment.title)")
                    .font(LabType.caption())
                    .tracking(0.6)
                    .foregroundStyle(LabPalette.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, ViewSpaceMotion.windowSafeAreaTop() + 2)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct LabHintOverlay: View {
    let text: String
    @State private var visible = true

    var body: some View {
        VStack {
            Spacer()
            if visible {
                Text(text)
                    .font(LabType.hint())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LabPalette.caption)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4.5))
                withAnimation(.easeOut(duration: 0.8)) {
                    visible = false
                }
            }
        }
    }
}
