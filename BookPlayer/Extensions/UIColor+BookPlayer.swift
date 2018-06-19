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

        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0

        return String(format: "#%06x", rgb)
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
}
