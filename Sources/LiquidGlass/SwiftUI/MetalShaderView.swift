import SwiftUI
import UIKit
import MetalKit
import simd

struct Uniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var blurScale: Float
    var boxSize: SIMD2<Float>
    var cornerRadius: Float
    var tintColor: SIMD3<Float>
    var tintAlpha: Float
}

struct MetalShaderView: UIViewRepresentable {
    let cornerRadius: CGFloat
    let blurScale: CGFloat
    var tintColor: CGColor
    let updateMode: SnapshotUpdateMode
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isOpaque = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        view.enableSetNeedsDisplay = true
        view.delegate = context.coordinator
        
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.mtkView = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(cornerRadius: cornerRadius, updateMode: updateMode, blurScale: blurScale, tintColor: tintColor)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        weak var mtkView: MTKView?
        
        var pipelineState: MTLRenderPipelineState!
        var commandQueue: MTLCommandQueue!
        var device: MTLDevice!
        var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

        var backgroundProvider: BackgroundTextureProvider!
        
        var cornerRadius: CGFloat
        var updateMode: SnapshotUpdateMode
        var blurScale: CGFloat
        var tintColor: CGColor
    
        @MainActor
        init(cornerRadius: CGFloat, updateMode: SnapshotUpdateMode, blurScale: CGFloat, tintColor: CGColor) {
            self.cornerRadius = cornerRadius
            self.updateMode = updateMode
            self.blurScale = blurScale
            self.tintColor = tintColor
            super.init()

            device = MTLCreateSystemDefaultDevice()
            commandQueue = device.makeCommandQueue()

            let library = try! device.makeDefaultLibrary(bundle: .module)

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexPassthrough")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "liquidGlassFragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

            backgroundProvider = BackgroundTextureProvider(device: device)
            backgroundProvider.updateMode = updateMode
            
            backgroundProvider.didUpdateTexture = { [weak self] in
                DispatchQueue.main.async { self?.mtkView?.setNeedsDisplay() }
            }
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }
            
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store

            let commandBuffer = commandQueue.makeCommandBuffer()!
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!

            encoder.setRenderPipelineState(pipelineState)

            var uniforms = Uniforms(
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                time: Float(CFAbsoluteTimeGetCurrent() - startTime),
                blurScale: Float(blurScale),
                boxSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                cornerRadius: Float(cornerRadius),
                tintColor: SIMD3<Float>(Float(tintColor.components?[safe: 0] ?? 0), Float(tintColor.components?[safe: 1] ?? 0), Float(tintColor.components?[safe: 2] ?? 0)),
                tintAlpha: Float(tintColor.components?.last ?? 0)
            )
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

            let sampler = device.makeSamplerState(descriptor: MTLSamplerDescriptor())!

            let snapshotTexture = backgroundProvider.currentTexture(for: mtkView!)
            encoder.setFragmentTexture(snapshotTexture, index: 0)

            encoder.setFragmentSamplerState(sampler, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if DEBUG
struct AnimatedGradientBackground: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(gradient: Gradient(colors: [.blue, .purple, .pink]),
                       startPoint: animate ? .topLeading : .bottomTrailing,
                       endPoint: animate ? .bottomTrailing : .topLeading)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(Animation.linear(duration: 5).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
    }
}

#Preview {
    ZStack {
        AnimatedGradientBackground()
        
        VStack(spacing: 20) {
            Text("Liquid Glass Button")
                .font(.title)
                .foregroundColor(.white)
            
            Button("Click Me") {
                print("Tapped")
            }
            .font(.headline)
            .padding()
            .liquidGlassBackground(cornerRadius: 60)
        }
    }
}
#endif
