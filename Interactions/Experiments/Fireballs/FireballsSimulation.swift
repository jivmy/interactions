import Combine
import CoreGraphics

/// Firepower only. The hearths live in the Metal fragment.
@MainActor
final class FireballsSimulation: ObservableObject {
    @Published var firepower: CGFloat = 0.5
}
