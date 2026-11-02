//
//  ConfettiView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = EmitterView(frame: .zero)

    let emitter = view.emitter

    emitter.emitterShape = .line

    let confettis: [(color: UIColor, image: UIImage)] = [
      (UIColor(red: 0.95, green: 0.40, blue: 0.27, alpha: 1.0), UIImage(named: "confetti_paper")!),
      (UIColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1.0), UIImage(named: "confetti_hole")!),
      (UIColor(red: 0.48, green: 0.78, blue: 0.64, alpha: 1.0), UIImage(named: "confetti_paper")!),
      (UIColor(red: 0.30, green: 0.76, blue: 0.85, alpha: 1.0), UIImage(named: "confetti_squiggle")!),
      (UIColor(red: 0.58, green: 0.39, blue: 0.55, alpha: 1.0), UIImage(named: "confetti_star")!),
    ]

    var cells = [CAEmitterCell]()
    for confetti in confettis {
      cells.append(self.confettiWithColor(color: confetti.color, image: confetti.image))
    }

    emitter.emitterCells = cells

    return view
  }

  func confettiWithColor(color: UIColor, image: UIImage? = nil) -> CAEmitterCell {
    let confetti = CAEmitterCell()
    let intensity: Float = 1.0
    confetti.birthRate = 6.0 * intensity
    confetti.lifetime = 14.0 * intensity
    confetti.lifetimeRange = 0
    confetti.color = color.cgColor
    confetti.velocity = CGFloat(350.0 * intensity)
    confetti.velocityRange = CGFloat(80.0 * intensity)
    confetti.emissionLongitude = CGFloat(Double.pi)
    confetti.emissionRange = CGFloat(Double.pi)
    confetti.spin = CGFloat(3.5 * intensity)
    confetti.spinRange = CGFloat(4.0 * intensity)
    confetti.scaleRange = CGFloat(intensity)
    confetti.scaleSpeed = CGFloat(-0.1 * intensity)

    confetti.contents = image?.cgImage ?? UIImage(named: "confetti")!.cgImage
    return confetti
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Lays the emitter out from its own bounds rather than the screen's: they differ in Split View
/// and on iPhone Duo, and the bounds follow the window when it resizes
private final class EmitterView: UIView {
  let emitter = CAEmitterLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.addSublayer(emitter)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    /// A standalone layer animates property changes implicitly, which would slide the emitter
    /// in from its previous frame
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
    emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    CATransaction.commit()
  }
}
