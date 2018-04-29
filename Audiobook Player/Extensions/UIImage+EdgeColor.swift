//
//  UIImage+EdgeColor.swift
//  ContrastColors
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 YLKGD. All rights reserved.
//

import UIKit

// swiftlint:disable identifier_name

extension UIImage {
    func edgeColor(_ insets: UIEdgeInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0), defaultColor: UIColor = .black) -> UIColor {
        guard let pixelData = self.cgImage?.dataProvider?.data else {
            return defaultColor
        }

        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let width = Int(self.size.width * self.scale)
        let height = Int(self.size.height * self.scale)

        var edgeR: Int = 0
        var edgeG: Int = 0
        var edgeB: Int = 0
        var count: Int = 0

        for x in stride(from: 0, to: width, by: 1) {
            for y in stride(from: 0, to: height, by: 1) {
                let pixelInfo: Int = ((width * y) + x) * 4

                let r: Int = Int(data[pixelInfo])
                let g: Int = Int(data[pixelInfo + 1])
                let b: Int = Int(data[pixelInfo + 2])

                // Accumulate top, right and left edges
                if
                    x < Int(insets.left) ||
                    y < Int(insets.top) ||
                    x > width - Int(insets.right) ||
                    y > height - Int(insets.bottom)
                {
                    edgeR += r
                    edgeG += g
                    edgeB += b
                    count += 1
                }
            }
        }

        return UIColor(
            red: CGFloat(edgeR / count) / 255,
            green: CGFloat(edgeG / count) / 255,
            blue: CGFloat(edgeB / count) / 255,
            alpha: 1.0
        )
    }
}
