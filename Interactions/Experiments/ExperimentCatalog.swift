import SwiftUI

/// One entry in Jimmy’s interaction lab.
///
/// Add future experiments here (pull-cord, compass mercury, …) without
/// rewriting the app root. Shipping today: A1 Hanging chain as the home screen.
struct ExperimentDescriptor: Identifiable {
    let id: String
    let code: String
    let title: String
    let summary: String
    let makeView: () -> AnyView

    init<V: View>(
        id: String,
        code: String,
        title: String,
        summary: String,
        @ViewBuilder content: @escaping () -> V
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.summary = summary
        self.makeView = { AnyView(content()) }
    }
}

enum ExperimentCatalog {
    static let hangingChain = ExperimentDescriptor(
        id: "hanging-chain",
        code: "A1",
        title: "Hanging chain",
        summary: "A Verlet rope pinned at the top of the screen, swung by real device gravity."
    ) {
        HangingChainView()
    }

    /// Register new experiments in this array. A list UI can sit on top later.
    static let all: [ExperimentDescriptor] = [
        hangingChain
    ]

    static var featured: ExperimentDescriptor { hangingChain }
}
