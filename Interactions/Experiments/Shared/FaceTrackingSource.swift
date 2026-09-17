import ARKit
import Combine
import UIKit

/// TrueDepth face tracking. Publishes a view-space head offset in roughly -1...1.
/// Simulator and non-TrueDepth phones stay at zero with `isSupported == false`.
final class FaceTrackingSource: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var offset = CGSize.zero
    @Published private(set) var isTracking = false
    @Published private(set) var isSupported = false

    private let session = ARSession()
    private var running = false

    override init() {
        super.init()
        isSupported = ARFaceTrackingConfiguration.isSupported
    }

    func start() {
        isSupported = ARFaceTrackingConfiguration.isSupported
        guard isSupported, !running else { return }
        running = true
        session.delegate = self
        let config = ARFaceTrackingConfiguration()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        guard running else { return }
        running = false
        session.pause()
        isTracking = false
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        let position = face.transform.columns.3
        let look = face.lookAtPoint
        let x = CGFloat(position.x) * 3.2 + CGFloat(look.x) * 0.55
        let y = CGFloat(-position.y) * 3.2 + CGFloat(-look.y) * 0.55
        let next = CGSize(width: min(max(x, -1.4), 1.4), height: min(max(y, -1.4), 1.4))
        let tracked = face.isTracked
        DispatchQueue.main.async { [weak self] in
            self?.offset = next
            self?.isTracking = tracked
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isTracking = false
            self?.running = false
        }
    }
}
