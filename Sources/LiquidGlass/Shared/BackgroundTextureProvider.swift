import UIKit
import SwiftUI
import Metal
import MetalKit
import MetalPerformanceShaders

/// Describes how often the background snapshot should be refreshed.
public enum SnapshotUpdateMode {
    /// Captures every *interval* seconds (optimized default: ~20 fps)
    case continuous(interval: TimeInterval = 1.0 / 20.0)
    /// Captures exactly once and re‑uses the texture forever.
    case once
    /// Captures only when you call `invalidate()` (the lightest option)
    case manual
}

@MainActor
public final class BackgroundTextureProvider {
    
    // MARK: - Configuration
    public var updateMode: SnapshotUpdateMode = .continuous() {
        didSet { scheduleUpdateLoop() }
    }
    
    public var blurRadius: Float = 0 {
        didSet {
            if abs(oldValue - blurRadius) > 0.5 {
                invalidate()
            }
        }
    }
    
    public var didUpdateTexture: (() -> Void)?
    
    // MARK: - Dependencies
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let capturer: HierarchySnapshotCapturer
    
    // MARK: - State
    private weak var targetView: UIView?
    private var timer: Timer?
    private var isCapturing = false
    
    private var sourceTexture: MTLTexture?
    private var blurredTexture: MTLTexture?
    private var lastTextureSize: CGSize = .zero
    
    private var cachedTexture: MTLTexture? {
        didSet { didUpdateTexture?() }
    }
    
    // MARK: - Init
    init(device: MTLDevice, capturer: HierarchySnapshotCapturer = HierarchySnapshotCapturer()) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.capturer = capturer
    }
    
    // MARK: - Public API
    
    public func currentTexture(for view: UIView) -> MTLTexture? {
        // Если view изменилась, сбрасываем цель
        if targetView !== view {
            targetView = view
            invalidate()
            scheduleUpdateLoop()
        }
        
        if cachedTexture == nil {
            refreshTexture()
        }
        
        return cachedTexture
    }
    
    public func invalidate() {
        cachedTexture = nil
    }
    
    // MARK: - Private Logic
    
    private func scheduleUpdateLoop() {
        timer?.invalidate()
        timer = nil
        
        switch updateMode {
        case .continuous(let interval):
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshTexture()
                }
            }
        case .once:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshTexture()
            }
        case .manual:
            break
        }
    }
    
    private func refreshTexture() {
        guard let view = targetView, !isCapturing else { return }
        
        isCapturing = true
        defer { isCapturing = false }
        
        guard let cgImage = capturer.captureSnapshot(for: view) else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        let currentSize = CGSize(width: width, height: height)
        
        let needsRecreate = sourceTexture == nil || lastTextureSize != currentSize
        
        if needsRecreate {
            sourceTexture = createTexture(width: width, height: height)
            blurredTexture = createTexture(width: width, height: height)
            lastTextureSize = currentSize
        }
        
        guard let source = sourceTexture else { return }
        
        updateTextureBytes(texture: source, from: cgImage)
        
        if blurRadius <= 0 {
            self.cachedTexture = source
            return
        }
        
        guard let blurred = blurredTexture,
              let buffer = commandQueue.makeCommandBuffer() else {
            self.cachedTexture = source
            return
        }
        
        let effectiveBlurRadius = blurRadius * Float(capturer.captureScale / UIScreen.main.scale)
        
        let gaussianBlur = MPSImageGaussianBlur(device: device, sigma: effectiveBlurRadius)
        gaussianBlur.edgeMode = .clamp
        gaussianBlur.encode(
            commandBuffer: buffer,
            sourceTexture: source,
            destinationTexture: blurred
        )
        
        buffer.commit()
        
        self.cachedTexture = blurred
    }
    
    // MARK: - Helpers
    
    private func createTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        #if targetEnvironment(simulator)
            descriptor.storageMode = .shared
        #else
            descriptor.storageMode = .shared
        #endif
        
        return device.makeTexture(descriptor: descriptor)
    }
    
    private func updateTextureBytes(texture: MTLTexture, from image: CGImage) {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              ) else { return }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return }
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bytesPerRow)
    }
}

#if DEBUG
import SwiftUI
import Metal

@available(iOS 17.0, *)
#Preview("Optimized Provider Test") {
    OptimizedProviderDebugView()
}

@available(iOS 17.0, *)
struct OptimizedProviderDebugView: View {
    @State private var debugImage: UIImage?
    @State private var updateCount = 0
    @State private var isAnimating = false
    @State private var fps: Double = 0
    @State private var lastUpdateTime: Date?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Optimized Provider Test")
                .font(.headline)
            
            ZStack {
                LinearGradient(
                    colors: [.purple, .blue, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Circle()
                    .fill(Color.orange)
                    .frame(width: 60, height: 60)
                    .offset(x: isAnimating ? 60 : -60)
                    .blur(radius: 2)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                
                Text("LIVE\nTEXTURE")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                ProviderIntegrationAgent(
                    debugImage: $debugImage,
                    updateCount: $updateCount,
                    fps: $fps,
                    lastUpdateTime: $lastUpdateTime
                )
                .frame(width: 140, height: 140)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.green, lineWidth: 3))
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear { isAnimating = true }
            
            Divider()
            
            VStack(spacing: 10) {
                Text("Captured Texture")
                    .font(.caption.bold())
                
                if let debugImage {
                    Image(uiImage: debugImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.blue, lineWidth: 2))
                } else {
                    ContentUnavailableView("No Texture", systemImage: "photo")
                        .frame(height: 140)
                }
                
                HStack(spacing: 20) {
                    VStack {
                        Text("Updates")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(updateCount)")
                            .font(.title3.monospacedDigit())
                    }
                    
                    VStack {
                        Text("FPS")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", fps))
                            .font(.title3.monospacedDigit())
                    }
                }
            }
        }
        .padding()
    }
}

struct ProviderIntegrationAgent: UIViewRepresentable {
    @Binding var debugImage: UIImage?
    @Binding var updateCount: Int
    @Binding var fps: Double
    @Binding var lastUpdateTime: Date?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            context.coordinator.startProvider(for: view)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator {
        var parent: ProviderIntegrationAgent
        var provider: BackgroundTextureProvider?
        
        init(parent: ProviderIntegrationAgent) {
            self.parent = parent
        }
        
        @MainActor
        func startProvider(for view: UIView) {
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("❌ Metal not supported")
                return
            }
            
            let provider = BackgroundTextureProvider(device: device)
            provider.updateMode = .continuous(interval: 1.0 / 120.0) // 20 FPS
            provider.blurRadius = 1.0
            
            provider.didUpdateTexture = { [weak self] in
                guard let self = self else { return }
                
                Task { @MainActor in
                    let now = Date()
                    if let last = self.parent.lastUpdateTime {
                        let delta = now.timeIntervalSince(last)
                        self.parent.fps = 1.0 / delta
                    }
                    self.parent.lastUpdateTime = now
                    
                    if let texture = provider.currentTexture(for: view) {
                        self.parent.debugImage = self.textureToImage(texture)
                        self.parent.updateCount += 1
                    }
                }
            }
            
            self.provider = provider
            
            _ = provider.currentTexture(for: view)
        }
        
        private func textureToImage(_ texture: MTLTexture) -> UIImage? {
            let width = texture.width
            let height = texture.height
            let rowBytes = width * 4
            var data = [UInt8](repeating: 0, count: width * height * 4)
            
            texture.getBytes(&data, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            
            guard let ctx = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
                  let cgImage = ctx.makeImage() else { return nil }
            
            return UIImage(cgImage: cgImage)
        }
    }
}
#endif
