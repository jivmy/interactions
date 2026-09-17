import SwiftUI

/// Quiet full-screen field. The prototype sits on it; chrome does not.
enum Stage {
    static let fieldWhite: Double = 0.96
    static var field: Color { Color(white: fieldWhite) }
    static let spring = Animation.spring(response: 0.50, dampingFraction: 0.92)
}

/// Full-screen active prototype. Switching is only two icon-only chevrons.
struct ContentView: View {
    @State private var index = 0
    @State private var goingForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rooms = PrototypeCatalog.all
        let current = rooms[min(max(index, 0), rooms.count - 1)]
        let canPage = rooms.count > 1

        ZStack {
            Stage.field
                .ignoresSafeArea()

            current.makeView()
                .id(current.id)
                .transition(pageTransition)
                .zIndex(1)

            VStack {
                Spacer()
                HStack {
                    PrototypeArrow(
                        systemName: "chevron.left",
                        accessibility: "Previous",
                        enabled: canPage
                    ) {
                        page(forward: false, count: rooms.count)
                    }
                    Spacer()
                    PrototypeArrow(
                        systemName: "chevron.right",
                        accessibility: "Next",
                        enabled: canPage
                    ) {
                        page(forward: true, count: rooms.count)
                    }
                }
                .padding(.horizontal, 4)
            }
            .zIndex(2)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.16) : Stage.spring, value: index)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading),
            removal: .move(edge: goingForward ? .leading : .trailing)
        )
    }

    private func page(forward: Bool, count: Int) {
        guard count > 1 else { return }
        goingForward = forward
        if forward {
            index = (index + 1) % count
        } else {
            index = (index + count - 1) % count
        }
    }
}

/// Icon only. 44pt hit, optically small, no pill, no label.
private struct PrototypeArrow: View {
    let systemName: String
    let accessibility: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(enabled ? 0.22 : 0.12))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .allowsHitTesting(enabled)
        .accessibilityLabel(accessibility)
        .accessibilityHidden(!enabled)
    }
}

#Preview {
    ContentView()
}
