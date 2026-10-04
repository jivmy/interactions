import Metal
import MetalKit
import QuartzCore
import SwiftUI

/// GPU uniforms. Layout must match CandleShaders.metal.
struct CandleUniforms: Sendable {
    var time: Float = 0
    var aspect: Float = 1
    var power: Float = 0.55
    var pad: Float = 0
}

/// Fullscreen triangle + candle fragment. If Metal is missing the field stays empty.
struct CandleMetalView: UIViewRepresentable {
    var power: Float

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        applyField(view)
        applyCadence(view)
        context.coordinator.power = power
        context.coordinator.attach(view)
        return view
    }

    @MainActor
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.power = power
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

    final class Coordinator: NSObject, MTKViewDelegate {
        private let lock = NSLock()
        private var latestPower: Float = 0.55
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private let start = CACurrentMediaTime()

        var power: Float {
            get {
                lock.lock()
                defer { lock.unlock() }
                return latestPower
            }
            set {
                lock.lock()
                latestPower = newValue
                lock.unlock()
            }
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
                  let vertex = library.makeFunction(name: "candleVertex"),
                  let fragment = library.makeFunction(name: "candleFragment") else { return }
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

            var uniforms = CandleUniforms()
            let width = max(view.drawableSize.width, 1)
            let height = max(view.drawableSize.height, 1)
            uniforms.time = Float(CACurrentMediaTime() - start)
            uniforms.aspect = Float(width / height)
            uniforms.power = power

            guard let command = queue.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CandleUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.present(drawable)
            command.commit()
        }
    }
}
