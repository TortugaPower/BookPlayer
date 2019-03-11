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

struct ArtworkColors {
    var background: String
    var primary: String
    var secondary: String
    var highlight: String
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
    convenience init(from image: UIImage, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!

        self.init(entity: entity, insertInto: context)

        self.processColors(from: image, darkVariant: true)
        self.processColors(from: image, darkVariant: false)
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.setDefaultColors(darkVariant: true)
        self.setDefaultColors(darkVariant: false)
    }

    func setColors(_ colors: ArtworkColors, darkVariant: Bool) {
        if darkVariant {
            self.darkBackgroundHex = colors.background
            self.darkPrimaryHex = colors.primary
            self.darkSecondaryHex = colors.secondary
            self.darkAccentHex = colors.highlight
        } else {
            self.defaultBackgroundHex = colors.background
            self.defaultPrimaryHex = colors.primary
            self.defaultSecondaryHex = colors.secondary
            self.defaultAccentHex = colors.highlight
        }
    }

    func processColors(from image: UIImage, darkVariant: Bool) {
        let flags = darkVariant ? CCOrderByDarkness : CCOrderByBrightness

        let colorCube = CCColorCube()

        guard let averageColor = image.averageColor(),
            let peakColor = colorCube.extractColors(from: image, flags: flags)?.first else {
            self.setDefaultColors(darkVariant: darkVariant)
            return
        }

        // Background color
        let background = self.getBackgroundColor(from: peakColor, averageColor: averageColor, darkVariant: darkVariant)
        let colors = self.process(image, averageColor: averageColor, backgroundColor: background, darkVariant: darkVariant)
        self.setColors(colors, darkVariant: false)
    }

    func process(_ image: UIImage, averageColor: UIColor, backgroundColor: UIColor, darkVariant: Bool) -> ArtworkColors {
        let colorCube = CCColorCube()

        var colors = colorCube.extractColors(from: image, flags: CCOnlyDistinctColors, avoid: backgroundColor)

        colors?.append(averageColor)
        colors = colors?.filter { $0 != backgroundColor }
        colors = colors?.filter({ !Constants.ignoredArtworkHexColors.contains($0.cssHex) })

        guard var filteredColors = colors else {
            return darkVariant
                ? self.getDefaultDarkColors()
                : self.getDefaultLightColors()
        }

        let primary = self.getPrimaryColor(from: filteredColors, background: backgroundColor, darkVariant: darkVariant)
        filteredColors = filteredColors.filter { $0 != primary }

        let secondary = self.getSecondaryColor(from: filteredColors, background: backgroundColor, primary: primary, darkVariant: darkVariant)
        filteredColors = filteredColors.filter { $0 != secondary }

        let highlight = self.getHighlightColor(from: filteredColors, background: backgroundColor, darkVariant: darkVariant)

        return ArtworkColors(background: backgroundColor.cssHex,
                             primary: primary.cssHex,
                             secondary: secondary.cssHex,
                             highlight: highlight.cssHex)
    }

    func getDefaultLightColors() -> ArtworkColors {
        return ArtworkColors(background: Constants.DefaultArtworkColors.background.lightColor,
                             primary: Constants.DefaultArtworkColors.primary.lightColor,
                             secondary: Constants.DefaultArtworkColors.secondary.lightColor,
                             highlight: Constants.DefaultArtworkColors.highlight.lightColor)
    }

    func getDefaultDarkColors() -> ArtworkColors {
        return ArtworkColors(background: Constants.DefaultArtworkColors.background.darkColor,
                             primary: Constants.DefaultArtworkColors.primary.darkColor,
                             secondary: Constants.DefaultArtworkColors.secondary.darkColor,
                             highlight: Constants.DefaultArtworkColors.highlight.darkColor)
    }

    func setDefaultColors(darkVariant: Bool) {
        let colors = darkVariant
            ? self.getDefaultDarkColors()
            : self.getDefaultLightColors()
        self.setColors(colors, darkVariant: darkVariant)
    }

    func getBackgroundColor(from color: UIColor, averageColor: UIColor, darkVariant: Bool) -> UIColor {
        var background = color.overlay(with: averageColor, using: 0.1)
        let bgThreshold: CGFloat = 0.7
        let maxThreshold: CGFloat = 0.95

        let flag = darkVariant
            ? background.luminance > bgThreshold
            : background.luminance < bgThreshold

        if flag {
            background = background.overlay(with: darkVariant ? .black : .white, using: 0.5)
        }

        let flag1 = darkVariant
            ? background.luminance < maxThreshold
            : background.luminance > maxThreshold

        let flag2 = darkVariant
            ? background.brightness < maxThreshold
            : background.brightness > maxThreshold

        if flag1 && flag2 {
            background = background.overlay(with: darkVariant ? .white : .black, using: 0.02)
        }

        if darkVariant {
            return background
        }

        //  Ensure a lighter color for very saturated backgrounds
        let satuationThreshold: CGFloat = 0.9
        let brightnessThreshold: CGFloat = 0.9

        if background.saturation > satuationThreshold && background.brightness > brightnessThreshold {
            background = background.overlay(with: .white, using: 0.8)
        }

        return background
    }

    func getPrimaryColor(from colors: [UIColor], background: UIColor, darkVariant: Bool) -> UIColor {
        var primary = colors[0]

        for color in colors {
            let flag = darkVariant
                ? color.contrastRatio(with: background) < primary.contrastRatio(with : background)
                : color.contrastRatio(with: background) > primary.contrastRatio(with: background)

            if flag {
                primary = color
            }
        }
        let flag2 = darkVariant
            ? primary.contrastRatio(with: background) > 2
            : primary.contrastRatio(with: background) < 2

        if flag2 {
            primary = primary.overlay(with: darkVariant ? .white : .black, using: 0.88)
        }

        return primary
    }

    func getSecondaryColor(from colors: [UIColor], background: UIColor, primary: UIColor, darkVariant: Bool) -> UIColor {
        var secondary = colors[0]
        let primaryBrightness = primary.brightness
        let backgroundBrightness = background.brightness
        let targetBrightness = primaryBrightness * 0.4 + backgroundBrightness * 0.6

        for color in colors {
            let flag = darkVariant
                ? abs(color.brightness - targetBrightness) > abs(secondary.brightness - targetBrightness)
                : abs(color.brightness - targetBrightness) < abs(secondary.brightness - targetBrightness)
            if flag {
                secondary = color
            }
        }

        return secondary
    }

    func getHighlightColor(from colors: [UIColor], background: UIColor, darkVariant: Bool) -> UIColor {
        var highlight = colors[0]
        print("====== getting highlight color (dark variant: \(darkVariant)), base highlight: \(highlight.cssHex), background: \(background.cssHex)")
        for color in colors {
            print(color.cssHex)
            let dist = background.relativeDistance(to: color)
            print("dist: \(dist)")
            let currentDist = background.relativeDistance(to: highlight)
            print("currentDist: \(currentDist)")
            // Prefer colors which are further away in hue and are more saturated

            let flag = darkVariant
                ? color.saturation < background.saturation
                : color.saturation > background.saturation

            if dist > currentDist && flag {
                highlight = color
            }
        }

        return highlight
    }
}

// MARK: - Color getters

extension Theme {
    var defaultBackgroundColor: UIColor {
        return UIColor(hex: self.defaultBackgroundHex)
    }

    var darkBackgroundColor: UIColor {
        return UIColor(hex: self.darkBackgroundHex)
    }

    var defaultPrimaryColor: UIColor {
        return UIColor(hex: self.defaultPrimaryHex)
    }

    var darkPrimaryColor: UIColor {
        return UIColor(hex: self.darkPrimaryHex)
    }

    var defaultSecondaryColor: UIColor {
        return UIColor(hex: self.defaultSecondaryHex)
    }

    var darkSecondaryColor: UIColor {
        return UIColor(hex: self.darkSecondaryHex)
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
