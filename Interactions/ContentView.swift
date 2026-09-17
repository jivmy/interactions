import SwiftUI

/// Full-screen active prototype. Switching is only quiet chevrons.
struct ContentView: View {
    @State private var index = 0

    var body: some View {
        let rooms = PrototypeCatalog.all
        let current = rooms[min(max(index, 0), rooms.count - 1)]
        let canPage = rooms.count > 1

        ZStack {
            current.makeView()
                .id(current.id)

            VStack {
                Spacer()
                HStack {
                    PrototypeArrow(
                        systemName: "chevron.left",
                        accessibility: "Previous prototype",
                        enabled: canPage
                    ) {
                        index = (index + rooms.count - 1) % rooms.count
                    }
                    Spacer()
                    PrototypeArrow(
                        systemName: "chevron.right",
                        accessibility: "Next prototype",
                        enabled: canPage
                    ) {
                        index = (index + 1) % rooms.count
                    }
                }
                .padding(.horizontal, 6)
            }
        }
    }
}

/// Tiny corner chevron. No label, no track letter, no material pill.
private struct PrototypeArrow: View {
    let systemName: String
    let accessibility: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(enabled ? 0.26 : 0.10))
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
