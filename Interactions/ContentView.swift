import SwiftUI

struct ContentView: View {
    @StateObject private var session = LabSession()
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            CatalogHome()
                .navigationDestination(for: String.self) { id in
                    ExperimentWorkspace(experimentID: id)
                }
        }
        .environmentObject(session)
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

    @State private var query = ""
    @State private var track: ExperimentSection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                searchField
                trackChips
                if query.isEmpty {
                    continueCard
                    rail(title: "Favorites", items: session.favoriteExperiments)
                    rail(title: "Recent", items: session.recentExperiments.filter { $0.id != session.lastExperimentID })
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
        }
        .background(LabPaperBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || track != nil
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Interactions")
                .font(LabType.display())
                .foregroundStyle(LabPalette.ink)
            Text("Eighteen feel prototypes. Browse, favorite, swipe a track.")
                .font(LabType.hint())
                .foregroundStyle(LabPalette.caption)
                .fixedSize(horizontal: false, vertical: true)
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
            TextField("Search experiments", text: $query)
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
        .frame(height: 48)
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
                    track = nil
                }
                ForEach(ExperimentSection.allCases) { section in
                    filterChip(
                        title: section.track,
                        subtitle: section.title,
                        selected: track == section,
                        color: LabPalette.track(section)
                    ) {
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
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .opacity(selected ? 0.86 : 0.7)
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
                    Image(systemName: last.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(LabPalette.track(last.section))
                        .frame(width: 36, height: 36)
                        .background(LabPalette.track(last.section).opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Continue")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LabPalette.caption)
                        Text("\(last.code)  ·  \(last.title)")
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
            HStack {
                Text(item.code)
                    .font(LabType.mono())
                    .foregroundStyle(LabPalette.track(item.section))
                Spacer(minLength: 0)
                Image(systemName: item.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LabPalette.track(item.section).opacity(0.8))
            }
            Text(item.title)
                .font(LabType.callout())
                .foregroundStyle(LabPalette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 168, alignment: .leading)
        .labCardSurface()
        .accessibilityLabel("\(item.code) \(item.title)")
    }

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(filteredAll.isEmpty ? "No experiments match" : "\(filteredAll.count) of 18")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LabPalette.ink.opacity(0.72))
            ForEach(filteredAll) { item in
                experimentRow(item)
            }
        }
    }

    private func sectionBlock(_ section: ExperimentSection) -> some View {
        let items = ExperimentCatalog.experiments(in: section).filter { $0.matches(query) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LabPalette.track(section))
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.heading)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LabPalette.ink.opacity(0.86))
                    Text(section.blurb)
                        .font(LabType.hint())
                        .foregroundStyle(LabPalette.caption)
                }
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
                HStack(alignment: .top, spacing: 12) {
                    Text(item.code)
                        .font(LabType.mono())
                        .foregroundStyle(LabPalette.track(item.section))
                        .frame(width: 34, alignment: .leading)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(LabType.callout())
                            .foregroundStyle(LabPalette.ink)
                        Text(item.summary)
                            .font(LabType.hint())
                            .foregroundStyle(LabPalette.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.hardware)
                            .font(.caption2)
                            .foregroundStyle(LabPalette.caption.opacity(0.9))
                            .padding(.top, 1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LabPalette.caption)
                        .padding(.top, 4)
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
                session.toggleFavorite(item.id)
            } label: {
                Image(systemName: session.isFavorite(item.id) ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(session.isFavorite(item.id) ? LabPalette.brass : LabPalette.caption)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
