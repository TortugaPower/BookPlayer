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
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.setColorsFromArray()
    }
}

extension Theme {
    var isDark: Bool {
        return self.backgroundColor.isDark
    }

    var backgroundColor: UIColor {
        return UIColor(hex: self.backgroundHex)
    }

    var primaryColor: UIColor {
        return UIColor(hex: self.primaryHex)
    }

    var secondaryColor: UIColor {
        return UIColor(hex: self.secondaryHex)
    }

    var tertiaryColor: UIColor {
        return UIColor(hex: self.tertiaryHex)
    }

    var detailColor: UIColor {
        return self.secondaryColor
    }

    var highlightColor: UIColor {
        return self.tertiaryColor
    }

    var lightHighlightColor: UIColor {
        return self.highlightColor.withAlpha(newAlpha: 0.3)
    }

    var importBackgroundColor: UIColor {
        return self.secondaryColor.overlay(with: self.backgroundColor, using: 0.83)
    }

    var separatorColor: UIColor {
        return self.secondaryColor.overlay(with: self.backgroundColor, using: 0.51)
    }

    var settingsBackgroundColor: UIColor {
        return self.secondaryColor.overlay(with: self.highlightColor, using: 0.17).overlay(with: self.backgroundColor, using: 0.88)
    }

    var pieFillColor: UIColor {
        return self.secondaryColor.overlay(with: self.backgroundColor, using: 0.27)
    }

    var pieBorderColor: UIColor {
        return self.secondaryColor.overlay(with: self.backgroundColor, using: 0.51)
    }

    var pieBackgroundColor: UIColor {
        return self.secondaryColor.overlay(with: self.backgroundColor, using: 0.90)
    }

    var highlightedPieFillColor: UIColor {
        return self.highlightColor.overlay(with: self.backgroundColor, using: 0.27)
    }

    var highlightedPieBorderColor: UIColor {
        return self.highlightColor.overlay(with: self.backgroundColor, using: 0.51)
    }

    var highlightedPieBackgroundColor: UIColor {
        return self.highlightColor.overlay(with: self.backgroundColor, using: 0.90)
    }

    var navigationTitleColor: UIColor {
        return self.primaryColor.overlay(with: self.highlightColor, using: 0.12).overlay(with: self.backgroundColor, using: 0.11)
    }
}
