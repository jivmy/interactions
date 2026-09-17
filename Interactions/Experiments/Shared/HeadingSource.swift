import Combine
import CoreLocation
import CoreMotion

/// True-north heading when Core Location allows it; magnetic north otherwise.
/// Simulator and denied-permission paths stay at 0 and report `isHardware == false`.
final class HeadingSource: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var degrees: Double = 0
    @Published private(set) var isTrueNorth = false
    @Published private(set) var isHardware = false

    private let location = CLLocationManager()
    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.jimmy.interactions.heading"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let lock = NSLock()
    private var motionDegrees: Double = 0
    private var motionLive = false

    func start() {
        location.delegate = self
        location.headingFilter = 0.5
        location.headingOrientation = .portrait
        location.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        if CLLocationManager.headingAvailable() {
            switch location.authorizationStatus {
            case .notDetermined:
                location.requestWhenInUseAuthorization()
            case .authorizedAlways, .authorizedWhenInUse:
                location.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    location.startUpdatingHeading()
                }
            default:
                break
            }
        }
        startMotion()
    }

    func stop() {
        location.stopUpdatingHeading()
        location.stopUpdatingLocation()
        motion.stopDeviceMotionUpdates()
        motion.stopMagnetometerUpdates()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0 { return }
        if newHeading.trueHeading >= 0 {
            publish(degrees: newHeading.trueHeading, trueNorth: true)
        } else {
            publish(degrees: newHeading.magneticHeading, trueNorth: false)
        }
    }

    private func startMotion() {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 30.0
            let frames: [CMAttitudeReferenceFrame] = [.xTrueNorthZVertical, .xMagneticNorthZVertical]
            for frame in frames where CMMotionManager.availableAttitudeReferenceFrames().contains(frame) {
                motion.startDeviceMotionUpdates(using: frame, to: queue) { [weak self] data, _ in
                    guard let self, let data else { return }
                    let heading = data.heading
                    if heading >= 0 {
                        self.lock.lock()
                        self.motionDegrees = heading
                        self.motionLive = true
                        self.lock.unlock()
                    }
                }
                return
            }
        }

        if motion.isMagnetometerAvailable {
            motion.magnetometerUpdateInterval = 1.0 / 30.0
            motion.startMagnetometerUpdates(to: queue) { [weak self] data, _ in
                guard let self, let data else { return }
                let angle = atan2(data.magneticField.x, data.magneticField.y) * 180 / .pi
                let degrees = (angle + 360).truncatingRemainder(dividingBy: 360)
                self.lock.lock()
                self.motionDegrees = degrees
                self.motionLive = true
                self.lock.unlock()
            }
        }
    }

    /// Called from the experiment tick when Core Location heading is absent.
    func pullMotionIfNeeded() {
        guard !isHardware else { return }
        lock.lock()
        let live = motionLive
        let value = motionDegrees
        lock.unlock()
        if live {
            degrees = value
            isTrueNorth = false
            isHardware = true
        }
    }

    private func publish(degrees: Double, trueNorth: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.degrees = degrees
            self?.isTrueNorth = trueNorth
            self?.isHardware = true
        }
    }
}
