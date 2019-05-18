//
//  CheckboxSelectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/18/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class CheckboxSelectionView: UIView {
    private let pieOutline = CAShapeLayer()
    private let pieSegment = CAShapeLayer()
    var defaultColor = UIColor(hex: "8F8E94")
    var selectedColor = UIColor(hex: "4C86CB")

    private var pieColor: CGColor {
        return self.isSelected ? self.selectedColor.cgColor : self.defaultColor.withAlpha(newAlpha: 0.5).cgColor
    }

    var isSelected: Bool = false {
        didSet {
            self.pieOutline.strokeColor = self.pieColor
            self.pieSegment.fillColor = self.pieColor

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
        self.pieOutline.strokeColor = self.pieColor
        self.pieOutline.lineWidth = 1.5

        self.layer.addSublayer(self.pieOutline)

        self.pieSegment.frame = bounds
        self.pieSegment.contentsScale = scale
        self.pieSegment.allowsEdgeAntialiasing = true
        self.pieSegment.backgroundColor = UIColor.clear.cgColor
        self.pieSegment.fillColor = self.pieColor
        self.pieSegment.strokeColor = UIColor.clear.cgColor
        self.pieSegment.lineWidth = 0

        self.layer.addSublayer(self.pieSegment)
    }

    override func draw(_ rect: CGRect) {
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        let diameter = min(width, height)
        let center = CGPoint(x: width * 0.5, y: height * 0.5)

        // Show progress pie chart
        let lineWidth: CGFloat = 1.5
        var radius: CGFloat = diameter * 0.5 - lineWidth / 2

        self.pieOutline.isHidden = false
        self.pieSegment.isHidden = false

        self.pieOutline.path = UIBezierPath(arcCenter: center,
                                            radius: radius,
                                            startAngle: 0,
                                            endAngle: CGFloat.pi * 2,
                                            clockwise: true).cgPath

        radius = diameter * 0.5 - lineWidth * 2

        let value: CGFloat = self.isSelected ? 1.0 : 0

        let path = UIBezierPath()

        path.move(to: center)
        path.addArc(withCenter: center,
                    radius: radius,
                    startAngle: -CGFloat.pi / 2,
                    endAngle: min(1.0, max(0.0, value)) * CGFloat.pi * 2 - CGFloat.pi / 2,
                    clockwise: true)
        path.close()

        self.pieSegment.path = path.cgPath
    }
}
