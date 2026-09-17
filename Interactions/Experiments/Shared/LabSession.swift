import SwiftUI

/// Favorites, recents, and the last open experiment. Survives relaunch so
/// Jimmy can pick up mid-flight without hunting the catalog.
@MainActor
final class LabSession: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var recentIDs: [String]
    @Published private(set) var lastExperimentID: String?

    private let defaults: UserDefaults
    private let favoritesKey = "lab.favorites"
    private let recentsKey = "lab.recents"
    private let lastKey = "lab.lastExperiment"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedFavorites = defaults.stringArray(forKey: favoritesKey) ?? []
        favoriteIDs = Set(storedFavorites)
        recentIDs = defaults.stringArray(forKey: recentsKey) ?? []
        lastExperimentID = defaults.string(forKey: lastKey)
    }

    func isFavorite(_ id: String) -> Bool {
        favoriteIDs.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        defaults.set(Array(favoriteIDs).sorted(), forKey: favoritesKey)
    }

    func opened(_ id: String) {
        lastExperimentID = id
        defaults.set(id, forKey: lastKey)
        var next = recentIDs.filter { $0 != id }
        next.insert(id, at: 0)
        if next.count > 8 { next = Array(next.prefix(8)) }
        recentIDs = next
        defaults.set(next, forKey: recentsKey)
    }

    var favoriteExperiments: [ExperimentDescriptor] {
        ExperimentCatalog.all.filter { favoriteIDs.contains($0.id) }
    }

    var recentExperiments: [ExperimentDescriptor] {
        recentIDs.compactMap { ExperimentCatalog.experiment(id: $0) }
    }

    var lastExperiment: ExperimentDescriptor? {
        lastExperimentID.flatMap { ExperimentCatalog.experiment(id: $0) }
    }
}
