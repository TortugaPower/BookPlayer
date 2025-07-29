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
    let view = UIView(frame: .zero)

    let emitter = CAEmitterLayer()

    emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2.0, y: 0)
    emitter.emitterShape = .line
    emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

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
    view.layer.addSublayer(emitter)

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
