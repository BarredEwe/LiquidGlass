//
//  UIView+LiquidGlass.swift
//  LiquidGlass
//
//  Created by kaixin.lian on 2025/06/18.
//

import UIKit

public extension UIView {

    /// Add liquid glass background effect to any UIView
    /// - Parameters:
    ///   - cornerRadius: Corner radius for the glass effect
    ///   - updateMode: How often the background should be updated
    ///   - blurScale: Blur intensity (0.0 = no blur, 1.0 = maximum blur)
    ///   - tintColor: Tint color for the glass effect
    /// - Returns: The created LiquidGlassUIView for further customization
    @discardableResult
    func addLiquidGlassBackground(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(interval: 0.2),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) -> LiquidGlassUIView {
        let glassView = LiquidGlassUIView(
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: tintColor
        )

        glassView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(glassView, at: 0)

        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        return glassView
    }

    /// Add liquid glass background with custom frame
    /// - Parameters:
    ///   - frame: Frame for the glass background view
    ///   - cornerRadius: Corner radius for the glass effect
    ///   - updateMode: How often the background should be updated
    ///   - blurScale: Blur intensity (0.0 = no blur, 1.0 = maximum blur)
    ///   - tintColor: Tint color for the glass effect
    /// - Returns: The created LiquidGlassUIView for further customization
    @discardableResult
    func addLiquidGlassBackground(
        frame: CGRect,
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(interval: 0.2),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) -> LiquidGlassUIView {
        let glassView = LiquidGlassUIView(
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: tintColor
        )

        glassView.frame = frame
        insertSubview(glassView, at: 0)

        return glassView
    }

    /// Remove all liquid glass background views
    func removeLiquidGlassBackgrounds() {
        subviews.compactMap { $0 as? LiquidGlassUIView }.forEach { $0.removeFromSuperview() }
    }

    /// Get the first liquid glass background view
    var liquidGlassBackground: LiquidGlassUIView? {
        return subviews.first { $0 is LiquidGlassUIView } as? LiquidGlassUIView
    }

    /// Get all liquid glass background views
    var liquidGlassBackgrounds: [LiquidGlassUIView] {
        return subviews.compactMap { $0 as? LiquidGlassUIView }
    }
}
