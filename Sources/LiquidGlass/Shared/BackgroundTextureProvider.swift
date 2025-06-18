import UIKit
import SwiftUI
import Metal
import MetalKit

/// Describes how often the background snapshot should be refreshed.
public enum SnapshotUpdateMode {
    /// Captures every *interval* seconds (default ≈ 5 fps).
    case continuous(interval: TimeInterval = 0.2)
    /// Captures exactly once and re‑uses the texture forever.
    case once
    /// Captures only when you call `invalidate()` (the lightest option).
    case manual
}

/// Captures a Metal texture of whatever is **behind** the LiquidGlass view so
/// that the fragment shader can refract it. After this rewrite you *never*
/// need to think about screenshots – just add `.liquidGlassBackground()`.
@MainActor
public final class BackgroundTextureProvider {
    public var updateMode: SnapshotUpdateMode = .continuous() {
        didSet { resetTimer() }
    }
    public var didUpdateTexture: (() -> Void)?
    
    private weak var timerTarget: UIView?
    private let device: MTLDevice
    private let textureLoader: MTKTextureLoader
    private var lastCaptureTime: CFAbsoluteTime = 0
    private var timer: Timer?
    private var isCapturingSnapshot = false
    private var cachedTexture: MTLTexture? {
        didSet {
            didUpdateTexture?()
        }
    }
    
    public init(device: MTLDevice) {
        self.device = device
        self.textureLoader = MTKTextureLoader(device: device)
        resetTimer()
    }

    /// Use when `updateMode == .manual` and the layout behind the glass changed.
    public func invalidate() {
        cachedTexture = nil
        lastCaptureTime = 0
    }

    /// Returns the latest texture (captures one if needed).
    public func currentTexture(for view: UIView) -> MTLTexture? {
        if timerTarget !== view { timerTarget = view }

        if let cached = cachedTexture { return cached }
        cachedTexture = makeSnapshotTexture(from: view)
        lastCaptureTime = CFAbsoluteTimeGetCurrent()
        return cachedTexture
    }

    // MARK: – Private

    private func resetTimer() {
        timer?.invalidate()
        switch updateMode {
        case .continuous(let interval):
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self]  _ in
                Task { @MainActor in
                    guard let self, let view = self.timerTarget else { return }
                    self.cachedTexture = self.makeSnapshotTexture(from: view)
                    self.lastCaptureTime = CFAbsoluteTimeGetCurrent()
                }
            }
            RunLoop.main.add(timer!, forMode: .common)
        case .once, .manual:
            timer = nil
        }
    }
    
    @MainActor private func makeSnapshotTexture(from view: UIView) -> MTLTexture? {
        if isCapturingSnapshot { return cachedTexture }
        isCapturingSnapshot = true
        defer { isCapturingSnapshot = false }
        
        if let cg = snapshotBehind(view) {
            return try? textureLoader.newTexture(cgImage: cg, options: [.SRGB: false, .generateMipmaps: true])
        }
        return nil
    }
    
    @MainActor
    private func snapshotBehind(_ glass: UIView) -> CGImage? {
        guard let window = glass.window else { return nil }

        let rect = glass.convert(glass.bounds, to: window)
        let img = UIGraphicsImageRenderer(size: rect.size).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: -rect.origin.x, y: -rect.origin.y)
            cg.setFillColor((window.backgroundColor ?? .systemBackground).cgColor)
            cg.fill(window.bounds)

            var layers: [CALayer] = []
            var layer: CALayer = glass.layer
            while layer !== window.layer, let parent = layer.superlayer {
                layers.append(layer)
                layer = parent
            }
            layers.reverse()

            var parentLayer = window.layer
            for wanted in layers {
                guard let idx = parentLayer.sublayers?.firstIndex(of: wanted) else { break }

                for i in 0..<idx {
                    guard let sib = parentLayer.sublayers?[i] else { continue }

                    if let frameInWindow = sib.delegate as? UIView {
                        let f = frameInWindow.convert(frameInWindow.bounds, to: window)
                        cg.saveGState()
                        cg.translateBy(x: f.origin.x, y: f.origin.y)
                        sib.render(in: cg)
                        cg.restoreGState()
                    } else {
                        sib.render(in: cg)
                    }
                }

                if let wantedView = wanted.delegate as? UIView {
                    cg.translateBy(x: wantedView.frame.origin.x, y: wantedView.frame.origin.y)
                }
                parentLayer = wanted
            }
        }
        return img.cgImage
    }
}
