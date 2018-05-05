//
//  ArtworkColors.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 04.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import ColorCube

struct ArtworkColors {
    let background: UIColor!
    let primary: UIColor!
    let secondary: UIColor!
    let tertiary: UIColor!
    let isDark: Bool!

    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    init(image: UIImage, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
        let colorCube = CCColorCube()
        var colors: [UIColor] = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 4)!

        let averageColor = image.averageColor()
        let displayOnDark = averageColor.luminance < darknessThreshold

        colors.sort { (color1: UIColor, color2: UIColor) -> Bool in
            if displayOnDark {
                return color1.isDarker(than: color2)
            }

            return color1.isLighter(than: color2)
        }

        let backgroundColor: UIColor = colors[0]

        colors = colors.map { (color: UIColor) -> UIColor in
            let ratio = color.contrastRatio(with: backgroundColor)

            if ratio > minimumContrastRatio || color == backgroundColor {
                return color
            }

            if displayOnDark {
                return color.overlayWhite
            }

            return color.overlayBlack
        }

        self.background = colors[0]
        self.primary = colors[1]
        self.secondary = colors[2]
        self.tertiary = colors[3]
        self.isDark = displayOnDark
    }

    // Default colors
    init() {
        self.background = UIColor(hex: "#EBECED")
        self.primary = UIColor(hex: "#696B6E")
        self.secondary = UIColor(hex: "#3488D1")
        self.tertiary = UIColor(hex: "#9D9FA3")
        self.isDark = false
    }
}
