import Combine
import QuartzCore
import UIKit

/// Shared display / publish cadence. Physics still steps on the tick; Low Power drops the ceiling.
enum LabCadence {
    static var displayRange: CAFrameRateRange {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        }
        return CAFrameRateRange(minimum: 48, maximum: 120, preferred: 120)
    }

    static var publishInterval: CGFloat {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30.0 : 1.0 / 60.0
    }

    static var metalFPS: Int {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? 60 : 120
    }

    static func apply(_ link: CADisplayLink) {
        link.preferredFrameRateRange = displayRange
    }
}

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
        LabCadence.apply(link)
        link.add(to: .main, forMode: .common)
        displayLink = link
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    func stop() {
        NotificationCenter.default.removeObserver(self, name: .NSProcessInfoPowerStateDidChange, object: nil)
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func powerChanged() {
        if let displayLink { LabCadence.apply(displayLink) }
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
