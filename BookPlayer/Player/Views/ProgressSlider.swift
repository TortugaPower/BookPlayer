//
//  ProgressSlider.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class ProgressSlider: UISlider {

    override var accessibilityLabel: String? {
        get {
            let value = Int(round(self.value * 100))
            return "\(value)% Complete"
        }

        set {
            self.accessibilityLabel = newValue
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    private func setup() {
        self.maximumValue = 1.0
        self.minimumValue = 0.0

        self.setThumbImage(#imageLiteral(resourceName: "thumbImageDefault"), for: .normal)
        self.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .selected)
        self.setThumbImage(#imageLiteral(resourceName: "thumbImageSelected"), for: .highlighted)
    }

    // Hide the default track
    open override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.trackRect(forBounds: bounds)

        rect.size.height = 0.01

        return rect
    }

    open override func draw(_ rect: CGRect) {
        let minColor = self.minimumTrackTintColor ?? UIColor.tintColor
        let maxColor = self.maximumTrackTintColor ?? minColor.withAlphaComponent(0.3)

        maxColor.set()

        let rect = self.bounds.insetBy(dx: 24.0, dy: 0.0)
        let height: CGFloat = 3.0
        let radius: CGFloat = height/2

        let sliderRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.height / 2 - radius),
            width: rect.width,
            height: rect.width
        )

        let progressRect = CGRect(
            x: sliderRect.origin.x,
            y: sliderRect.origin.y,
            width: sliderRect.size.width * CGFloat((value - minimumValue) / (maximumValue - minimumValue)),
            height: sliderRect.size.height
        )

        // Track
        let path = UIBezierPath()

        path.addArc(
            withCenter: CGPoint(x: sliderRect.minX + radius, y: sliderRect.minY + radius),
            radius: radius,
            startAngle: CGFloat.pi / 2,
            endAngle: -CGFloat.pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: sliderRect.maxX - radius, y: sliderRect.minY))
        path.addArc(
            withCenter: CGPoint(x: sliderRect.maxX - radius, y: sliderRect.minY + radius),
            radius: radius,
            startAngle: -CGFloat.pi / 2,
            endAngle: CGFloat.pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: sliderRect.minX + radius, y: sliderRect.minY + height))
        path.fill()
        path.addClip()

        // Progress
        minColor.set()
        UIBezierPath(rect: progressRect).fill()
    }
}
