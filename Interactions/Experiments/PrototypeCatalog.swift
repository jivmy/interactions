import SwiftUI

/// Ordered rooms the chevrons can page through.
/// Only hanging chain is real in this reset; keep the list so arrows have somewhere to go later.
@MainActor
struct PrototypeDescriptor: Identifiable {
    let id: String
    let makeView: () -> AnyView
}

@MainActor
enum PrototypeCatalog {
    static let hangingChain = PrototypeDescriptor(id: "hanging-chain") {
        AnyView(HangingChainView())
    }

    static let all: [PrototypeDescriptor] = [
        hangingChain
    ]

    static func index(of id: String) -> Int? {
        all.firstIndex { $0.id == id }
    }

    static func neighbors(of id: String) -> (prev: PrototypeDescriptor?, next: PrototypeDescriptor?) {
        guard let i = all.firstIndex(where: { $0.id == id }), all.count > 1 else {
            return (nil, nil)
        }
        return (
            all[(i + all.count - 1) % all.count],
            all[(i + 1) % all.count]
        )
    }
}
