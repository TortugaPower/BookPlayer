//
//  ItemProgress.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ItemProgress: UIView {
    private let pieOutline = CAShapeLayer()
    private let pieBackground = CAShapeLayer()
    private let pieSegment = CAShapeLayer()
    private let completionBackground = CAShapeLayer()
    private let completionCheckmark = CALayer()

    var pieColor = UIColor(hex: "8F8E94") {
        didSet {
            pieOutline.strokeColor = pieColor.withAlpha(newAlpha: 0.5).cgColor
            pieBackground.fillColor = pieColor.withAlpha(newAlpha: 0.1).cgColor
            pieSegment.fillColor = pieColor.withAlpha(newAlpha: 0.7).cgColor

            layer.setNeedsDisplay()
        }
    }

    var completionColor = UIColor.tintColor {
        didSet {
            completionBackground.fillColor = completionColor.cgColor

            layer.setNeedsDisplay()
        }
    }

    var value: Double = 0.0 {
        didSet {
            self.layer.setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    // swiftlint:disable:next function_body_length
    private func setup() {
        isOpaque = false
        backgroundColor = .clear

        // Setup layers
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        let diameter = min(width, height)
        let bounds = CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter)
        let scale = UIScreen.main.scale

        pieOutline.frame = bounds
        pieOutline.contentsScale = scale
        pieOutline.allowsEdgeAntialiasing = true
        pieOutline.backgroundColor = UIColor.clear.cgColor
        pieOutline.fillColor = UIColor.clear.cgColor
        pieOutline.strokeColor = pieColor.withAlpha(newAlpha: 0.5).cgColor
        pieOutline.lineWidth = 1.5

        layer.addSublayer(pieOutline)

        pieBackground.frame = bounds
        pieBackground.contentsScale = scale
        pieBackground.allowsEdgeAntialiasing = true
        pieBackground.backgroundColor = UIColor.clear.cgColor
        pieBackground.fillColor = pieColor.withAlpha(newAlpha: 0.1).cgColor
        pieBackground.strokeColor = UIColor.clear.cgColor
        pieBackground.lineWidth = 0

        layer.addSublayer(pieBackground)

        pieSegment.frame = bounds
        pieSegment.contentsScale = scale
        pieSegment.allowsEdgeAntialiasing = true
        pieSegment.backgroundColor = UIColor.clear.cgColor
        pieSegment.fillColor = pieColor.withAlpha(newAlpha: 0.7).cgColor
        pieSegment.strokeColor = UIColor.clear.cgColor
        pieSegment.lineWidth = 0

        layer.addSublayer(pieSegment)

        completionBackground.frame = bounds
        completionBackground.contentsScale = scale
        completionBackground.allowsEdgeAntialiasing = true
        completionBackground.backgroundColor = UIColor.clear.cgColor
        completionBackground.fillColor = completionColor.cgColor
        completionBackground.strokeColor = UIColor.clear.cgColor
        completionBackground.lineWidth = 0

        layer.addSublayer(completionBackground)

        let mask = CALayer()

        mask.frame = bounds
        mask.contents = #imageLiteral(resourceName: "completionIndicatorDone").cgImage
        mask.contentsGravity = kCAGravityResizeAspect

        completionCheckmark.frame = bounds
        completionCheckmark.mask = mask
        completionCheckmark.backgroundColor = UIColor.white.cgColor

        layer.addSublayer(completionCheckmark)
    }

    // swiftlint:disable:next function_body_length
    override func draw(_: CGRect) {
        let width = bounds.size.width
        let height = bounds.size.height
        let diameter = min(width, height)
        let center = CGPoint(x: width * 0.5, y: height * 0.5)
        let roundedValue = CGFloat(round(value * 1000) / 1000)

        if roundedValue == 0 {
            // Hide progress if none
            pieOutline.isHidden = true
            pieBackground.isHidden = true
            pieSegment.isHidden = true
            completionBackground.isHidden = true
            completionCheckmark.isHidden = true
        } else if roundedValue < 1.0 {
            // Show progress pie chart
            let lineWidth: CGFloat = 1.5
            var radius: CGFloat = diameter * 0.5 - lineWidth / 2

            pieOutline.isHidden = false
            pieBackground.isHidden = false
            pieSegment.isHidden = false
            completionBackground.isHidden = true
            completionCheckmark.isHidden = true

            pieOutline.path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath

            radius = diameter * 0.5 - lineWidth * 2

            pieBackground.path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath

            let path = UIBezierPath()

            path.move(to: center)
            path.addArc(
                withCenter: center,
                radius: radius,
                startAngle: -CGFloat.pi / 2,
                endAngle: min(1.0, max(0.0, roundedValue)) * CGFloat.pi * 2 - CGFloat.pi / 2,
                clockwise: true
            )
            path.close()

            pieSegment.path = path.cgPath
        } else {
            // Show completion stateggg
            pieOutline.isHidden = true
            pieBackground.isHidden = true
            pieSegment.isHidden = true
            completionBackground.isHidden = false
            completionCheckmark.isHidden = false

            completionBackground.path = UIBezierPath(
                arcCenter: center,
                radius: diameter * 0.5,
                startAngle: 0,
                endAngle: CGFloat.pi * 2,
                clockwise: true
            ).cgPath
        }
    }
}
