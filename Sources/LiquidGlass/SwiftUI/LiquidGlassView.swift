import SwiftUI

public struct LiquidGlassView: View {
    let cornerRadius: CGFloat
    let updateMode: SnapshotUpdateMode
    let blurScale: CGFloat
    let tintColor: CGColor

    public init(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) {
        self.cornerRadius = cornerRadius
        self.updateMode = updateMode
        self.blurScale = blurScale
        self.tintColor = tintColor.cgColor
    }

    public var body: some View {
        MetalShaderView(cornerRadius: cornerRadius, blurScale: blurScale, tintColor: tintColor, updateMode: updateMode)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius * 0.32))
    }
}
