import Metal
import MetalKit
import QuartzCore
import SwiftUI

/// GPU uniforms. Layout must match FireShaders.metal.
struct FireUniforms: Sendable {
    var time: Float = 0
    var aspect: Float = 1
    var width: Float = 1
    var height: Float = 1
    var intensity: Float = 0.62
    var touchX: Float = 0.5
    var touchY: Float = 0.28
    var prevX: Float = 0.5
    var prevY: Float = 0.28
    var touching: Float = 0
    var tiltX: Float = 0
    var tiltY: Float = 0
    var spin: Float = 0
    var style: Float = 0
    var p0: Float = 0
    var p1: Float = 0
}

struct FirePoint: Sendable {
    var x: Float = 0
    var y: Float = 0
    var age: Float = 1
    var strength: Float = 0
}

/// Physics ticks with the display. Reduce Motion does not freeze fire.
@MainActor
final class FireLinkClock: NSObject {
    var onTick: ((CGFloat) -> Void)?
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    func start() {
        guard displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
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

    deinit {
        displayLink?.invalidate()
    }

    @objc private func powerChanged() {
        if let displayLink { DisplayCadence.apply(displayLink) }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt: CGFloat
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            dt = 1.0 / 60.0
        } else {
            dt = min(CGFloat(link.timestamp - lastTimestamp), 1.0 / 30.0)
            lastTimestamp = link.timestamp
        }
        onTick?(dt)
    }
}

enum FireUV {
    static func point(_ point: CGPoint, in size: CGSize) -> (x: Float, y: Float) {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        return (Float(point.x / w), Float(1 - point.y / h))
    }
}

/// Fullscreen triangle + named fragment. If Metal is missing the field stays empty — no vector fire.
struct FireMetalView: UIViewRepresentable {
    var fragmentName: String
    var uniforms: FireUniforms
    var points: [FirePoint] = []

    func makeCoordinator() -> Coordinator {
        Coordinator(fragmentName: fragmentName)
    }

    @MainActor
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        applyField(view)
        applyCadence(view)
        context.coordinator.attach(view)
        context.coordinator.uniforms = uniforms
        context.coordinator.points = padded(points)
        return view
    }

    @MainActor
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.uniforms = uniforms
        context.coordinator.points = padded(points)
        applyCadence(uiView)
    }

    @MainActor
    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        uiView.isPaused = true
        uiView.delegate = nil
    }

    @MainActor
    private func applyField(_ view: MTKView) {
        let field = Stage.fieldWhite
        view.clearColor = MTLClearColor(red: field, green: field, blue: field, alpha: 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isOpaque = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.backgroundColor = UIColor(white: field, alpha: 1)
    }

    @MainActor
    private func applyCadence(_ view: MTKView) {
        view.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
    }

    private func padded(_ points: [FirePoint]) -> [FirePoint] {
        var padded = Array(points.prefix(24))
        if padded.count < 24 {
            padded.append(contentsOf: Array(repeating: FirePoint(), count: 24 - padded.count))
        }
        return padded
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private let fragmentName: String
        private let lock = NSLock()
        private var latestUniforms = FireUniforms()
        private var latestPoints: [FirePoint] = Array(repeating: FirePoint(), count: 24)
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private let start = CACurrentMediaTime()

        var uniforms: FireUniforms {
            get {
                lock.lock()
                defer { lock.unlock() }
                return latestUniforms
            }
            set {
                lock.lock()
                latestUniforms = newValue
                lock.unlock()
            }
        }

        var points: [FirePoint] {
            get {
                lock.lock()
                defer { lock.unlock() }
                return latestPoints
            }
            set {
                lock.lock()
                latestPoints = newValue
                lock.unlock()
            }
        }

        init(fragmentName: String) {
            self.fragmentName = fragmentName
        }

        @MainActor
        func attach(_ view: MTKView) {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            view.device = device
            view.delegate = self
            queue = device.makeCommandQueue()
            buildPipeline(device: device, pixelFormat: view.colorPixelFormat)
        }

        private func buildPipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) {
            guard let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "fireVertex"),
                  let fragment = library.makeFunction(name: fragmentName) else { return }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pipeline,
                  let queue,
                  let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor else { return }

            var uniforms = self.uniforms
            var points = self.points
            let width = max(view.drawableSize.width, 1)
            let height = max(view.drawableSize.height, 1)
            uniforms.time = Float(CACurrentMediaTime() - start)
            uniforms.aspect = Float(width / height)
            uniforms.width = Float(width)
            uniforms.height = Float(height)

            guard let command = queue.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<FireUniforms>.stride, index: 0)
            points.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                encoder.setFragmentBytes(base, length: MemoryLayout<FirePoint>.stride * buffer.count, index: 1)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.present(drawable)
            command.commit()
        }
    }
}
