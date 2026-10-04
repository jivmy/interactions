import Combine
import CoreGraphics
import QuartzCore
import UIKit

enum BreathFireTuning {
    /// Full heat to cold coals if the breath stops.
    static let fadeSeconds: CGFloat = 60
    /// A clear blow reaches full in about a second and a half.
    static let buildPerSecond: CGFloat = 0.85
}

struct BreathFireFrame: Sendable {
    var heat: CGFloat
    var listening: Bool
    var denied: Bool
}

/// One hearth. Breath raises heat; silence spends it in a one-minute fade from full.
@MainActor
final class BreathFireSimulation: NSObject, ObservableObject {
    @Published private(set) var frame = BreathFireFrame(heat: 0, listening: false, denied: false)

    private let microphone = MicrophoneSource()
    private var heat: CGFloat = 0
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        microphone.start()
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        DisplayCadence.apply(link)
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
        microphone.stop()
    }

    @objc private func powerChanged() {
        if let displayLink { DisplayCadence.apply(displayLink) }
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        let dt: CGFloat
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(link.timestamp - lastTimestamp), 1.0 / 30.0)
            lastTimestamp = link.timestamp
        }
        let blow = blowStrength(microphone.level)
        if blow > 0 {
            heat = min(1, heat + blow * BreathFireTuning.buildPerSecond * dt)
        } else {
            heat = max(0, heat - dt / BreathFireTuning.fadeSeconds)
        }
        frame = BreathFireFrame(heat: heat, listening: microphone.isListening, denied: microphone.isDenied)
    }

    private func blowStrength(_ rms: CGFloat) -> CGFloat {
        let floor: CGFloat = 0.028
        let span: CGFloat = 0.11
        return max(0, min(1, (rms - floor) / span))
    }
}
