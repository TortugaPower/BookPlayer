//
//  UIColor+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

// swiftlint:disable identifier_name

extension UIColor {
    public var cssHex: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255) << 0

        return String(format: "#%06x", rgb)
    }

    static var playerControlsShadowColor: UIColor {
        return UIColor(hex: "545454")
    }

    static var tintColor: UIColor {
        return UIColor(hex: "3488D1")
    }

    static var textColor: UIColor {
        return UIColor(hex: "37454E")
    }

    public var brightness: CGFloat {
        var H: CGFloat = 0
        var S: CGFloat = 0
        var B: CGFloat = 0
        var A: CGFloat = 0
        self.getHue(&H, saturation: &S, brightness: &B, alpha: &A)

        return B
    }

    /// Blend two colors by amount
    ///
    /// - Parameters:
    ///   - color: Color to be mixed into the current color
    ///   - amount: 0 - 1.0 of the color that should be mixed in
    /// - Returns: a new UIColor
    func mix(with color: UIColor, amount: CGFloat = 0.5) -> UIColor {
        let mainRGBA = self.RGBA
        let maskRGBA = color.RGBA
        let invertedAmount = 1.0 - amount

        return UIColor(r: mainRGBA[0] * invertedAmount + maskRGBA[0] * amount,
                       g: mainRGBA[1] * invertedAmount + maskRGBA[1] * amount,
                       b: mainRGBA[2] * invertedAmount + maskRGBA[2] * amount,
                       a: mainRGBA[3] * invertedAmount + maskRGBA[3] * amount)
    }
}
