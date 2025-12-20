import UIKit
import QuartzCore

class HierarchySnapshotCapturer {
    
    @MainActor
    lazy var captureScale: CGFloat = UIScreen.main.scale * 0.8
    
    private var cachedFormat: UIGraphicsImageRendererFormat?
    private var lastRectSize: CGSize = .zero
    
    @MainActor
    func captureSnapshot(for glassView: UIView) -> CGImage? {
        var sourceView = glassView.superview
        while let parent = sourceView?.superview {
            sourceView = parent
        }
        guard let targetView = sourceView else { return nil }
        
        let rectInTarget = glassView.convert(glassView.bounds, to: targetView)
        
        let width = Int(rectInTarget.width * captureScale)
        let height = Int(rectInTarget.height * captureScale)
        
        if width < 1 || height < 1 { return nil }
        
        if cachedFormat == nil || lastRectSize != rectInTarget.size {
            let format = UIGraphicsImageRendererFormat()
            format.scale = captureScale
            format.opaque = false
            format.preferredRange = .standard
            cachedFormat = format
            lastRectSize = rectInTarget.size
        }
        
        guard let format = cachedFormat else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: rectInTarget.size, format: format)
        
        let image = renderer.image { ctx in
            ctx.cgContext.translateBy(x: -rectInTarget.origin.x, y: -rectInTarget.origin.y)
            
            let originalAlpha = glassView.layer.opacity
            glassView.layer.opacity = 0.0
            
            targetView.layer.render(in: ctx.cgContext)
            
            glassView.layer.opacity = originalAlpha
        }
        
        return image.cgImage
    }
}


#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
#Preview("Real Usage Test") {
    RealUsageTestView()
}

@available(iOS 18.0, *)
struct RealUsageTestView: View {
    @State private var capturedImage: UIImage?
    @State private var captureTime: TimeInterval = 0
    @State private var frameCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Real Usage Performance Test")
                .font(.headline)
            
            ZStack {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .red, .orange, .yellow,
                        .purple, .blue, .cyan,
                        .indigo, .green, .mint
                    ]
                )
                
                GlassTestCard(
                    capturedImage: $capturedImage,
                    captureTime: $captureTime,
                    frameCount: $frameCount
                )
            }
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            Divider()
            
            VStack(spacing: 10) {
                Text("Captured Background Texture")
                    .font(.caption.bold())
                
                if let capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue, lineWidth: 2)
                        )
                } else {
                    ContentUnavailableView("No Texture", systemImage: "photo")
                        .frame(height: 100)
                }
                
                HStack(spacing: 30) {
                    VStack {
                        Text("Capture Time")
                            .font(.caption2)
                        Text(String(format: "%.1f ms", captureTime * 1000))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(captureTime < 0.005 ? .green : .orange)
                    }
                    
                    VStack {
                        Text("Frames")
                            .font(.caption2)
                        Text("\(frameCount)")
                            .font(.title3.monospacedDigit())
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Glass Test Card

@available(iOS 18.0, *)
struct GlassTestCard: View {
    @Binding var capturedImage: UIImage?
    @Binding var captureTime: TimeInterval
    @Binding var frameCount: Int
    
    var body: some View {
        GlassCaptureView(
            capturedImage: $capturedImage,
            captureTime: $captureTime,
            frameCount: $frameCount
        )
        .frame(width: 180, height: 100)
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 2)
                
                VStack(spacing: 8) {
                    Text("Glass Card")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Frame: \(frameCount)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Capture View

struct GlassCaptureView: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var captureTime: TimeInterval
    @Binding var frameCount: Int
    
    func makeUIView(context: Context) -> CaptureTargetView {
        let view = CaptureTargetView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                context.coordinator.capture(view: view)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CaptureTargetView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator {
        let parent: GlassCaptureView
        let capturer = HierarchySnapshotCapturer()
        
        init(parent: GlassCaptureView) {
            self.parent = parent
        }
        
        @MainActor
        func capture(view: UIView) {
            guard view.window != nil, view.superview != nil else {
                print("⚠️ View not in hierarchy")
                return
            }
            
            let start = CFAbsoluteTimeGetCurrent()
            
            if let cgImage = capturer.captureSnapshot(for: view) {
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                
                Task { @MainActor in
                    parent.capturedImage = UIImage(cgImage: cgImage)
                    parent.captureTime = elapsed
                    parent.frameCount += 1
                }
            } else {
                print("❌ captureSnapshot returned nil")
            }
        }
    }
}

class CaptureTargetView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
