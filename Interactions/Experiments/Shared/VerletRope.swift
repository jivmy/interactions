import CoreGraphics
import Foundation

/// One mass point in a Verlet rope.
struct VerletParticle {
    var position: CGPoint
    var oldPosition: CGPoint
    var pinned: Bool
}

/// Classic Jakobsen-style rope: Verlet integration + distance constraints.
/// Equal-step particles, first point pinned. A heavier last particle reads as a pendant.
struct VerletRope {
    var particles: [VerletParticle]
    var restLength: CGFloat
    var damping60: CGFloat
    var iterations: Int
    var draggedIndex: Int?
    var bounds: CGRect?

    static func hanging(
        count: Int,
        origin: CGPoint,
        restLength: CGFloat,
        damping60: CGFloat = 0.988,
        iterations: Int = 12
    ) -> VerletRope {
        let particles = (0..<count).map { index -> VerletParticle in
            let point = CGPoint(x: origin.x, y: origin.y + CGFloat(index) * restLength)
            return VerletParticle(position: point, oldPosition: point, pinned: index == 0)
        }
        return VerletRope(
            particles: particles,
            restLength: restLength,
            damping60: damping60,
            iterations: iterations,
            draggedIndex: nil,
            bounds: nil
        )
    }

    var positions: [CGPoint] {
        particles.map(\.position)
    }

    mutating func integrate(gravity: CGVector, dt: CGFloat) {
        guard dt > 0, dt.isFinite else { return }
        let damp = pow(damping60, dt * 60)
        let ax = gravity.dx * dt * dt
        let ay = gravity.dy * dt * dt

        for index in particles.indices {
            if particles[index].pinned { continue }
            if index == draggedIndex { continue }

            let position = particles[index].position
            let old = particles[index].oldPosition
            let vx = (position.x - old.x) * damp
            let vy = (position.y - old.y) * damp
            particles[index].oldPosition = position
            particles[index].position = CGPoint(x: position.x + vx + ax, y: position.y + vy + ay)
        }
    }

    mutating func solveConstraints(anchor: CGPoint) {
        guard particles.count >= 2 else { return }

        for _ in 0..<iterations {
            particles[0].position = anchor
            particles[0].oldPosition = anchor

            for index in 0..<(particles.count - 1) {
                satisfyDistance(i: index, j: index + 1)
            }

            applyBounds()
        }

        particles[0].position = anchor
        particles[0].oldPosition = anchor
    }

    mutating func beginDrag(at point: CGPoint, grabRadius: CGFloat = 56) {
        guard particles.count > 1 else { return }
        var bestIndex: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        let last = particles.count - 1
        for index in 1..<particles.count {
            let radius = index == last ? grabRadius * 1.45 : grabRadius
            let distance = hypot(
                particles[index].position.x - point.x,
                particles[index].position.y - point.y
            )
            if distance <= radius && distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        draggedIndex = bestIndex
        moveDrag(to: point)
    }

    mutating func moveDrag(to point: CGPoint) {
        guard let draggedIndex, particles.indices.contains(draggedIndex) else { return }
        particles[draggedIndex].oldPosition = particles[draggedIndex].position
        particles[draggedIndex].position = point
    }

    mutating func endDrag() {
        draggedIndex = nil
    }

    private func inverseMass(at index: Int) -> CGFloat {
        if particles[index].pinned { return 0 }
        if index == draggedIndex { return 0 }
        if index == particles.count - 1 { return 0.4 }
        return 1
    }

    private mutating func satisfyDistance(i: Int, j: Int) {
        let a = particles[i].position
        let b = particles[j].position
        let dx = b.x - a.x
        let dy = b.y - a.y
        let distance = hypot(dx, dy)
        guard distance > 0.0001 else { return }

        let w1 = inverseMass(at: i)
        let w2 = inverseMass(at: j)
        let weight = w1 + w2
        guard weight > 0 else { return }

        let correction = (distance - restLength) / distance
        let ox = dx * correction
        let oy = dy * correction
        if w1 > 0 {
            particles[i].position.x += ox * (w1 / weight)
            particles[i].position.y += oy * (w1 / weight)
        }
        if w2 > 0 {
            particles[j].position.x -= ox * (w2 / weight)
            particles[j].position.y -= oy * (w2 / weight)
        }
    }

    private mutating func applyBounds() {
        guard let bounds else { return }
        let inset: CGFloat = 10
        let minX = bounds.minX + inset
        let maxX = bounds.maxX - inset
        let minY = bounds.minY + inset
        let maxY = bounds.maxY - inset
        for index in particles.indices where inverseMass(at: index) > 0 {
            var p = particles[index].position
            var old = particles[index].oldPosition
            if p.x < minX {
                let vx = p.x - old.x
                p.x = minX
                old.x = p.x + vx * 0.25
            } else if p.x > maxX {
                let vx = p.x - old.x
                p.x = maxX
                old.x = p.x + vx * 0.25
            }
            if p.y < minY {
                let vy = p.y - old.y
                p.y = minY
                old.y = p.y + vy * 0.25
            } else if p.y > maxY {
                let vy = p.y - old.y
                p.y = maxY
                old.y = p.y + vy * 0.25
            }
            particles[index].position = p
            particles[index].oldPosition = old
        }
    }
}
