import Metal
import MetalKit
import SwiftUI
import UIKit

struct LabUniforms {
    var time: Float = 0
    var aspect: Float = 1
    var touchX: Float = 0.5
    var touchY: Float = 0.5
    var tiltX: Float = 0
    var tiltY: Float = 0
    var pop: Float = 0
    var p0: Float = 0
    var p1: Float = 0
    var p2: Float = 0
    var p3: Float = 0
    var b0x: Float = 0.35
    var b0y: Float = 0.45
    var b0r: Float = 0.16
    var b1x: Float = 0.62
    var b1y: Float = 0.52
    var b1r: Float = 0.13
    var b2x: Float = 0.48
    var b2y: Float = 0.62
    var b2r: Float = 0.11
    var b3x: Float = 0.55
    var b3y: Float = 0.38
    var b3r: Float = 0.09
    var pad: Float = 0
}

/// Fullscreen triangle + named Metal fragment shader. Falls back to a solid color if Metal is missing.
struct MetalLabView: UIViewRepresentable {
    var fragmentName: String
    var uniforms: LabUniforms
    var fallback: Color = LabPalette.paper
    var isActive: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(fragmentName: fragmentName, fallback: UIColor(fallback))
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.configure(view: view)
        context.coordinator.uniforms = uniforms
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.uniforms = uniforms
        uiView.isPaused = !isActive
        uiView.enableSetNeedsDisplay = !isActive
        if isActive {
            uiView.preferredFramesPerSecond = LabCadence.metalFPS
        } else {
            uiView.setNeedsDisplay()
        }
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var uniforms = LabUniforms()
        private let fragmentName: String
        private let fallback: UIColor
        private var device: MTLDevice?
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var failed = false

        init(fragmentName: String, fallback: UIColor) {
            self.fragmentName = fragmentName
            self.fallback = fallback
        }

        func configure(view: MTKView) {
            guard let device = MTLCreateSystemDefaultDevice() else {
                failed = true
                view.device = nil
                view.clearColor = MTLClearColor(red: 0.957, green: 0.949, blue: 0.929, alpha: 1)
                view.isPaused = true
                view.backgroundColor = fallback
                return
            }
            self.device = device
            view.device = device
            view.delegate = self
            view.framebufferOnly = true
            view.isOpaque = true
            view.enableSetNeedsDisplay = false
            view.isPaused = false
            view.preferredFramesPerSecond = LabCadence.metalFPS
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColorMake(0.957, 0.949, 0.929, 1)
            queue = device.makeCommandQueue()
            buildPipeline(view: view)
        }

        private func buildPipeline(view: MTKView) {
            guard let device, let library = device.makeDefaultLibrary() else {
                failed = true
                return
            }
            guard let vertex = library.makeFunction(name: "labVertex"),
                  let fragment = library.makeFunction(name: fragmentName) else {
                failed = true
                return
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertex
            desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
            do {
                pipeline = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                failed = true
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard !failed,
                  let pipeline,
                  let queue,
                  let drawable = view.currentDrawable,
                  let pass = view.currentRenderPassDescriptor else { return }
            var uniforms = self.uniforms
            let width = max(view.drawableSize.width, 1)
            let height = max(view.drawableSize.height, 1)
            uniforms.aspect = Float(width / height)
            guard let command = queue.makeCommandBuffer(),
                  let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LabUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            command.present(drawable)
            command.commit()
        }
    }
}
