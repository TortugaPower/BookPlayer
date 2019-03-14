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
}
