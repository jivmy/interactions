import CoreMotion
import UIKit

/// Device-frame acceleration in g's (CoreMotion: +x right, +y toward the top of the phone, +z out).
struct DeviceAcceleration: Sendable {
    var x: Double
    var y: Double
    var z: Double

    /// Portrait-upright gravity: pull toward the bottom of the phone.
    static let hangingPortrait = DeviceAcceleration(x: 0, y: -1, z: 0)
}

/// Maps CoreMotion device-space acceleration into SwiftUI view space (+x right, +y down).
enum ViewSpaceMotion {
    static func acceleration(
        _ device: DeviceAcceleration,
        interface: UIInterfaceOrientation
    ) -> CGVector {
        switch interface {
        case .portraitUpsideDown:
            return CGVector(dx: -device.x, dy: device.y)
        case .landscapeLeft:
            return CGVector(dx: -device.y, dy: -device.x)
        case .landscapeRight:
            return CGVector(dx: device.y, dy: device.x)
        default:
            return CGVector(dx: device.x, dy: -device.y)
        }
    }

    @MainActor
    static func currentInterfaceOrientation() -> UIInterfaceOrientation {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return active.interfaceOrientation
        }
        return scenes.first?.interfaceOrientation ?? .portrait
    }

    @MainActor
    static func windowSafeAreaTop() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow
            ?? scenes.first?.keyWindow
            ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 54
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow) ?? windows.first
    }
}

/// Reads gravity + user acceleration from CoreMotion.
/// Simulator typically has no hardware; callers keep a portrait-down default.
final class DeviceMotionSource: @unchecked Sendable {
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.jimmy.interactions.motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let lock = NSLock()
    private var raw = DeviceAcceleration.hangingPortrait
    private var hardwareActive = false

    var isUsingHardware: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hardwareActive
    }

    var acceleration: DeviceAcceleration {
        lock.lock()
        defer { lock.unlock() }
        return raw
    }

    func start() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1.0 / 120.0
            manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let self, let motion else { return }
                self.publish(
                    gravity: motion.gravity,
                    user: motion.userAcceleration
                )
            }
            return
        }

        if manager.isAccelerometerAvailable {
            manager.accelerometerUpdateInterval = 1.0 / 120.0
            manager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                self.publish(
                    x: data.acceleration.x,
                    y: data.acceleration.y,
                    z: data.acceleration.z
                )
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        manager.stopAccelerometerUpdates()
        lock.lock()
        hardwareActive = false
        raw = .hangingPortrait
        lock.unlock()
    }

    deinit {
        manager.stopDeviceMotionUpdates()
        manager.stopAccelerometerUpdates()
    }

    private func publish(gravity: CMAcceleration, user: CMAcceleration) {
        // A wrist snap should read through the links, not just rest gravity.
        let boost = 1.55
        publish(
            x: gravity.x + user.x * boost,
            y: gravity.y + user.y * boost,
            z: gravity.z + user.z * boost
        )
    }

    private func publish(x: Double, y: Double, z: Double) {
        lock.lock()
        raw = DeviceAcceleration(x: x, y: y, z: z)
        hardwareActive = true
        lock.unlock()
    }
}
