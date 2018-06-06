//
//  ItemProgress.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ItemProgress: UIView {
    var value: Double = 0.0 {
        didSet {
            self.layer.setNeedsDisplay()
        }
    }

    var color = UIColor(hex: "8F8E94")
    var completionColor = UIColor.tintColor

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    private func setup() {
        self.isOpaque = false
        self.backgroundColor = .clear
    }

    // swiftlint:disable:next function_body_length
    override func draw(_ rect: CGRect) {
        self.layer.sublayers?.removeAll()

        let width = self.bounds.size.width
        let height = self.bounds.size.height
        let diameter = min(width, height)
        let bounds = CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter)
        let center = CGPoint(x: width * 0.5, y: height * 0.5)
        let scale = UIScreen.main.scale

        if self.value < 1.0 {
            let lineWidth: CGFloat = 1.5
            var radius: CGFloat = diameter * 0.5 - lineWidth / 2

            let outerCircleLayer = CAShapeLayer()

            outerCircleLayer.frame = bounds
            outerCircleLayer.contentsScale = scale
            outerCircleLayer.allowsEdgeAntialiasing = true
            outerCircleLayer.backgroundColor = UIColor.clear.cgColor
            outerCircleLayer.fillColor = UIColor.clear.cgColor
            outerCircleLayer.strokeColor = self.color.withAlpha(newAlpha: 0.5).cgColor
            outerCircleLayer.lineWidth = lineWidth

            outerCircleLayer.path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath

            self.layer.addSublayer(outerCircleLayer)

            let fillLayer = CAShapeLayer()

            fillLayer.frame = bounds
            fillLayer.contentsScale = scale
            fillLayer.allowsEdgeAntialiasing = true
            fillLayer.backgroundColor = UIColor.clear.cgColor
            fillLayer.fillColor = self.color.withAlpha(newAlpha: 0.1).cgColor
            fillLayer.strokeColor = UIColor.clear.cgColor
            fillLayer.lineWidth = 0

            radius = diameter * 0.5 - lineWidth * 2

            fillLayer.path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath

            self.layer.addSublayer(fillLayer)

            let pieLayer = CAShapeLayer()

            pieLayer.frame = bounds
            pieLayer.contentsScale = scale
            pieLayer.allowsEdgeAntialiasing = true
            pieLayer.backgroundColor = UIColor.clear.cgColor
            pieLayer.fillColor = self.color.withAlpha(newAlpha: 0.7).cgColor
            pieLayer.strokeColor = UIColor.clear.cgColor
            pieLayer.lineWidth = 0
            pieLayer.path = self.getSegmentPath(center, radius: radius, value: min(1.0, max(0.0, CGFloat(self.value))))

            self.layer.addSublayer(pieLayer)
        } else {
            let fillLayer = CAShapeLayer()

            fillLayer.frame = bounds
            fillLayer.contentsScale = scale
            fillLayer.allowsEdgeAntialiasing = true
            fillLayer.backgroundColor = UIColor.clear.cgColor
            fillLayer.fillColor = self.completionColor.cgColor
            fillLayer.strokeColor = UIColor.clear.cgColor
            fillLayer.lineWidth = 0

            fillLayer.path = UIBezierPath(
                arcCenter: center,
                radius: diameter * 0.5,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath

            self.layer.addSublayer(fillLayer)

            let mask = CALayer()

            mask.frame = bounds
            mask.contents = #imageLiteral(resourceName: "completionIndicatorDone").cgImage
            mask.contentsGravity = kCAGravityResizeAspect

            let checkmark = CALayer()

            checkmark.frame = bounds
            checkmark.mask = mask
            checkmark.backgroundColor = UIColor.white.cgColor

            self.layer.addSublayer(checkmark)
        }
    }

    private func getSegmentPath(_ center: CGPoint = CGPoint(x: 0.5, y: 0.5), radius: CGFloat = 1.0, value: CGFloat = 0.0) -> CGPath {
        let path = UIBezierPath()

        path.move(to: center)
        path.addArc(
            withCenter: center,
            radius: radius,
            startAngle: -CGFloat.pi / 2,
            endAngle: value * CGFloat.pi * 2 - CGFloat.pi / 2,
            clockwise: true
        )
        path.close()

        return path.cgPath
    }
}
