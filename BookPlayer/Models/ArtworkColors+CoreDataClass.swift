//
//  ArtworkColors+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/14/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import ColorCube
import CoreData
import Foundation

enum ArtworkColorsError: Error {
    case averageColorFailed
}

struct ColorsToSetDefault {
    static let light = [
        UIColor(hex: "#FFFFFF"), // background
        UIColor(hex: "#37454E"), // primary
        UIColor(hex: "#3488D1"), // secondary
        UIColor(hex: "#7685B3") // tertiary
    ]
    static let dark = [
        UIColor(hex: "#212121"), // background
        UIColor(hex: "#FAFAFA"), // primary
        UIColor(hex: "#3488D1"), // secondary
        UIColor.white // tertiary
    ]
}

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
    convenience init(from image: UIImage, context: NSManagedObjectContext, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
        do {
            let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: context)!
            self.init(entity: entity, insertInto: context)

            let colorCube = CCColorCube()
            var colors: [UIColor] = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 4)!

            guard let averageColor = image.averageColor() else {
                throw ArtworkColorsError.averageColorFailed
            }

            let darkThemeEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.darkThemeEnabled.rawValue)
            let displayOnDark = averageColor.luminance < darknessThreshold || darkThemeEnabled

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

            self.setColorsFromArray(colors, displayOnDark: displayOnDark)
        } catch {
            self.setColorsFromArray()
        }
    }

    func setColorsFromArray(_ colors: [UIColor] = [], displayOnDark: Bool = false) {
        var colorsToSet = Array(colors)

        if colorsToSet.isEmpty {
            colorsToSet = displayOnDark ? ColorsToSetDefault.dark : ColorsToSetDefault.light
        } else if colorsToSet.count < 4 {
            let placeholder = displayOnDark ? UIColor.white : UIColor.black

            for _ in 1...(4 - colorsToSet.count) {
                colorsToSet.append(placeholder)
            }
        }

        self.backgroundHex = colorsToSet[0].cssHex
        self.primaryHex = colorsToSet[1].cssHex
        self.secondaryHex = colorsToSet[2].cssHex
        self.tertiaryHex = colorsToSet[3].cssHex

        self.displayOnDark = displayOnDark
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: context)!
        self.init(entity: entity, insertInto: context)

        let darkThemeEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.darkThemeEnabled.rawValue)
        self.setColorsFromArray(displayOnDark: darkThemeEnabled)
    }
}
