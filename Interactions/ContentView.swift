import SwiftUI

struct ContentView: View {
    var body: some View {
        // Home is the featured experiment. Swap in a list of
        // ExperimentCatalog.all when a second experiment ships.
        ExperimentCatalog.featured.makeView()
    }
}

#Preview {
    ContentView()
}
