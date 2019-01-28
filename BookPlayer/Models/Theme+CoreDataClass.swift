//
//  Theme+CoreDataClass.swift
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

public class Theme: NSManagedObject {
    var isDark: Bool {
        return self.background.isDark
    }

    var background: UIColor { //background
        return UIColor(hex: self.backgroundHex)
    }

    var primary: UIColor { //foreground
        return UIColor(hex: self.primaryHex)
    }

    var secondary: UIColor { //detail
        return UIColor(hex: self.secondaryHex)
    }

    var tertiary: UIColor { //highlighted
        return UIColor(hex: self.tertiaryHex)
    }

    func sameColors(as theme: Theme) -> Bool {
        return self.backgroundHex == theme.backgroundHex
            && self.primaryHex == theme.primaryHex
            && self.secondaryHex == theme.secondaryHex
            && self.tertiaryHex == theme.tertiaryHex
    }

    convenience init(params: [String: String], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.backgroundHex = params["background"]
        self.primaryHex = params["primary"]
        self.secondaryHex = params["secondary"]
        self.tertiaryHex = params["tertiary"]
        self.title = params["title"]
        self.displayOnDark = false
    }

    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    convenience init(from image: UIImage, context: NSManagedObjectContext, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
        do {
            let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!

            self.init(entity: entity, insertInto: context)

            let colorCube = CCColorCube()
            var colors: [UIColor] = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 4)!

            guard let averageColor = image.averageColor() else {
                throw ArtworkColorsError.averageColorFailed
            }

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

            self.setColorsFromArray(colors, displayOnDark: displayOnDark)
        } catch {
            self.setColorsFromArray()
        }
    }

    func setColorsFromArray(_ colors: [UIColor] = [], displayOnDark: Bool = false) {
        var colorsToSet = Array(colors)
        var displayOnDarkToSet = displayOnDark

        if colorsToSet.isEmpty {
            colorsToSet.append(UIColor(hex: "#FFFFFF")) // background
            colorsToSet.append(UIColor(hex: "#37454E")) // primary
            colorsToSet.append(UIColor(hex: "#3488D1")) // secondary
            colorsToSet.append(UIColor(hex: "#7685B3")) // tertiary

            displayOnDarkToSet = false
        } else if colorsToSet.count < 4 {
            let placeholder = displayOnDarkToSet ? UIColor.white : UIColor.black

            for _ in 1...(4 - colorsToSet.count) {
                colorsToSet.append(placeholder)
            }
        }

        self.backgroundHex = colorsToSet[0].cssHex
        self.primaryHex = colorsToSet[1].cssHex
        self.secondaryHex = colorsToSet[2].cssHex
        self.tertiaryHex = colorsToSet[3].cssHex

        self.displayOnDark = displayOnDarkToSet
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.setColorsFromArray()
    }
}
