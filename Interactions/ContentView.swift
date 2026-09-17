import SwiftUI

struct ContentView: View {
    @StateObject private var session = LabSession()
    @State private var path: [String] = []
    @Namespace private var labHero

    var body: some View {
        NavigationStack(path: $path) {
            CatalogHome()
                .navigationDestination(for: String.self) { id in
                    ExperimentWorkspace(experimentID: id)
                }
        }
        .environmentObject(session)
        .environment(\.labHero, labHero)
        .tint(LabPalette.ink)
        .onOpenURL { url in
            if let id = ExperimentCatalog.resolve(url: url) {
                path = [id]
            }
        }
    }
}

struct CatalogHome: View {
    @EnvironmentObject private var session: LabSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var track: ExperimentSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                searchField
                trackChips
                if query.isEmpty {
                    continueCard
                    rail(title: "Favorites", items: session.favoriteExperiments)
                    rail(title: "Recents", items: session.recentExperiments.filter { $0.id != session.lastExperimentID })
                }
                if isSearching {
                    resultsList
                } else {
                    ForEach(visibleSections) { section in
                        sectionBlock(section)
                    }
                }
            }
            .padding(.horizontal, LabSpace.gutter)
            .padding(.top, 8)
            .padding(.bottom, 56)
            .animation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.soft), value: track)
        }
        .background(LabPaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.immediately)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleSections: [ExperimentSection] {
        if let track { return [track] }
        return ExperimentSection.allCases
    }

    private var filteredAll: [ExperimentDescriptor] {
        ExperimentCatalog.all.filter { item in
            if let track, item.section != track { return false }
            return item.matches(query)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Interactions")
                .font(LabType.display())
                .foregroundStyle(LabPalette.ink)
            Text("Feel prototypes.")
                .font(LabType.hint())
                .foregroundStyle(LabPalette.caption)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LabPalette.caption)
            TextField("Search", text: $query)
                .font(LabType.body())
                .foregroundStyle(LabPalette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LabPalette.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LabRadius.chip, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LabRadius.chip, style: .continuous)
                .strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var trackChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", subtitle: nil, selected: track == nil, color: LabPalette.ink) {
                    LabSelect.fire()
                    track = nil
                }
                ForEach(ExperimentSection.allCases) { section in
                    filterChip(
                        title: section.track,
                        subtitle: section.title,
                        selected: track == section,
                        color: LabPalette.track(section)
                    ) {
                        LabSelect.fire()
                        track = track == section ? nil : section
                    }
                }
            }
        }
        .accessibilityLabel("Filter by track")
    }

    private func filterChip(title: String, subtitle: String?, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle, selected {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .opacity(0.86)
                }
            }
            .foregroundStyle(selected ? Color.white : LabPalette.ink.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? color : Color.white.opacity(0.42), in: Capsule())
            .overlay(Capsule().strokeBorder(LabPalette.ink.opacity(selected ? 0 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(subtitle.map { "\(title) \($0)" } ?? title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var continueCard: some View {
        if let last = session.lastExperiment {
            NavigationLink(value: last.id) {
                HStack(spacing: 14) {
                    Text(last.code)
                        .font(LabType.mono())
                        .foregroundStyle(LabPalette.track(last.section))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(LabPalette.caption)
                        Text(last.title)
                            .font(LabType.callout())
                            .foregroundStyle(LabPalette.ink)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LabPalette.caption)
                }
                .padding(16)
                .labCardSurface()
            }
            .buttonStyle(LabCardButtonStyle())
            .accessibilityLabel("Continue \(last.code) \(last.title)")
        }
    }

    @ViewBuilder
    private func rail(title: String, items: [ExperimentDescriptor]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LabPalette.ink.opacity(0.72))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { item in
                            NavigationLink(value: item.id) {
                                compactCard(item)
                            }
                            .buttonStyle(LabCardButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func compactCard(_ item: ExperimentDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.code)
                .font(LabType.mono())
                .foregroundStyle(LabPalette.track(item.section))
            Text(item.title)
                .font(LabType.callout())
                .foregroundStyle(LabPalette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 156, alignment: .leading)
        .labCardSurface()
        .accessibilityLabel("\(item.code) \(item.title)")
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if filteredAll.isEmpty {
                Text("Nothing matches.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LabPalette.ink.opacity(0.72))
            }
            ForEach(filteredAll) { item in
                experimentRow(item)
            }
        }
    }

    private func sectionBlock(_ section: ExperimentSection) -> some View {
        let items = ExperimentCatalog.experiments(in: section).filter { $0.matches(query) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(section.track)
                    .font(LabType.mono())
                    .foregroundStyle(LabPalette.track(section))
                    .labHero("track-\(section.rawValue)")
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LabPalette.ink.opacity(0.86))
                Text(section.blurb)
                    .font(LabType.hint())
                    .foregroundStyle(LabPalette.caption)
                    .lineLimit(1)
            }
            VStack(spacing: 8) {
                ForEach(items) { item in
                    experimentRow(item)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section.heading)
    }

    private func experimentRow(_ item: ExperimentDescriptor) -> some View {
        HStack(alignment: .center, spacing: 0) {
            NavigationLink(value: item.id) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.code)
                        .font(LabType.mono())
                        .foregroundStyle(LabPalette.track(item.section))
                        .frame(width: 34, alignment: .leading)
                        .labHero("code-\(item.id)")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(LabType.callout())
                            .foregroundStyle(LabPalette.ink)
                            .labHero("title-\(item.id)")
                        Text(item.summary)
                            .font(LabType.hint())
                            .foregroundStyle(LabPalette.caption)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                }
                .padding(.vertical, 14)
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(LabCardButtonStyle())
            .accessibilityLabel("\(item.code) \(item.title)")
            .accessibilityHint(item.summary)

            Button {
                LabSelect.fire()
                session.toggleFavorite(item.id)
            } label: {
                Image(systemName: session.isFavorite(item.id) ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(session.isFavorite(item.id) ? LabPalette.brass : LabPalette.caption)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .symbolEffect(.bounce, value: session.isFavorite(item.id))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isFavorite(item.id) ? "Remove \(item.title) from favorites" : "Add \(item.title) to favorites")
            .padding(.trailing, 6)
        }
        .labCardSurface()
    }
}

#Preview {
    ContentView()
}
