//
//  ItemProgress.swift
//  BookPlayer
//
//  Created by Florian Pichler on 05.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

enum State {
    case normal
    case highlighted
}

struct PieColors {
    var backgroundColor: CGColor
    var fillColor: CGColor
    var borderColor: CGColor
}

class ItemProgress: UIView {
    private let pieOutline = CAShapeLayer()
    private let pieBackground = CAShapeLayer()
    private let pieSegment = CAShapeLayer()
    private let completionBackground = CAShapeLayer()
    private let completionCheckmark = CALayer()
    private var pieColors: PieColors?
    private var highlightedPieColors: PieColors?

    var state: State = .normal {
        didSet {
            self.applyColors()
        }
    }

    var completionColor = UIColor.tintColor {
        didSet {
            self.completionBackground.fillColor = self.completionColor.cgColor

            self.layer.setNeedsDisplay()
        }
    }

    var value: Double = 0.0 {
        didSet {
            self.layer.setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    // swiftlint:disable:next function_body_length
    private func setup() {
        self.isOpaque = false
        self.backgroundColor = .clear

        // Setup layers
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        let diameter = min(width, height)
        let bounds = CGRect(x: 0.0, y: 0.0, width: diameter, height: diameter)
        let scale = UIScreen.main.scale

        self.pieOutline.frame = bounds
        self.pieOutline.contentsScale = scale
        self.pieOutline.allowsEdgeAntialiasing = true
        self.pieOutline.backgroundColor = UIColor.clear.cgColor
        self.pieOutline.fillColor = UIColor.clear.cgColor
        self.pieOutline.lineWidth = 1.5

        self.layer.addSublayer(self.pieOutline)

        self.pieBackground.frame = bounds
        self.pieBackground.contentsScale = scale
        self.pieBackground.allowsEdgeAntialiasing = true
        self.pieBackground.backgroundColor = UIColor.clear.cgColor
        self.pieBackground.strokeColor = UIColor.clear.cgColor
        self.pieBackground.lineWidth = 0

        self.layer.addSublayer(self.pieBackground)

        self.pieSegment.frame = bounds
        self.pieSegment.contentsScale = scale
        self.pieSegment.allowsEdgeAntialiasing = true
        self.pieSegment.backgroundColor = UIColor.clear.cgColor
        self.pieSegment.strokeColor = UIColor.clear.cgColor
        self.pieSegment.lineWidth = 0

        self.layer.addSublayer(self.pieSegment)

        self.completionBackground.frame = bounds
        self.completionBackground.contentsScale = scale
        self.completionBackground.allowsEdgeAntialiasing = true
        self.completionBackground.backgroundColor = UIColor.clear.cgColor
        self.completionBackground.fillColor = self.completionColor.cgColor
        self.completionBackground.strokeColor = UIColor.clear.cgColor
        self.completionBackground.lineWidth = 0

        self.layer.addSublayer(self.completionBackground)

        let mask = CALayer()

        mask.frame = bounds
        mask.contents = #imageLiteral(resourceName: "completionIndicatorDone").cgImage
        mask.contentsGravity = CALayerContentsGravity.resizeAspect

        self.completionCheckmark.frame = bounds
        self.completionCheckmark.mask = mask
        self.completionCheckmark.backgroundColor = UIColor.white.cgColor

        self.layer.addSublayer(self.completionCheckmark)

        self.setUpTheming()
    }

    // swiftlint:disable:next function_body_length
    override func draw(_ rect: CGRect) {
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        let diameter = min(width, height)
        let center = CGPoint(x: width * 0.5, y: height * 0.5)
        let roundedValue = CGFloat(round(self.value * 1000) / 1000)

        if roundedValue == 0 {
            // Hide progress if none
            self.pieOutline.isHidden = true
            self.pieBackground.isHidden = true
            self.pieSegment.isHidden = true
            self.completionBackground.isHidden = true
            self.completionCheckmark.isHidden = true
        } else if roundedValue < 1.0 {
            // Show progress pie chart
            let lineWidth: CGFloat = 1.5
            var radius: CGFloat = diameter * 0.5 - lineWidth / 2

            self.pieOutline.isHidden = false
            self.pieBackground.isHidden = false
            self.pieSegment.isHidden = false
            self.completionBackground.isHidden = true
            self.completionCheckmark.isHidden = true

            self.pieOutline.path = UIBezierPath(arcCenter: center,
                                                radius: radius,
                                                startAngle: 0,
                                                endAngle: CGFloat.pi * 2,
                                                clockwise: true).cgPath

            radius = diameter * 0.5 - lineWidth * 2

            self.pieBackground.path = UIBezierPath(arcCenter: center,
                                                   radius: radius,
                                                   startAngle: 0,
                                                   endAngle: CGFloat.pi * 2,
                                                   clockwise: true).cgPath

            let path = UIBezierPath()

            path.move(to: center)
            path.addArc(withCenter: center,
                        radius: radius,
                        startAngle: -CGFloat.pi / 2,
                        endAngle: min(1.0, max(0.0, roundedValue)) * CGFloat.pi * 2 - CGFloat.pi / 2,
                        clockwise: true)
            path.close()

            self.pieSegment.path = path.cgPath
        } else {
            // Show completion stateggg
            self.pieOutline.isHidden = true
            self.pieBackground.isHidden = true
            self.pieSegment.isHidden = true
            self.completionBackground.isHidden = false
            self.completionCheckmark.isHidden = false

            self.completionBackground.path = UIBezierPath(arcCenter: center,
                                                          radius: diameter * 0.5,
                                                          startAngle: 0,
                                                          endAngle: CGFloat.pi * 2,
                                                          clockwise: true).cgPath
        }
    }

    func applyColors() {
        let colors = self.state == .normal ? self.pieColors : self.highlightedPieColors

        self.pieOutline.strokeColor = colors?.borderColor
        self.pieBackground.fillColor = colors?.backgroundColor
        self.pieSegment.fillColor = colors?.fillColor

        self.layer.setNeedsDisplay()
    }
}

extension ItemProgress: Themeable {
    func applyTheme(_ theme: Theme) {
        self.pieColors = PieColors(backgroundColor: theme.pieBackgroundColor.cgColor,
                                   fillColor: theme.pieFillColor.cgColor,
                                   borderColor: theme.pieBorderColor.cgColor)

        self.highlightedPieColors = PieColors(backgroundColor: theme.highlightedPieBackgroundColor.cgColor,
                                              fillColor: theme.highlightedPieFillColor.cgColor,
                                              borderColor: theme.highlightedPieBorderColor.cgColor)

        self.completionBackground.fillColor = theme.highlightColor.cgColor

        self.applyColors()
    }
}
