import Combine
import QuartzCore
import UIKit

/// CADisplayLink on the main run loop. Experiments assign `onTick` and call start/stop.
@MainActor
final class FrameTicker: NSObject, ObservableObject {
    var onTick: ((CGFloat) -> Void)?

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(handle(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 48, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func handle(_ link: CADisplayLink) {
        let dt: CGFloat
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(link.timestamp - lastTimestamp), 1.0 / 30.0)
            lastTimestamp = link.timestamp
        }
        onTick?(dt)
    }
}
