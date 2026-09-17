import SwiftUI
import UIKit

/// Shared materials for the lab. Paper, metal, ink — calm enough that every
/// experiment can sit on the same desk without fighting the chrome.
enum LabPalette {
    static let paper = Color(red: 0.957, green: 0.949, blue: 0.929)
    static let paperDeep = Color(red: 0.886, green: 0.871, blue: 0.839)
    static let card = Color.white.opacity(0.58)
    static let ink = Color(red: 0.105, green: 0.098, blue: 0.090)
    static let secondary = Color(red: 0.294, green: 0.278, blue: 0.255)
    static let caption = Color(red: 0.294, green: 0.278, blue: 0.255).opacity(0.62)
    static let metal = Color(red: 0.216, green: 0.224, blue: 0.243)
    static let metalSoft = Color(red: 0.416, green: 0.424, blue: 0.443)
    static let rust = Color(red: 0.545, green: 0.255, blue: 0.149)
    static let tungsten = Color(red: 1.0, green: 0.86, blue: 0.62)
    static let brass = Color(red: 0.76, green: 0.62, blue: 0.34)
    static let sepia = Color(red: 0.42, green: 0.34, blue: 0.24)

    static func track(_ section: ExperimentSection) -> Color {
        switch section {
        case .coreMotion: Color(red: 0.34, green: 0.42, blue: 0.37)
        case .haptics: Color(red: 0.55, green: 0.36, blue: 0.22)
        case .sensors: Color(red: 0.28, green: 0.36, blue: 0.48)
        case .shaders: Color(red: 0.40, green: 0.31, blue: 0.42)
        case .simulation: Color(red: 0.27, green: 0.38, blue: 0.41)
        }
    }
}

enum LabType {
    static func display() -> Font {
        .system(.largeTitle, design: .default, weight: .regular)
    }

    static func title() -> Font {
        .system(.title3, design: .default, weight: .semibold)
    }

    static func body() -> Font {
        .system(.body, design: .default, weight: .regular)
    }

    static func callout() -> Font {
        .system(.callout, design: .default, weight: .medium)
    }

    static func caption() -> Font {
        .system(.caption, design: .default, weight: .semibold)
    }

    static func hint() -> Font {
        .system(.footnote, design: .default, weight: .regular)
    }

    static func mono() -> Font {
        .system(.caption, design: .monospaced, weight: .semibold)
    }
}

enum LabRadius {
    static let card: CGFloat = 18
    static let chip: CGFloat = 13
    static let control: CGFloat = 22
    static let sheet: CGFloat = 28
}

enum LabSpace {
    static let gutter: CGFloat = 20
    static let stack: CGFloat = 14
    static let chrome: CGFloat = 40
}

enum LabMotion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.18)
    static let soft = Animation.spring(response: 0.56, dampingFraction: 0.90, blendDuration: 0.20)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.84, blendDuration: 0.12)
    static let page = Animation.spring(response: 0.46, dampingFraction: 0.90, blendDuration: 0.16)
    static let fade = Animation.easeOut(duration: 0.22)

    static func adaptive(reduceMotion: Bool, _ preferred: Animation = spring) -> Animation {
        reduceMotion ? .easeOut(duration: 0.16) : preferred
    }
}

enum LabShadow {
    static func card() -> Color { Color.black.opacity(0.06) }
    static func lift() -> Color { Color.black.opacity(0.10) }
    static func ground() -> Color { Color.black.opacity(0.14) }
}

enum LabSelect {
    private static let generator = UISelectionFeedbackGenerator()

    static func fire() {
        generator.selectionChanged()
        generator.prepare()
    }
}

private struct LabHeroKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var labHero: Namespace.ID? {
        get { self[LabHeroKey.self] }
        set { self[LabHeroKey.self] = newValue }
    }
}

struct LabPaperBackground: View {
    var body: some View {
        ZStack {
            LabPalette.paper
            LinearGradient(
                colors: [
                    Color.white.opacity(0.28),
                    Color.clear,
                    LabPalette.paperDeep.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct LabCircleButton: View {
    let systemName: String
    var accessibility: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LabPalette.ink.opacity(0.82))
                .frame(width: LabSpace.chrome, height: LabSpace.chrome)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(LabCardButtonStyle())
        .accessibilityLabel(accessibility)
    }
}

struct LabCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(LabMotion.adaptive(reduceMotion: reduceMotion, LabMotion.snappy), value: configuration.isPressed)
    }
}

private struct LabHeroModifier: ViewModifier {
    let id: String
    @Environment(\.labHero) private var hero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if let hero, !reduceMotion {
            content.matchedGeometryEffect(id: id, in: hero)
        } else {
            content
        }
    }
}

extension View {
    func labHero(_ id: String) -> some View {
        modifier(LabHeroModifier(id: id))
    }

    @ViewBuilder
    func labHero(_ id: String, in namespace: Namespace.ID?) -> some View {
        if namespace != nil {
            modifier(LabHeroModifier(id: id))
        } else {
            self
        }
    }

    func labCardSurface() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: LabRadius.card, style: .continuous)
                    .fill(LabPalette.card)
                    .background(
                        RoundedRectangle(cornerRadius: LabRadius.card, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: LabRadius.card, style: .continuous)
                    .strokeBorder(LabPalette.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: LabShadow.card(), radius: 10, x: 0, y: 4)
    }
}
