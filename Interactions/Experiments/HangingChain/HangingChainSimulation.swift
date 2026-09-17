import Combine
import CoreGraphics
import QuartzCore
import UIKit

enum HangingChainTuning {
    static let nodeCount = 18
    static let lengthFraction: CGFloat = 0.56
    /// Points per g. High enough to feel like metal, with substeps so constraints hold.
    static let pixelsPerG: CGFloat = 20000
    static let damping60: CGFloat = 0.988
    static let iterations = 12
    static let substeps = 3
    static let gravitySmoothing: CGFloat = 0.22
}

@MainActor
final class HangingChainSimulation: NSObject, ObservableObject {
    @Published private(set) var positions: [CGPoint] = []
    @Published private(set) var isUsingDeviceMotion = false

    var isDragging: Bool { rope.draggedIndex != nil }

    private var rope = VerletRope.hanging(
        count: HangingChainTuning.nodeCount,
        origin: .zero,
        restLength: 24,
        damping60: HangingChainTuning.damping60,
        iterations: HangingChainTuning.iterations
    )
    private let motion = DeviceMotionSource()
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var filteredGravity = CGVector(dx: 0, dy: HangingChainTuning.pixelsPerG)
    private var viewport: CGSize = .zero
    private var didLayout = false

    var anchor: CGPoint {
        CGPoint(x: viewport.width / 2, y: ViewSpaceMotion.windowSafeAreaTop() + 62)
    }

    func updateViewport(size: CGSize) {
        viewport = size
        let usable = max(size.height - anchor.y - 40, 120)
        let rest = (usable * HangingChainTuning.lengthFraction) / CGFloat(HangingChainTuning.nodeCount - 1)

        if !didLayout || rope.particles.isEmpty {
            rope = VerletRope.hanging(
                count: HangingChainTuning.nodeCount,
                origin: anchor,
                restLength: rest,
                damping60: HangingChainTuning.damping60,
                iterations: HangingChainTuning.iterations
            )
            didLayout = true
            positions = rope.positions
        } else {
            rope.restLength = rest
            rope.particles[0].position = anchor
            rope.particles[0].oldPosition = anchor
            rope.particles[0].pinned = true
        }
    }

    func start() {
        motion.start()
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 48, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        motion.stop()
    }

    func beginDrag(at point: CGPoint) {
        rope.beginDrag(at: point)
    }

    func moveDrag(to point: CGPoint) {
        rope.moveDrag(to: point)
    }

    func endDrag() {
        rope.endDrag()
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        guard didLayout, viewport.width > 1 else { return }

        let dt: CGFloat
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(link.timestamp - lastTimestamp), 1.0 / 30.0)
            lastTimestamp = link.timestamp
        }

        let hardware = motion.isUsingHardware
        if hardware != isUsingDeviceMotion {
            isUsingDeviceMotion = hardware
        }

        let mapped = ViewSpaceMotion.acceleration(
            motion.acceleration,
            interface: ViewSpaceMotion.currentInterfaceOrientation()
        )
        let target = CGVector(
            dx: mapped.dx * HangingChainTuning.pixelsPerG,
            dy: mapped.dy * HangingChainTuning.pixelsPerG
        )
        let blend = HangingChainTuning.gravitySmoothing
        filteredGravity = CGVector(
            dx: filteredGravity.dx + (target.dx - filteredGravity.dx) * blend,
            dy: filteredGravity.dy + (target.dy - filteredGravity.dy) * blend
        )

        let steps = HangingChainTuning.substeps
        let subdt = dt / CGFloat(steps)
        let pin = anchor
        for _ in 0..<steps {
            rope.integrate(gravity: filteredGravity, dt: subdt)
            rope.solveConstraints(anchor: pin)
        }
        positions = rope.positions
    }
}
