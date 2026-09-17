import SwiftUI
import UIKit

/// Full-screen experiment with floating chrome that stays out of the prototype.
/// Prev / next and a switcher live in the thumb zone for a tray-table phone.
struct ExperimentWorkspace: View {
    @EnvironmentObject private var session: LabSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentID: String
    @State private var showSwitcher = false

    init(experimentID: String) {
        _currentID = State(initialValue: experimentID)
    }

    private var experiment: ExperimentDescriptor {
        ExperimentCatalog.experiment(id: currentID) ?? ExperimentCatalog.all[0]
    }

    private var trackNeighbors: (prev: ExperimentDescriptor?, next: ExperimentDescriptor?) {
        ExperimentCatalog.neighbors(of: experiment.id, in: experiment.section)
    }

    var body: some View {
        ZStack {
            experiment.makeView()
                .id(currentID)
                .transition(contentTransition)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                Spacer(minLength: 0)
                bottomBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }
            .padding(.top, ViewSpaceMotion.windowSafeAreaTop())
            .padding(.bottom, 8)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSwitcher) {
            ExperimentSwitcherSheet(currentID: currentID) { id in
                switchTo(id)
                showSwitcher = false
            }
            .environmentObject(session)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(LabRadius.sheet)
        }
        .onAppear {
            session.opened(currentID)
        }
        .onChange(of: currentID) { _, id in
            session.opened(id)
        }
        .accessibilityElement(children: .contain)
    }

    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985))
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            LabCircleButton(systemName: "chevron.left", accessibility: "Back to catalog") {
                dismiss()
            }

            HStack(spacing: 8) {
                Text(experiment.code)
                    .font(LabType.mono())
                    .foregroundStyle(LabPalette.track(experiment.section))
                Text(experiment.title)
                    .font(LabType.caption())
                    .foregroundStyle(LabPalette.ink.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: LabSpace.chrome)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 0.5))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("\(experiment.code), \(experiment.title)")

            Spacer(minLength: 0)

            LabCircleButton(
                systemName: session.isFavorite(experiment.id) ? "star.fill" : "star",
                accessibility: session.isFavorite(experiment.id) ? "Remove from favorites" : "Add to favorites"
            ) {
                session.toggleFavorite(experiment.id)
            }
        }
    }

    private var bottomBar: some View {
        let neighbors = trackNeighbors
        return HStack(spacing: 10) {
            LabCircleButton(systemName: "chevron.left", accessibility: previousLabel(neighbors.prev)) {
                if let prev = neighbors.prev { switchTo(prev.id) }
            }
            .opacity(neighbors.prev == nil ? 0.35 : 1)
            .disabled(neighbors.prev == nil)
            .accessibilityHint("Loops within this track")

            Button {
                showSwitcher = true
            } label: {
                VStack(spacing: 6) {
                    HStack(spacing: 5) {
                        ForEach(ExperimentCatalog.experiments(in: experiment.section)) { item in
                            Circle()
                                .fill(item.id == experiment.id ? LabPalette.track(experiment.section) : LabPalette.ink.opacity(0.18))
                                .frame(width: item.id == experiment.id ? 7 : 5, height: item.id == experiment.id ? 7 : 5)
                        }
                    }
                    Text("\(experiment.section.track)  ·  \(experiment.section.title)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LabPalette.ink.opacity(0.62))
                }
                .frame(maxWidth: .infinity)
                .frame(height: LabSpace.chrome)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch experiment")
            .accessibilityHint("Opens the lab switcher")
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -40, let next = neighbors.next {
                            switchTo(next.id)
                        } else if value.translation.width > 40, let prev = neighbors.prev {
                            switchTo(prev.id)
                        }
                    }
            )

            LabCircleButton(systemName: "chevron.right", accessibility: nextLabel(neighbors.next)) {
                if let next = neighbors.next { switchTo(next.id) }
            }
            .opacity(neighbors.next == nil ? 0.35 : 1)
            .disabled(neighbors.next == nil)
        }
        .accessibilityElement(children: .contain)
    }

    private func previousLabel(_ prev: ExperimentDescriptor?) -> String {
        if let prev { return "Previous, \(prev.code) \(prev.title)" }
        return "Previous experiment unavailable"
    }

    private func nextLabel(_ next: ExperimentDescriptor?) -> String {
        if let next { return "Next, \(next.code) \(next.title)" }
        return "Next experiment unavailable"
    }

    private func switchTo(_ id: String) {
        guard id != currentID else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.soft)) {
            currentID = id
        }
    }
}

struct ExperimentSwitcherSheet: View {
    let currentID: String
    var onSelect: (String) -> Void

    @EnvironmentObject private var session: LabSession
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var track: ExperimentSection?

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty, !session.favoriteExperiments.isEmpty {
                    Section("Favorites") {
                        ForEach(session.favoriteExperiments) { item in
                            switcherRow(item)
                        }
                    }
                }
                ForEach(visibleSections) { section in
                    Section(section.heading) {
                        ForEach(filtered(in: section)) { item in
                            switcherRow(item)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search the lab")
            .safeAreaInset(edge: .top, spacing: 0) {
                trackChips
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .navigationTitle("Switch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var visibleSections: [ExperimentSection] {
        if let track { return [track] }
        return ExperimentSection.allCases.filter { !filtered(in: $0).isEmpty }
    }

    private func filtered(in section: ExperimentSection) -> [ExperimentDescriptor] {
        ExperimentCatalog.experiments(in: section).filter { $0.matches(query) }
    }

    private var trackChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", selected: track == nil, color: LabPalette.ink) {
                    track = nil
                }
                ForEach(ExperimentSection.allCases) { section in
                    chip(title: section.track, selected: track == section, color: LabPalette.track(section)) {
                        track = track == section ? nil : section
                    }
                }
            }
        }
        .accessibilityLabel("Filter by track")
    }

    private func chip(title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : LabPalette.ink.opacity(0.78))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? color : LabPalette.paperDeep.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func switcherRow(_ item: ExperimentDescriptor) -> some View {
        Button {
            onSelect(item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(LabPalette.track(item.section))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.code)
                            .font(LabType.mono())
                            .foregroundStyle(LabPalette.track(item.section))
                        Text(item.title)
                            .font(LabType.callout())
                            .foregroundStyle(LabPalette.ink)
                    }
                    Text(item.summary)
                        .font(LabType.hint())
                        .foregroundStyle(LabPalette.caption)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if item.id == currentID {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LabPalette.track(item.section))
                        .accessibilityLabel("Current")
                }
                if session.isFavorite(item.id) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(LabPalette.brass)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.code) \(item.title)")
        .accessibilityHint(item.id == currentID ? "Currently open" : "Switch to this experiment")
    }
}

/// Short coaching that fades. Re-announces when the copy changes.
struct LabHintOverlay: View {
    let text: String
    var duration: TimeInterval = 3.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true
    @State private var token = UUID()

    var body: some View {
        VStack {
            Spacer()
            if visible {
                Text(text)
                    .font(LabType.hint())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LabPalette.ink.opacity(0.78))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.05), lineWidth: 0.5))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 86)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .allowsHitTesting(false)
        .onAppear { reveal() }
        .onChange(of: text) { _, _ in
            reveal()
        }
        .accessibilityHidden(!visible)
    }

    private func reveal() {
        visible = true
        let id = UUID()
        token = id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard token == id else { return }
            withAnimation(reduceMotion ? LabMotion.fade : .easeOut(duration: 0.7)) {
                visible = false
            }
        }
    }
}

/// Quiet, persistent fallback / permission chip. Does not fade.
struct LabFallbackChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(LabPalette.ink.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.05), lineWidth: 0.5))
            .accessibilityAddTraits(.isStaticText)
    }
}

/// Back-compat wrapper used by older destinations.
struct ExperimentDestination: View {
    let experiment: ExperimentDescriptor

    var body: some View {
        ExperimentWorkspace(experimentID: experiment.id)
    }
}
