//
//  ExampleViewController.swift
//  LiquidGlass
//
//  Created by kaixin.lian on 2025/06/18.
//

#if DEBUG
import UIKit

/// Example view controller demonstrating UIKit integration
public class ExampleViewController: UIViewController {

    private let gradientLayer = CAGradientLayer()
    private var animationTimer: Timer?

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupGradientBackground()
        setupUI()
        startGradientAnimation()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func setupGradientBackground() {
        gradientLayer.colors = [
            UIColor.blue.cgColor,
            UIColor.purple.cgColor,
            UIColor.systemPink.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupUI() {
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Liquid Glass UIKit"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Glass button 1 - using extension
        let glassButton1 = UIButton(type: .system)
        glassButton1.setTitle("Glass Button (Extension)", for: .normal)
        glassButton1.setTitleColor(.white, for: .normal)
        glassButton1.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        glassButton1.translatesAutoresizingMaskIntoConstraints = false
        glassButton1.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        view.addSubview(glassButton1)

        // Add glass background using extension
        glassButton1.addLiquidGlassBackground(
            cornerRadius: 25,
            updateMode: .continuous(interval: 0.2),
            blurScale: 0.5,
            tintColor: .gray.withAlphaComponent(0.2)
        )

        // Glass button 2 - using direct LiquidGlassUIView
        let glassContainer = UIView()
        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glassContainer)

        let glassView = LiquidGlassUIView(
            cornerRadius: 30,
            updateMode: .continuous(interval: 0.2),
            blurScale: 0.5,
            tintColor: .gray.withAlphaComponent(0.2)
        )
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.addSubview(glassView)

        let glassButton2 = UIButton(type: .system)
        glassButton2.setTitle("Glass Button (Direct)", for: .normal)
        glassButton2.setTitleColor(.white, for: .normal)
        glassButton2.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        glassButton2.translatesAutoresizingMaskIntoConstraints = false
        glassButton2.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        glassContainer.addSubview(glassButton2)

        // Glass label with manual update mode
        let glassLabel = UILabel()
        glassLabel.text = "Manual Update Glass"
        glassLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        glassLabel.textColor = .white
        glassLabel.textAlignment = .center
        glassLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glassLabel)

        let manualGlass = glassLabel.addLiquidGlassBackground(
            cornerRadius: 20,
            updateMode: .continuous(interval: 0.2), // Changed to continuous for consistency
            blurScale: 0.5,
            tintColor: .gray.withAlphaComponent(0.2)
        )

        // Tap gesture to manually update
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(manualUpdate))
        glassLabel.addGestureRecognizer(tapGesture)
        glassLabel.isUserInteractionEnabled = true

        // Store reference for manual updates
        glassLabel.tag = 999

        // Setup constraints
        NSLayoutConstraint.activate([
            // Title
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            // Glass Button 1
            glassButton1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glassButton1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 80),
            glassButton1.widthAnchor.constraint(equalToConstant: 280),
            glassButton1.heightAnchor.constraint(equalToConstant: 50),

            // Glass Container
            glassContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glassContainer.topAnchor.constraint(equalTo: glassButton1.bottomAnchor, constant: 40),
            glassContainer.widthAnchor.constraint(equalToConstant: 280),
            glassContainer.heightAnchor.constraint(equalToConstant: 60),

            // Glass View inside container
            glassView.topAnchor.constraint(equalTo: glassContainer.topAnchor),
            glassView.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: glassContainer.trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: glassContainer.bottomAnchor),

            // Glass Button 2 inside container
            glassButton2.centerXAnchor.constraint(equalTo: glassContainer.centerXAnchor),
            glassButton2.centerYAnchor.constraint(equalTo: glassContainer.centerYAnchor),

            // Manual Glass Label
            glassLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glassLabel.topAnchor.constraint(equalTo: glassContainer.bottomAnchor, constant: 40),
            glassLabel.widthAnchor.constraint(equalToConstant: 200),
            glassLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func startGradientAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                UIView.animate(withDuration: 5.0, delay: 0, options: [.curveLinear]) {
                    // Toggle between two gradient states to match SwiftUI
                    let colors1 = [
                        UIColor.blue.cgColor,
                        UIColor.purple.cgColor,
                        UIColor.systemPink.cgColor
                    ]
                    let colors2 = [
                        UIColor.systemPink.cgColor,
                        UIColor.purple.cgColor,
                        UIColor.blue.cgColor
                    ]
                    // Use forced cast with optional chaining
                    let currentFirstColor = self.gradientLayer.colors?.first as! CGColor?
                    self.gradientLayer.colors = (currentFirstColor == colors1.first) ? colors2 : colors1
                    self.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
                    self.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common) // Ensure timer runs on main thread
    }

    @objc private func buttonTapped() {
        let alert = UIAlertController(title: "Button Tapped", message: "Liquid Glass button works!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func manualUpdate() {
        if let label = view.viewWithTag(999) as? UILabel {
            label.liquidGlassBackground?.invalidateBackground()
            // Visual feedback
            UIView.animate(withDuration: 0.1, animations: {
                label.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    label.transform = .identity
                }
            }
        }
    }
}
#endif
