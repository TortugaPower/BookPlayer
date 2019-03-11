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
    var useDarkVariant = false

    func sameColors(as theme: Theme) -> Bool {
        return self.defaultBackgroundHex == theme.defaultBackgroundHex
            && self.defaultPrimaryHex == theme.defaultPrimaryHex
            && self.defaultSecondaryHex == theme.defaultSecondaryHex
            && self.defaultAccentHex == theme.defaultAccentHex
    }

    convenience init(params: [String: String], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.defaultBackgroundHex = params["defaultBackground"]
        self.defaultPrimaryHex = params["defaultPrimary"]
        self.defaultSecondaryHex = params["defaultSecondary"]
        self.defaultAccentHex = params["defaultAccent"]
        self.darkBackgroundHex = params["darkBackground"]
        self.darkPrimaryHex = params["darkPrimary"]
        self.darkSecondaryHex = params["darkSecondary"]
        self.darkAccentHex = params["darkAccent"]
        self.title = params["title"]
    }

    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    convenience init(from image: UIImage, context: NSManagedObjectContext, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
        do {
            let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!

            self.init(entity: entity, insertInto: context)

            let colorCube = CCColorCube()
            var colors: [UIColor] = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, count: 8)!

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

        if colorsToSet.isEmpty {
            colorsToSet.append(UIColor(hex: "#FFFFFF")) // background
            colorsToSet.append(UIColor(hex: "#37454E")) // primary
            colorsToSet.append(UIColor(hex: "#3488D1")) // secondary
            colorsToSet.append(UIColor(hex: "#7685B3")) // tertiary
        } else if colorsToSet.count < 4 {
            let placeholder = displayOnDark ? UIColor.white : UIColor.black

            for _ in 1...(4 - colorsToSet.count) {
                colorsToSet.append(placeholder)
            }
        }

        self.defaultBackgroundHex = colorsToSet[0].cssHex
        self.defaultPrimaryHex = colorsToSet[1].cssHex
        self.defaultSecondaryHex = colorsToSet[2].cssHex
        self.defaultAccentHex = colorsToSet[3].cssHex
        self.darkBackgroundHex = colorsToSet[4].cssHex
        self.darkPrimaryHex = colorsToSet[5].cssHex
        self.darkSecondaryHex = colorsToSet[6].cssHex
        self.darkAccentHex = colorsToSet[7].cssHex
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.setColorsFromArray()
    }
}

// MARK: - Color getters

extension Theme {
    var defaultBackgroundColor: UIColor {
        return UIColor(hex: self.defaultBackgroundHex)
    }

    var defaultPrimaryColor: UIColor {
        return UIColor(hex: self.defaultPrimaryHex)
    }

    var defaultSecondaryColor: UIColor {
        return UIColor(hex: self.defaultSecondaryHex)
    }

    var defaultAccentColor: UIColor {
        return UIColor(hex: self.defaultAccentHex)
    }

    var backgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkBackgroundHex
            : self.defaultBackgroundHex
        return UIColor(hex: hex)
    }

    var primaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkPrimaryHex
            : self.defaultPrimaryHex
        return UIColor(hex: hex)
    }

    var secondaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkSecondaryHex
            : self.defaultSecondaryHex
        return UIColor(hex: hex)
    }

    var detailColor: UIColor {
        return self.secondaryColor
    }

    var highlightColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkAccentHex
            : self.defaultAccentHex
        return UIColor(hex: hex)
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
