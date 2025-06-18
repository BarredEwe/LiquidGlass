//
//  LiquidGlassUIView.swift
//  LiquidGlass
//
//  Created by kaixin.lian on 2025/06/18.
//

import UIKit
import MetalKit
import simd

/// UIKit version of LiquidGlass - a UIView that applies liquid glass effect to its background
@MainActor
public class LiquidGlassUIView: UIView {

    // MARK: - Public Properties

    /// Corner radius for the glass effect
    public var cornerRadius: CGFloat = 20 {
        didSet {
            layer.cornerRadius = cornerRadius * 0.32
            setNeedsDisplay()
        }
    }

    /// Background snapshot update mode
    public var updateMode: SnapshotUpdateMode = .continuous() {
        didSet {
            backgroundProvider?.updateMode = updateMode
        }
    }

    /// Blur intensity (0.0 = no blur, 1.0 = maximum blur)
    public var blurScale: CGFloat = 0.5 {
        didSet {
            metalView.setNeedsDisplay()
        }
    }

    /// Glass tint color for the effect (renamed to avoid UIView.tintColor conflict)
    public var glassTintColor: UIColor = .gray.withAlphaComponent(0.2) {
        didSet {
            metalView.setNeedsDisplay()
        }
    }

    // MARK: - Private Properties

    private var metalView: MTKView!
    private var coordinator: MetalCoordinator!
    private var backgroundProvider: BackgroundTextureProvider?

    // MARK: - Initialization

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    public convenience init(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) {
        self.init(frame: .zero)
        self.cornerRadius = cornerRadius
        self.updateMode = updateMode
        self.blurScale = blurScale
        self.glassTintColor = tintColor

        layer.cornerRadius = cornerRadius * 0.32
        backgroundProvider?.updateMode = updateMode
    }

    // MARK: - Public Methods

    /// Manually invalidate the background texture (useful when updateMode is .manual)
    public func invalidateBackground() {
        backgroundProvider?.invalidate()
        metalView.setNeedsDisplay()
    }

    // MARK: - Private Methods

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerRadius = cornerRadius * 0.32

        setupMetalView()
    }

    private func setupMetalView() {
        metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isOpaque = false
        metalView.layer.isOpaque = false
        metalView.backgroundColor = .clear
        metalView.enableSetNeedsDisplay = true
        metalView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(metalView)
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        guard let device = metalView.device else {
            print("Failed to create Metal device")
            return
        }

        coordinator = MetalCoordinator(
            device: device,
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: glassTintColor
        )

        metalView.delegate = coordinator

        backgroundProvider = BackgroundTextureProvider(device: device)
        backgroundProvider?.updateMode = updateMode
        backgroundProvider?.didUpdateTexture = { [weak self] in
            DispatchQueue.main.async {
                self?.metalView.setNeedsDisplay()
            }
        }

        coordinator.backgroundProvider = backgroundProvider
        coordinator.parentView = self
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.setNeedsDisplay()
    }
}

// MARK: - Metal Coordinator

private class MetalCoordinator: NSObject, MTKViewDelegate {
    weak var parentView: LiquidGlassUIView?
    var backgroundProvider: BackgroundTextureProvider?

    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var device: MTLDevice!
    var startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()

    var cornerRadius: CGFloat
    var updateMode: SnapshotUpdateMode
    var blurScale: CGFloat
    var tintColor: UIColor

    init(device: MTLDevice, cornerRadius: CGFloat, updateMode: SnapshotUpdateMode, blurScale: CGFloat, tintColor: UIColor) {
        self.device = device
        self.cornerRadius = cornerRadius
        self.updateMode = updateMode
        self.blurScale = blurScale
        self.tintColor = tintColor

        super.init()

        setupMetal()
    }

    private func setupMetal() {
        commandQueue = device.makeCommandQueue()

        let bundle = Bundle.module
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            print("Failed to create Metal library")
            return
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexPassthrough")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "liquidGlassFragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create render pipeline state: \(error)")
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let parentView = parentView else { return }

        // Update properties from parent view
        cornerRadius = parentView.cornerRadius
        blurScale = parentView.blurScale
        tintColor = parentView.glassTintColor

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
            cornerRadius: Float(cornerRadius * 0.32), // Align with SwiftUI
            tintColor: SIMD3<Float>(
                Float(tintColor.cgColor.components?[safe: 0] ?? 0),
                Float(tintColor.cgColor.components?[safe: 1] ?? 0),
                Float(tintColor.cgColor.components?[safe: 2] ?? 0)
            ),
            tintAlpha: Float(tintColor.cgColor.components?.last ?? 0)
        )

        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        let sampler = device.makeSamplerState(descriptor: MTLSamplerDescriptor())!

        let snapshotTexture = backgroundProvider?.currentTexture(for: parentView)
        encoder.setFragmentTexture(snapshotTexture, index: 0)
        encoder.setFragmentSamplerState(sampler, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
