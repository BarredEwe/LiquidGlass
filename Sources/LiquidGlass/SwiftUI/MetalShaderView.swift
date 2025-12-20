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
        var samplerState: MTLSamplerState!
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
            
            let samplerDescriptor = MTLSamplerDescriptor()
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            samplerDescriptor.minFilter = .linear
            samplerDescriptor.magFilter = .linear
            samplerDescriptor.mipFilter = .linear
            samplerDescriptor.sAddressMode = .clampToEdge
            samplerDescriptor.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: samplerDescriptor)

            backgroundProvider = BackgroundTextureProvider(device: device)
            backgroundProvider.updateMode = updateMode
            
            backgroundProvider.didUpdateTexture = { [weak self] in
                DispatchQueue.main.async {
                    self?.mtkView?.setNeedsDisplay()
                }
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
                cornerRadius: Float(cornerRadius * view.contentScaleFactor),
                tintColor: SIMD3<Float>(Float(tintColor.components?[safe: 0] ?? 0), Float(tintColor.components?[safe: 1] ?? 0), Float(tintColor.components?[safe: 2] ?? 0)),
                tintAlpha: Float(tintColor.components?.last ?? 0)
            )
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

            backgroundProvider.blurRadius = Float(blurScale) * 30.0
            let snapshotTexture = backgroundProvider.currentTexture(for: mtkView!)
            encoder.setFragmentTexture(snapshotTexture, index: 0)
            encoder.setFragmentSamplerState(samplerState, index: 0)

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
import SwiftUI
import MetalKit

@available(iOS 17.0, *)
#Preview("Shader Live Debug") {
    ShaderLiveDebugView()
}

@available(iOS 17.0, *)
struct ShaderLiveDebugView: View {
    @State private var blur: CGFloat = 0.4
    @State private var radius: CGFloat = 30
    @State private var tint: Color = .white.opacity(0.1)
    
    @State private var animateBG = true
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [.black, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    
                    Circle().fill(.orange).frame(width: 100).blur(radius: 20)
                        .offset(x: animateBG ? 100 : -100, y: -50)
                    
                    Circle().fill(.cyan).frame(width: 80).blur(radius: 10)
                        .offset(x: animateBG ? -80 : 80, y: 80)
                    
                    VStack(spacing: 5) {
                        Text("LIQUID")
                            .font(.system(size: 80, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 2)
                        
                        Text("GLASS")
                            .font(.system(size: 80, weight: .black))
                            .foregroundStyle(.clear)
                            .overlay(
                                LinearGradient(colors: [.yellow, .red], startPoint: .top, endPoint: .bottom)
                                    .mask(Text("GLASS").font(.system(size: 80, weight: .black)))
                            )
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                        animateBG.toggle()
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 10) {
                    Text("Glass Card")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Button(action: {}) {
                        Text("Action")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(30)
                .frame(width: 250, height: 160)
                
                .liquidGlassBackground(
                    cornerRadius: radius,
                    updateMode: .continuous(),
                    blurScale: blur,
                    tintColor: UIColor(tint)
                )
                
                Spacer()
            }
        }
        .frame(height: 400)
        .clipped()
    }
}
#endif
