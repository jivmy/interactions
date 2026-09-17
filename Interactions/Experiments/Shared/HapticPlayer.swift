import CoreHaptics
import UIKit

/// Refined Core Haptics. Transient clicks for detents, two-stage clunks for
/// drops, a real continuous player for melt — not a spray of UIImpact.
final class HapticPlayer {
    private var engine: CHHapticEngine?
    private var supportsCore = false
    private var meltPlayer: CHHapticAdvancedPatternPlayer?

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let select = UISelectionFeedbackGenerator()
    private let notify = UINotificationFeedbackGenerator()

    init() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        rigid.prepare()
        soft.prepare()
        select.prepare()
        notify.prepare()
        startEngine()
    }

    func startEngine() {
        supportsCore = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsCore else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { [weak self] _ in
                try? self?.engine?.start()
            }
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            supportsCore = false
            engine = nil
        }
    }

    func selection() {
        select.selectionChanged()
        select.prepare()
    }

    func click(intensity: Float = 0.48, sharpness: Float = 0.88) {
        if !playTransient(intensity: intensity, sharpness: sharpness) {
            select.selectionChanged()
            select.prepare()
        }
    }

    func tick() {
        if !playTransient(intensity: 0.36, sharpness: 0.96) {
            light.impactOccurred(intensity: 0.42)
            light.prepare()
        }
    }

    /// Regular safe-dial notch. Decade marks land a hair heavier.
    func detent(isDecade: Bool = false, isDrop: Bool = false) {
        if isDrop {
            clunk()
            return
        }
        click(intensity: isDecade ? 0.62 : 0.42, sharpness: isDecade ? 0.72 : 0.92)
    }

    func clunk() {
        if supportsCore, let engine {
            let hit = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
                ],
                relativeTime: 0
            )
            let settle = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08)
                ],
                relativeTime: 0.02,
                duration: 0.12
            )
            play(events: [hit, settle], engine: engine)
        } else {
            heavy.impactOccurred(intensity: 1.0)
            heavy.prepare()
        }
    }

    func thud() {
        if !playTransient(intensity: 0.78, sharpness: 0.28) {
            medium.impactOccurred(intensity: 0.82)
            medium.prepare()
        }
    }

    func zipperTick(at tooth: Int, of total: Int) {
        let t = Float(tooth) / Float(max(total - 1, 1))
        let intensity = 0.30 + t * 0.18
        if tooth == 0 || tooth == total - 1 {
            thud()
        } else {
            click(intensity: intensity, sharpness: 0.94)
        }
    }

    func scrape() {
        if supportsCore, let engine {
            var events: [CHHapticEvent] = []
            var t: TimeInterval = 0
            for i in 0..<7 {
                let fade = 1 - Float(i) / 8
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float.random(in: 0.14...0.32) * fade),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float.random(in: 0.35...0.85))
                        ],
                        relativeTime: t
                    )
                )
                t += TimeInterval.random(in: 0.016...0.032)
            }
            play(events: events, engine: engine)
        } else {
            light.impactOccurred(intensity: 0.28)
        }
    }

    func ignite() {
        if supportsCore, let engine {
            let strike = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.68)
                ],
                relativeTime: 0
            )
            let rumble = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.32),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
                ],
                relativeTime: 0.018,
                duration: 0.42
            )
            play(events: [strike, rumble], engine: engine)
        } else {
            rigid.impactOccurred(intensity: 1.0)
            notify.notificationOccurred(.success)
        }
    }

    func success() {
        if supportsCore, let engine {
            let bright = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.82),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ],
                relativeTime: 0
            )
            let bloom = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
                ],
                relativeTime: 0.015,
                duration: 0.16
            )
            play(events: [bright, bloom], engine: engine)
        } else {
            notify.notificationOccurred(.success)
        }
    }

    func failure() {
        if supportsCore, let engine {
            let dull = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.40),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
                ],
                relativeTime: 0
            )
            play(events: [dull], engine: engine)
        } else {
            soft.impactOccurred(intensity: 0.45)
        }
    }

    func pop() {
        if supportsCore, let engine {
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.68),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.16),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08)
                    ],
                    relativeTime: 0.01,
                    duration: 0.10
                )
            ]
            play(events: events, engine: engine)
        } else {
            light.impactOccurred(intensity: 0.72)
        }
    }

    func startMelt(intensity: Float) {
        stopMelt()
        guard supportsCore, let engine else {
            soft.impactOccurred(intensity: CGFloat(max(0.18, intensity)))
            return
        }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.08, min(intensity, 1))),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.10)
                ],
                relativeTime: 0,
                duration: 30
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            meltPlayer = player
        } catch {
            meltPlayer = nil
        }
    }

    func updateMelt(intensity: Float) {
        guard let meltPlayer else { return }
        let value = max(0.06, min(intensity * 0.55, 0.85))
        let param = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: value, relativeTime: 0)
        try? meltPlayer.sendParameters([param], atTime: CHHapticTimeImmediate)
    }

    func stopMelt() {
        try? meltPlayer?.stop(atTime: CHHapticTimeImmediate)
        meltPlayer = nil
    }

    @discardableResult
    private func playTransient(intensity: Float, sharpness: Float) -> Bool {
        guard supportsCore, let engine else { return false }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(intensity, 0), 1)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(sharpness, 0), 1))
            ],
            relativeTime: 0
        )
        play(events: [event], engine: engine)
        return true
    }

    private func play(events: [CHHapticEvent], engine: CHHapticEngine) {
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Keep the experiment running if a pattern fails to build.
        }
    }
}
