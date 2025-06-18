import SwiftUI

public struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let updateMode: SnapshotUpdateMode
    let blurScale: CGFloat
    let tintColor: UIColor
    
    @State var size: CGSize = .zero

    public func body(content: Content) -> some View {
        content
            .background(LiquidGlassView(cornerRadius: cornerRadius, updateMode: updateMode, blurScale: blurScale, tintColor: tintColor))
    }
}

public extension View {
    func liquidGlassBackground(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) -> some View {
        modifier(
            LiquidGlassModifier(cornerRadius: cornerRadius, updateMode: updateMode, blurScale: blurScale, tintColor: tintColor)
        )
    }
}
