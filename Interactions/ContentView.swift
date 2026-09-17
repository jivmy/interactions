import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    ForEach(ExperimentSection.allCases) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 48)
            }
            .background(LabPalette.paper.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interactions")
                .font(LabType.title())
                .foregroundStyle(LabPalette.ink)
            Text("Feel prototypes. Pick an experiment.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(LabPalette.caption)
        }
        .padding(.top, 8)
    }

    private func sectionBlock(_ section: ExperimentSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(LabPalette.ink.opacity(0.8))
                Text(section.blurb)
                    .font(LabType.hint())
                    .foregroundStyle(LabPalette.caption)
            }
            VStack(spacing: 8) {
                ForEach(ExperimentCatalog.experiments(in: section)) { experiment in
                    NavigationLink {
                        ExperimentDestination(experiment: experiment)
                    } label: {
                        ExperimentRow(experiment: experiment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ExperimentRow: View {
    let experiment: ExperimentDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(experiment.code)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(LabPalette.ink.opacity(0.7))
                .frame(width: 36, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(experiment.title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(LabPalette.ink)
                Text(experiment.summary)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(LabPalette.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Text(experiment.hardware)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(LabPalette.caption.opacity(0.85))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LabPalette.caption)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(LabPalette.ink.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
