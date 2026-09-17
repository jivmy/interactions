import SwiftUI

enum LabPalette {
    static let paper = Color(red: 0.925, green: 0.914, blue: 0.890)
    static let paperDeep = Color(red: 0.86, green: 0.84, blue: 0.80)
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    static let caption = Color(red: 0.28, green: 0.27, blue: 0.25).opacity(0.55)
    static let metal = Color(red: 0.22, green: 0.23, blue: 0.25)
    static let metalSoft = Color(red: 0.38, green: 0.38, blue: 0.40)
    static let rust = Color(red: 0.45, green: 0.22, blue: 0.12)
    static let tungsten = Color(red: 1.0, green: 0.86, blue: 0.62)
}

enum LabType {
    static func caption() -> Font {
        .system(.caption, design: .rounded, weight: .medium)
    }

    static func hint() -> Font {
        .system(.footnote, design: .rounded)
    }

    static func title() -> Font {
        .system(.largeTitle, design: .serif, weight: .regular)
    }
}
