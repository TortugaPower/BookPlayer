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
        var newPoint = CGPoint(x: bounds.size.width * anchorPoint.x, y: bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: bounds.size.width * layer.anchorPoint.x, y: bounds.size.height * layer.anchorPoint.y)

        newPoint = newPoint.applying(transform)
        oldPoint = oldPoint.applying(transform)

        var position: CGPoint = layer.position

        position.x -= oldPoint.x
        position.x += newPoint.x

        position.y -= oldPoint.y
        position.y += newPoint.y

        translatesAutoresizingMaskIntoConstraints = true
        layer.position = position
        layer.anchorPoint = anchorPoint
    }
}
