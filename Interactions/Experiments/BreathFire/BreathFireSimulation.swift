import Combine
import CoreGraphics
import QuartzCore
import UIKit

enum BreathFireTuning {
    /// Full heat to cold coals if the breath stops.
    static let fadeSeconds: CGFloat = 60
    /// A clear blow reaches full in about a second and a half.
    static let buildPerSecond: CGFloat = 0.85
    static let maxSparks = 42
}

struct BreathSpark: Sendable {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var size: CGFloat
    var warmth: CGFloat
}

struct BreathFireFrame: Sendable {
    var time: CGFloat
    var heat: CGFloat
    var blow: CGFloat
    var sparks: [BreathSpark]
    var listening: Bool
    var denied: Bool
}

/// One hearth. Breath raises heat; silence spends it in a one-minute fade from full.
@MainActor
final class BreathFireSimulation: NSObject, ObservableObject {
    @Published private(set) var frame: BreathFireFrame

    private let microphone = MicrophoneSource()
    private var time: CGFloat = 0
    private var heat: CGFloat = 0
    private var blow: CGFloat = 0
    private var sparks: [BreathSpark] = []
    private var rng = BreathRNG(seed: 0xB1_0E_F1_5E)
    private var sparkCarry: CGFloat = 0
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override init() {
        frame = BreathFireFrame(time: 0, heat: 0, blow: 0, sparks: [], listening: false, denied: false)
        super.init()
    }

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
        step(dt: dt)
    }

    private func step(dt: CGFloat) {
        time += dt
        blow = blowStrength(microphone.level)
        if blow > 0 {
            heat = min(1, heat + blow * BreathFireTuning.buildPerSecond * dt)
        } else {
            heat = max(0, heat - dt / BreathFireTuning.fadeSeconds)
        }
        stepSparks(dt: dt)
        frame = BreathFireFrame(
            time: time,
            heat: heat,
            blow: blow,
            sparks: sparks,
            listening: microphone.isListening,
            denied: microphone.isDenied
        )
    }

    /// RMS above a quiet floor. Below that, the minute fade owns the heat.
    private func blowStrength(_ rms: CGFloat) -> CGFloat {
        let floor: CGFloat = 0.028
        let span: CGFloat = 0.11
        let excess = (rms - floor) / span
        return max(0, min(1, excess))
    }

    private func stepSparks(dt: CGFloat) {
        let target = Int(mix(0, CGFloat(BreathFireTuning.maxSparks), heat))
        sparkCarry += dt * mix(0, 36, heat)
        while sparkCarry >= 1, sparks.count < BreathFireTuning.maxSparks {
            sparkCarry -= 1
            sparks.append(spawnSpark())
        }
        if sparks.count > target {
            sparks.removeFirst(sparks.count - target)
        }

        var kept: [BreathSpark] = []
        kept.reserveCapacity(sparks.count)
        for var spark in sparks {
            spark.x += spark.vx * dt
            spark.y += spark.vy * dt
            spark.vx += (rng.unit() - 0.5) * dt * 1.4
            spark.vy += dt * mix(0.2, 0.7, heat)
            spark.life -= dt / spark.maxLife
            if spark.life > 0, spark.y < 1.2 {
                kept.append(spark)
            }
        }
        sparks = kept
    }

    private func spawnSpark() -> BreathSpark {
        BreathSpark(
            x: (rng.unit() - 0.5) * mix(0.12, 0.55, heat),
            y: rng.unit() * 0.05,
            vx: (rng.unit() - 0.5) * 0.55,
            vy: mix(0.25, 1.05, heat) * mix(0.6, 1.2, rng.unit()),
            life: 1,
            maxLife: mix(0.35, 1.05, heat),
            size: mix(1.6, 4.4, heat) * mix(0.7, 1.25, rng.unit()),
            warmth: rng.unit()
        )
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

private struct BreathRNG: Sendable {
    var state: UInt32

    mutating func unit() -> CGFloat {
        state = state &* 1_664_525 &+ 1_013_904_223
        return CGFloat(state) / CGFloat(UInt32.max)
    }
}
