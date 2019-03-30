//
//  setAnchorPoint.swift
//  BookPlayer
//
//  Created by Florian Pichler on 23.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIView {
    func setAnchorPoint(anchorPoint: CGPoint) {
        var newPoint = CGPoint(x: self.bounds.size.width * anchorPoint.x, y: self.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: self.bounds.size.width * self.layer.anchorPoint.x, y: self.bounds.size.height * self.layer.anchorPoint.y)

        newPoint = newPoint.applying(self.transform)
        oldPoint = oldPoint.applying(self.transform)

        var position: CGPoint = self.layer.position

        position.x -= oldPoint.x
        position.x += newPoint.x

        position.y -= oldPoint.y
        position.y += newPoint.y

        self.translatesAutoresizingMaskIntoConstraints = true
        self.layer.position = position
        self.layer.anchorPoint = anchorPoint
    }

    func addLayerMask(_ name: String, backgroundColor: UIColor) {
        guard let image = UIImage(named: name),
            let maskImage = image.cgImage else { return }

        let layer = CALayer()
        layer.frame = self.bounds
        layer.backgroundColor = backgroundColor.cgColor

        let mask = CALayer(layer: maskImage)
        mask.frame = self.bounds
        mask.contents = maskImage
        layer.mask = mask

        self.layer.addSublayer(layer)
    }

    // Confetti
    public func startConfetti() {
        let emitter = CAEmitterLayer()

        emitter.emitterPosition = CGPoint(x: self.frame.size.width / 2.0, y: 0)
        emitter.emitterShape = CAEmitterLayerEmitterShape.line
        emitter.emitterSize = CGSize(width: self.frame.size.width, height: 1)

        let confettis: [(color: UIColor, image: UIImage)] = [
            (UIColor(red: 0.95, green: 0.40, blue: 0.27, alpha: 1.0), UIImage(named: "confetti_paper")!),
            (UIColor(red: 1.00, green: 0.78, blue: 0.36, alpha: 1.0), UIImage(named: "confetti_hole")!),
            (UIColor(red: 0.48, green: 0.78, blue: 0.64, alpha: 1.0), UIImage(named: "confetti_paper")!),
            (UIColor(red: 0.30, green: 0.76, blue: 0.85, alpha: 1.0), UIImage(named: "confetti_squiggle")!),
            (UIColor(red: 0.58, green: 0.39, blue: 0.55, alpha: 1.0), UIImage(named: "confetti_star")!)
        ]

        var cells = [CAEmitterCell]()
        for confetti in confettis {
            cells.append(self.confettiWithColor(color: confetti.color, image: confetti.image))
        }

        emitter.emitterCells = cells
        self.layer.addSublayer(emitter)
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
}
