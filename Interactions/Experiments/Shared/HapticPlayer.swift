import CoreHaptics
import UIKit

/// Transient / continuous haptics with UIKit fallbacks. Silent on Simulator.
final class HapticPlayer {
    private var engine: CHHapticEngine?
    private var supportsCore = false
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let select = UISelectionFeedbackGenerator()

    init() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
        select.prepare()
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

    func click(intensity: Float = 0.55, sharpness: Float = 0.85) {
        if !playTransient(intensity: intensity, sharpness: sharpness) {
            select.selectionChanged()
            select.prepare()
        }
    }

    func tick() {
        if !playTransient(intensity: 0.42, sharpness: 0.95) {
            light.impactOccurred(intensity: 0.55)
            light.prepare()
        }
    }

    func clunk() {
        if !playTransient(intensity: 1.0, sharpness: 0.25) {
            heavy.impactOccurred(intensity: 1.0)
            heavy.prepare()
        }
    }

    func thud() {
        if !playTransient(intensity: 0.85, sharpness: 0.35) {
            medium.impactOccurred(intensity: 0.9)
            medium.prepare()
        }
    }

    func scrape() {
        if supportsCore, let engine {
            var events: [CHHapticEvent] = []
            var t: TimeInterval = 0
            for _ in 0..<5 {
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float.random(in: 0.18...0.38)),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float.random(in: 0.4...0.9))
                        ],
                        relativeTime: t
                    )
                )
                t += TimeInterval.random(in: 0.018...0.04)
            }
            play(events: events, engine: engine)
        } else {
            light.impactOccurred(intensity: 0.35)
        }
    }

    func ignite() {
        if supportsCore, let engine {
            let strike = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.95),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            )
            let rumble = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0.02,
                duration: 0.45
            )
            play(events: [strike, rumble], engine: engine)
        } else {
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    func meltRumble(intensity: Float) {
        if !playTransient(intensity: max(0.08, intensity * 0.45), sharpness: 0.12) {
            soft.impactOccurred(intensity: CGFloat(max(0.2, intensity)))
        }
    }

    func pop() {
        if supportsCore, let engine {
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0.01,
                    duration: 0.12
                )
            ]
            play(events: events, engine: engine)
        } else {
            light.impactOccurred(intensity: 0.8)
        }
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
