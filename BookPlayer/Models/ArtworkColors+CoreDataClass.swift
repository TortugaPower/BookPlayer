//
//  ArtworkColors+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/14/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import ColorCube

public class ArtworkColors: NSManagedObject {
    var background: UIColor {
        return UIColor(hex: self.backgroundHex)
    }
    var primary: UIColor {
        return UIColor(hex: self.primaryHex)
    }
    var secondary: UIColor {
        return UIColor(hex: self.secondaryHex)
    }
    var tertiary: UIColor {
        return UIColor(hex: self.tertiaryHex)
    }
    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    convenience init(from image: UIImage,
                     context: NSManagedObjectContext,
                     darknessThreshold: CGFloat = 0.2,
                     minimumContrastRatio: CGFloat = 3.0) {
        let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: context)!
        self.init(entity: entity, insertInto: context)

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
        print(colors[0].cssHex)
        print(colors[1].cssHex)
        print(colors[2].cssHex)
        print(colors[3].cssHex)
        self.backgroundHex = colors[0].cssHex
        self.primaryHex = colors[1].cssHex
        self.secondaryHex = colors[2].cssHex
        self.tertiaryHex = colors[3].cssHex
        self.displayOnDark = displayOnDark
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: context)!
        self.init(entity: entity, insertInto: context)

        self.backgroundHex = "#EBECED"
        self.primaryHex = "#696B6E"
        self.secondaryHex = "#3488D1"
        self.tertiaryHex = "#9D9FA3"
        self.displayOnDark = false
    }
}
