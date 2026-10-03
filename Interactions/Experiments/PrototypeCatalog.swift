import SwiftUI

/// Ordered rooms the chevrons page through.
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

    static let fireCandle = PrototypeDescriptor(id: "fire-candle") {
        AnyView(FireballsView(style: 0, styleName: "Candle"))
    }

    static let fireHearth = PrototypeDescriptor(id: "fire-hearth") {
        AnyView(FireballsView(style: 1, styleName: "Hearth"))
    }

    static let fireTorch = PrototypeDescriptor(id: "fire-torch") {
        AnyView(FireballsView(style: 2, styleName: "Torch"))
    }

    static let fireBonfire = PrototypeDescriptor(id: "fire-bonfire") {
        AnyView(FireballsView(style: 3, styleName: "Bonfire"))
    }

    static let breathFire = PrototypeDescriptor(id: "breath-fire") {
        AnyView(BreathFireView())
    }

    static let fireLean = PrototypeDescriptor(id: "fire-lean") {
        AnyView(FireLeanView())
    }

    static let fireTrail = PrototypeDescriptor(id: "fire-trail") {
        AnyView(FireTrailView())
    }

    static let fireWhirl = PrototypeDescriptor(id: "fire-whirl") {
        AnyView(FireWhirlView())
    }

    static let fireSheet = PrototypeDescriptor(id: "fire-sheet") {
        AnyView(FireSheetView())
    }

    static let fireStrike = PrototypeDescriptor(id: "fire-strike") {
        AnyView(FireStrikeView())
    }

    static let all: [PrototypeDescriptor] = [
        hangingChain,
        fireCandle,
        fireHearth,
        fireTorch,
        fireBonfire,
        breathFire,
        fireLean,
        fireTrail,
        fireWhirl,
        fireSheet,
        fireStrike
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
