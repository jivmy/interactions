import Combine
import CoreGraphics
import QuartzCore
import UIKit

enum FireballsTuning {
    static let pixelWidth = 18
    static let pixelHeight = 26
    static let maxEmbers = 96
    static let maxDrips = 12
    static let maxVortex = 78
}

struct EmberParticle: Sendable {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var size: CGFloat
    var warmth: CGFloat
}

struct MoltenDrip: Sendable {
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var width: CGFloat
}

struct VortexSpark: Sendable {
    var angle: CGFloat
    var radius: CGFloat
    var spin: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var size: CGFloat
    var arm: Int
    var warmth: CGFloat
}

struct FireballsFrame: Sendable {
    var time: CGFloat
    var embers: [EmberParticle]
    var drips: [MoltenDrip]
    var pixels: [UInt8]
    var pixelWidth: Int
    var pixelHeight: Int
    var vortex: [VortexSpark]
}

/// Eight hearths share one clock. Firepower is read live from the slider.
@MainActor
final class FireballsSimulation: NSObject, ObservableObject {
    @Published var firepower: CGFloat = 0.62
    @Published private(set) var frame: FireballsFrame

    let pixelWidth = FireballsTuning.pixelWidth
    let pixelHeight = FireballsTuning.pixelHeight

    private var time: CGFloat = 0
    private var embers: [EmberParticle] = []
    private var drips: [MoltenDrip] = []
    private var pixels: [UInt8]
    private var vortex: [VortexSpark] = []
    private var rng = FireRNG(seed: 0xF1_5E_B0_11)
    private var emberCarry: CGFloat = 0
    private var dripCarry: CGFloat = 0
    private var vortexCarry: CGFloat = 0
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override init() {
        let count = FireballsTuning.pixelWidth * FireballsTuning.pixelHeight
        pixels = Array(repeating: 0, count: count)
        frame = FireballsFrame(
            time: 0,
            embers: [],
            drips: [],
            pixels: Array(repeating: 0, count: count),
            pixelWidth: FireballsTuning.pixelWidth,
            pixelHeight: FireballsTuning.pixelHeight,
            vortex: []
        )
        super.init()
    }

    func start() {
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
        let power = max(0, min(1, firepower))
        stepPixels(power: power)
        stepEmbers(dt: dt, power: power)
        stepDrips(dt: dt, power: power)
        stepVortex(dt: dt, power: power)
        frame = FireballsFrame(
            time: time,
            embers: embers,
            drips: drips,
            pixels: pixels,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            vortex: vortex
        )
    }

    private func stepPixels(power: CGFloat) {
        let width = pixelWidth
        let height = pixelHeight
        var next = pixels
        let coolLo = mix(14, 2.2, power)
        let coolHi = mix(22, 6.5, power)
        for y in 0..<(height - 1) {
            for x in 0..<width {
                let wander = Int(rng.unit() * 3) - 1
                let sourceX = min(max(x + wander, 0), width - 1)
                let below = pixels[(y + 1) * width + sourceX]
                let cool = UInt8(min(255, mix(coolLo, coolHi, rng.unit())))
                next[y * width + x] = below > cool ? below - cool : 0
            }
        }

        let base = mix(18, 236, power)
        for x in 0..<width {
            let heat = UInt8(min(255, max(0, base + rng.unit() * mix(10, 28, power))))
            next[(height - 1) * width + x] = heat
            if height >= 2, power > 0.55, rng.unit() < power * 0.55 {
                next[(height - 2) * width + x] = UInt8(min(255, Int(heat) - 18))
            }
        }
        if power < 0.04 {
            for x in 0..<width {
                next[(height - 1) * width + x] = UInt8(mix(8, 22, rng.unit()))
            }
        }
        pixels = next
    }

    private func stepEmbers(dt: CGFloat, power: CGFloat) {
        let target = Int(mix(3, CGFloat(FireballsTuning.maxEmbers), power))
        emberCarry += dt * mix(6, 78, power)
        while emberCarry >= 1, embers.count < FireballsTuning.maxEmbers {
            emberCarry -= 1
            embers.append(spawnEmber(power: power))
        }
        if embers.count > target {
            embers.removeFirst(embers.count - target)
        }

        let lift = mix(0.55, 1.85, power)
        var kept: [EmberParticle] = []
        kept.reserveCapacity(embers.count)
        for var ember in embers {
            ember.x += ember.vx * dt
            ember.y += ember.vy * dt * lift
            ember.vx += (rng.unit() - 0.5) * dt * 1.8
            ember.vy += dt * mix(0.15, 0.55, power)
            ember.life -= dt / ember.maxLife
            if ember.life > 0, ember.y < 1.35 {
                kept.append(ember)
            }
        }
        embers = kept
    }

    private func spawnEmber(power: CGFloat) -> EmberParticle {
        let maxLife = mix(0.35, 1.15, power) * mix(0.7, 1.2, rng.unit())
        return EmberParticle(
            x: (rng.unit() - 0.5) * mix(0.18, 0.72, power),
            y: rng.unit() * 0.04,
            vx: (rng.unit() - 0.5) * mix(0.15, 0.85, power),
            vy: mix(0.35, 1.15, power) * mix(0.55, 1.2, rng.unit()),
            life: 1,
            maxLife: max(0.18, maxLife),
            size: mix(1.4, 4.8, power) * mix(0.7, 1.3, rng.unit()),
            warmth: rng.unit()
        )
    }

    private func stepDrips(dt: CGFloat, power: CGFloat) {
        let target = Int(mix(0, CGFloat(FireballsTuning.maxDrips), power * sqrt(max(power, 0))))
        dripCarry += dt * mix(0.15, 3.8, power)
        while dripCarry >= 1, drips.count < FireballsTuning.maxDrips {
            dripCarry -= 1
            drips.append(
                MoltenDrip(
                    x: (rng.unit() - 0.5) * mix(0.12, 0.48, power),
                    y: 0.02,
                    vy: mix(0.18, 0.85, power) * mix(0.7, 1.2, rng.unit()),
                    life: 1,
                    width: mix(3.2, 9.5, power) * mix(0.75, 1.2, rng.unit())
                )
            )
        }
        if drips.count > max(target, 0) {
            drips.removeFirst(drips.count - max(target, 0))
        }

        var kept: [MoltenDrip] = []
        for var drip in drips {
            drip.y += drip.vy * dt
            drip.vy += dt * mix(0.6, 1.6, power)
            drip.life -= dt * mix(0.55, 0.85, 1 - power)
            if drip.life > 0, drip.y < 1.1 {
                kept.append(drip)
            }
        }
        drips = kept
    }

    private func stepVortex(dt: CGFloat, power: CGFloat) {
        let target = Int(mix(8, CGFloat(FireballsTuning.maxVortex), power))
        vortexCarry += dt * mix(10, 64, power)
        while vortexCarry >= 1, vortex.count < FireballsTuning.maxVortex {
            vortexCarry -= 1
            let arm = Int(rng.unit() * 3)
            vortex.append(
                VortexSpark(
                    angle: (CGFloat(arm) / 3) * .pi * 2 + rng.unit() * 0.4,
                    radius: rng.unit() * 0.12,
                    spin: mix(1.6, 5.4, power) * mix(0.75, 1.25, rng.unit()),
                    life: 1,
                    maxLife: mix(0.45, 1.4, power),
                    size: mix(1.6, 4.6, power) * mix(0.7, 1.25, rng.unit()),
                    arm: arm,
                    warmth: rng.unit()
                )
            )
        }
        if vortex.count > target {
            vortex.removeFirst(vortex.count - target)
        }

        var kept: [VortexSpark] = []
        for var spark in vortex {
            spark.angle += spark.spin * dt
            spark.radius += dt * mix(0.18, 0.72, power)
            spark.life -= dt / spark.maxLife
            if spark.life > 0, spark.radius < 1.15 {
                kept.append(spark)
            }
        }
        vortex = kept
    }

    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

private struct FireRNG: Sendable {
    var state: UInt32

    mutating func unit() -> CGFloat {
        state = state &* 1_664_525 &+ 1_013_904_223
        return CGFloat(state) / CGFloat(UInt32.max)
    }
}
