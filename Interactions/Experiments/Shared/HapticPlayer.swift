import CoreHaptics
import UIKit

/// Refined Core Haptics. Transient clicks for detents, two-stage clunks for
/// drops, a real continuous player for melt — not a spray of UIImpact.
final class HapticPlayer {
    private var engine: CHHapticEngine?
    private var supportsCore = false
    private var meltPlayer: CHHapticAdvancedPatternPlayer?
    private var zipperPlayer: CHHapticAdvancedPatternPlayer?
    private var scrapePlayer: CHHapticAdvancedPatternPlayer?

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

    /// Regular safe-dial notch. Decades carry weight; the drop is a two-stage clunk.
    func detent(isDecade: Bool = false, isDrop: Bool = false) {
        if isDrop {
            clunk()
            return
        }
        if isDecade {
            decade()
        } else {
            click(intensity: 0.40, sharpness: 0.94)
        }
    }

    func decade() {
        if supportsCore, let engine {
            let hit = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.72),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.48)
                ],
                relativeTime: 0
            )
            let weight = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.26),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.16)
                ],
                relativeTime: 0.012,
                duration: 0.10
            )
            play(events: [hit, weight], engine: engine)
        } else {
            medium.impactOccurred(intensity: 0.72)
            medium.prepare()
        }
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

    func startZipper() {
        stopZipper()
        guard let player = makeContinuous(intensity: 0.11, sharpness: 0.88, duration: 60) else { return }
        zipperPlayer = player
    }

    func zipperTick(at tooth: Int, of total: Int) {
        let t = Float(tooth) / Float(max(total - 1, 1))
        if zipperPlayer == nil { startZipper() }
        send(to: zipperPlayer, intensity: 0.10 + t * 0.20, sharpness: 0.78 + t * 0.18)
        if tooth == 0 || tooth == total - 1 {
            thud()
        } else {
            click(intensity: 0.28 + t * 0.24, sharpness: 0.97)
        }
    }

    func stopZipper() {
        try? zipperPlayer?.stop(atTime: CHHapticTimeImmediate)
        zipperPlayer = nil
    }

    func startScrape() {
        stopScrape()
        guard let player = makeContinuous(intensity: 0.16, sharpness: 0.72, duration: 20) else {
            light.impactOccurred(intensity: 0.22)
            return
        }
        scrapePlayer = player
    }

    func updateScrape(speed: Float) {
        let n = min(max(speed / 2600, 0.08), 0.78)
        send(to: scrapePlayer, intensity: n, sharpness: 0.45 + n * 0.45)
    }

    func stopScrape() {
        try? scrapePlayer?.stop(atTime: CHHapticTimeImmediate)
        scrapePlayer = nil
    }

    func scrape() {
        if supportsCore, let engine {
            var events: [CHHapticEvent] = []
            var t: TimeInterval = 0
            for i in 0..<9 {
                let fade = 1 - Float(i) / 10
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float.random(in: 0.12...0.30) * fade),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float.random(in: 0.40...0.92))
                        ],
                        relativeTime: t
                    )
                )
                t += TimeInterval.random(in: 0.012...0.026)
            }
            let tail = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.14),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ],
                relativeTime: t,
                duration: 0.08
            )
            play(events: events + [tail], engine: engine)
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
        let i = max(0.08, min(intensity * 0.64, 0.90))
        let s = max(0.06, min(0.08 + intensity * 0.24, 0.36))
        send(to: meltPlayer, intensity: i, sharpness: s)
    }

    func stopMelt() {
        try? meltPlayer?.stop(atTime: CHHapticTimeImmediate)
        meltPlayer = nil
    }

    private func makeContinuous(intensity: Float, sharpness: Float, duration: TimeInterval) -> CHHapticAdvancedPatternPlayer? {
        guard supportsCore, let engine else { return nil }
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(intensity, 0.05), 1)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(sharpness, 0), 1))
                ],
                relativeTime: 0,
                duration: duration
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return player
        } catch {
            return nil
        }
    }

    private func send(to player: CHHapticAdvancedPatternPlayer?, intensity: Float, sharpness: Float) {
        guard let player else { return }
        let i = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: min(max(intensity, 0.05), 1), relativeTime: 0)
        let s = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: min(max(sharpness, 0), 1), relativeTime: 0)
        try? player.sendParameters([i, s], atTime: CHHapticTimeImmediate)
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
