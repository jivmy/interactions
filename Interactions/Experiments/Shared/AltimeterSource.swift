import Combine
import CoreMotion

/// Relative altitude in meters from `CMAltimeter`. Zeroed at `resetBaseline()`.
final class AltimeterSource: ObservableObject {
    @Published private(set) var relativeMeters: Double = 0
    @Published private(set) var isHardware = false
    @Published private(set) var unavailableReason: String?

    static var isSupported: Bool { CMAltimeter.isRelativeAltitudeAvailable() }

    private let altimeter = CMAltimeter()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.jimmy.interactions.altimeter"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var baseline: Double?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            unavailableReason = "No barometer"
            return
        }
        if #available(iOS 17.4, *) {
            switch CMAltimeter.authorizationStatus() {
            case .denied, .restricted:
                unavailableReason = "Motion permission denied"
                return
            default:
                break
            }
        }
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, error in
            guard let self else { return }
            if error != nil {
                DispatchQueue.main.async {
                    self.unavailableReason = "Altimeter unavailable"
                    self.isHardware = false
                }
                return
            }
            guard let data else { return }
            let meters = data.relativeAltitude.doubleValue
            DispatchQueue.main.async {
                if self.baseline == nil { self.baseline = meters }
                self.relativeMeters = meters - (self.baseline ?? meters)
                self.isHardware = true
                self.unavailableReason = nil
            }
        }
    }

    func resetBaseline() {
        baseline = nil
        relativeMeters = 0
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        started = false
    }
}
