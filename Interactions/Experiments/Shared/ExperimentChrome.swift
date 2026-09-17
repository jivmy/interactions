import SwiftUI

/// Full-screen experiment with floating chrome that stays out of the prototype.
/// Prev / next and a switcher live in the thumb zone for a tray-table phone.
struct ExperimentWorkspace: View {
    @EnvironmentObject private var session: LabSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.labHero) private var hero

    @State private var currentID: String
    @State private var showSwitcher = false
    @State private var slideForward = true

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
            ZStack {
                experiment.makeView()
                    .id(currentID)
                    .transition(contentTransition)
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                bottomBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }
            .padding(.top, ViewSpaceMotion.windowSafeAreaTop())
            .padding(.bottom, 6)
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
        if reduceMotion { return .opacity }
        let incoming: CGFloat = slideForward ? 44 : -44
        let outgoing: CGFloat = slideForward ? -28 : 28
        return .asymmetric(
            insertion: .offset(x: incoming).combined(with: .opacity),
            removal: .offset(x: outgoing).combined(with: .opacity)
        )
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            LabCircleButton(systemName: "chevron.left", accessibility: "Back to catalog") {
                dismiss()
            }

            HStack(spacing: 7) {
                Text(experiment.code)
                    .font(LabType.mono())
                    .foregroundStyle(LabPalette.track(experiment.section))
                    .labHero("code-\(experiment.id)", in: hero)
                Text(experiment.title)
                    .font(LabType.caption())
                    .foregroundStyle(LabPalette.ink.opacity(0.78))
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 12)
            .frame(height: LabSpace.chrome)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 0.5))
            .animation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.page), value: currentID)
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
        return HStack(spacing: 8) {
            LabCircleButton(systemName: "chevron.left", accessibility: neighborLabel("Previous", neighbors.prev)) {
                if let prev = neighbors.prev { switchTo(prev.id) }
            }

            Button {
                showSwitcher = true
            } label: {
                HStack(spacing: 8) {
                    Text(experiment.section.track)
                        .font(LabType.mono())
                        .foregroundStyle(LabPalette.track(experiment.section))
                    HStack(spacing: 5) {
                        ForEach(ExperimentCatalog.experiments(in: experiment.section)) { item in
                            Capsule()
                                .fill(item.id == experiment.id ? LabPalette.track(experiment.section) : LabPalette.ink.opacity(0.16))
                                .frame(width: item.id == experiment.id ? 14 : 5, height: 5)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: LabSpace.chrome)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 0.5))
                .animation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.snappy), value: currentID)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(experiment.code) \(experiment.title)")
            .accessibilityHint("Opens the lab. Swipe for neighbors.")
            .highPriorityGesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let dx = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        if dx < -24 || predicted < -48, let next = neighbors.next {
                            switchTo(next.id)
                        } else if dx > 24 || predicted > 48, let prev = neighbors.prev {
                            switchTo(prev.id)
                        }
                    }
            )

            LabCircleButton(systemName: "chevron.right", accessibility: neighborLabel("Next", neighbors.next)) {
                if let next = neighbors.next { switchTo(next.id) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func neighborLabel(_ prefix: String, _ item: ExperimentDescriptor?) -> String {
        if let item { return "\(prefix), \(item.code) \(item.title)" }
        return "\(prefix) experiment unavailable"
    }

    private func switchTo(_ id: String) {
        guard id != currentID else { return }
        slideForward = ExperimentCatalog.isForward(from: currentID, to: id, in: experiment.section)
        LabSelect.fire()
        withAnimation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.page)) {
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

    init(currentID: String, onSelect: @escaping (String) -> Void) {
        self.currentID = currentID
        self.onSelect = onSelect
        _track = State(initialValue: ExperimentCatalog.experiment(id: currentID)?.section)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty, track == nil {
                    if !session.favoriteExperiments.isEmpty {
                        Section("Favorites") {
                            ForEach(session.favoriteExperiments) { item in
                                switcherRow(item)
                            }
                        }
                    }
                    let recents = Array(session.recentExperiments.filter { $0.id != currentID }.prefix(4))
                    if !recents.isEmpty {
                        Section("Recents") {
                            ForEach(recents) { item in
                                switcherRow(item)
                            }
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
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .safeAreaInset(edge: .top, spacing: 0) {
                trackChips
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .navigationTitle("Lab")
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
                Text(item.code)
                    .font(LabType.mono())
                    .foregroundStyle(LabPalette.track(item.section))
                    .frame(width: 32, alignment: .leading)
                Text(item.title)
                    .font(LabType.callout())
                    .foregroundStyle(LabPalette.ink)
                Spacer(minLength: 0)
                if item.id == currentID {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LabPalette.track(item.section))
                        .accessibilityLabel("Current")
                } else if session.isFavorite(item.id) {
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
        .accessibilityHint(item.id == currentID ? "Current" : "Open")
    }
}

/// Short coaching that fades. Re-announces when the copy changes.
struct LabHintOverlay: View {
    let text: String
    var duration: TimeInterval = 2.4

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
                    .foregroundStyle(LabPalette.ink.opacity(0.72))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(0.05), lineWidth: 0.5))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 78)
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
            withAnimation(reduceMotion ? LabMotion.fade : .easeOut(duration: 0.55)) {
                visible = false
            }
        }
    }
}

/// Quiet status chip. Fades so it does not sit on the prototype.
struct LabFallbackChip: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true

    var body: some View {
        Group {
            if visible {
                Text(text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(LabPalette.ink.opacity(0.62))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.8))
                withAnimation(reduceMotion ? LabMotion.fade : .easeOut(duration: 0.5)) {
                    visible = false
                }
            }
        }
    }
}
