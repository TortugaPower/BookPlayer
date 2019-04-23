//
//  Theme+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

enum ArtworkColorsError: Error {
    case averageColorFailed
}

@objc(Theme)
public class Theme: NSManagedObject {
    public var useDarkVariant = false

    public var locked = false

    public func sameColors(as theme: Theme) -> Bool {
        return self.defaultBackgroundHex == theme.defaultBackgroundHex
            && self.defaultPrimaryHex == theme.defaultPrimaryHex
            && self.defaultSecondaryHex == theme.defaultSecondaryHex
            && self.defaultAccentHex == theme.defaultAccentHex
    }

    public convenience init(params: [String: Any], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.defaultBackgroundHex = params["defaultBackground"] as? String
        self.defaultPrimaryHex = params["defaultPrimary"] as? String
        self.defaultSecondaryHex = params["defaultSecondary"] as? String
        self.defaultAccentHex = params["defaultAccent"] as? String
        self.darkBackgroundHex = params["darkBackground"] as? String
        self.darkPrimaryHex = params["darkPrimary"] as? String
        self.darkSecondaryHex = params["darkSecondary"] as? String
        self.darkAccentHex = params["darkAccent"] as? String
        self.title = params["title"] as? String
        self.locked = params["locked"] as? Bool ?? false
    }

    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    public convenience init(from image: UIImage, context: NSManagedObjectContext, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        // Temporal: color extraction removed for the time being
        self.setColors()
    }

    // Default colors
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)
        self.setColors()
    }

    func setColors() {
        self.defaultBackgroundHex = Constants.DefaultArtworkColors.background.lightColor
        self.darkBackgroundHex = Constants.DefaultArtworkColors.background.darkColor
        self.defaultPrimaryHex = Constants.DefaultArtworkColors.primary.lightColor
        self.darkPrimaryHex = Constants.DefaultArtworkColors.primary.darkColor
        self.defaultSecondaryHex = Constants.DefaultArtworkColors.secondary.lightColor
        self.darkSecondaryHex = Constants.DefaultArtworkColors.secondary.darkColor
        self.defaultAccentHex = Constants.DefaultArtworkColors.highlight.lightColor
        self.darkAccentHex = Constants.DefaultArtworkColors.highlight.darkColor
    }
}

// MARK: - Color getters

extension Theme {
    public var defaultBackgroundColor: UIColor {
        return UIColor(hex: self.defaultBackgroundHex)
    }

    public var defaultPrimaryColor: UIColor {
        return UIColor(hex: self.defaultPrimaryHex)
    }

    public var defaultSecondaryColor: UIColor {
        return UIColor(hex: self.defaultSecondaryHex)
    }

    public var defaultAccentColor: UIColor {
        return UIColor(hex: self.defaultAccentHex)
    }

    public var backgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkBackgroundHex
            : self.defaultBackgroundHex
        return UIColor(hex: hex)
    }

    public var primaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkPrimaryHex
            : self.defaultPrimaryHex
        return UIColor(hex: hex)
    }

    public var secondaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkSecondaryHex
            : self.defaultSecondaryHex
        return UIColor(hex: hex)
    }

    public var detailColor: UIColor {
        return self.secondaryColor
    }

    public var highlightColor: UIColor {
        let hex: String = self.useDarkVariant
            ? self.darkAccentHex
            : self.defaultAccentHex
        return UIColor(hex: hex)
    }

    public var lightHighlightColor: UIColor {
        return self.highlightColor.withAlpha(newAlpha: 0.3)
    }

    public var importBackgroundColor: UIColor {
        return self.secondaryColor.mix(with: self.backgroundColor, amount: 0.83)
    }

    public var separatorColor: UIColor {
        return self.secondaryColor.mix(with: self.backgroundColor, amount: 0.60)
    }

    public var settingsBackgroundColor: UIColor {
        return self.secondaryColor
            .mix(with: self.highlightColor, amount: 0.03)
            .mix(with: self.backgroundColor, amount: 0.90)
    }

    public var pieFillColor: UIColor {
        return self.secondaryColor.mix(with: self.backgroundColor, amount: 0.27)
    }

    public var pieBorderColor: UIColor {
        return self.secondaryColor.mix(with: self.backgroundColor, amount: 0.51)
    }

    public var pieBackgroundColor: UIColor {
        return self.secondaryColor.mix(with: self.backgroundColor, amount: 0.90)
    }

    public var highlightedPieFillColor: UIColor {
        return self.pieFillColor.mix(with: self.highlightColor, amount: 0.30)
    }

    public var highlightedPieBorderColor: UIColor {
        return self.pieBorderColor.mix(with: self.highlightColor, amount: 0.30)
    }

    public var highlightedPieBackgroundColor: UIColor {
        return self.pieBackgroundColor.mix(with: self.highlightColor, amount: 0.30)
    }

    public var navigationTitleColor: UIColor {
        return self.primaryColor
            .mix(with: self.highlightColor, amount: 0.16)
            .mix(with: self.backgroundColor, amount: 0.10)
    }

    public var miniPlayerBackgroundColor: UIColor {
        return self.backgroundColor.mix(with: self.useDarkVariant ? UIColor.black : UIColor.white)
    }
}
