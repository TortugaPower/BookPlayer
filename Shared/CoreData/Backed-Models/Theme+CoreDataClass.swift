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
public class Theme: NSManagedObject, Codable {
    public var useDarkVariant = false

    public var locked = false

    public func sameColors(as theme: Theme) -> Bool {
        return self.lightPrimaryHex == theme.lightPrimaryHex
            && self.lightSecondaryHex == theme.lightSecondaryHex
            && self.lightAccentHex == theme.lightAccentHex
            && self.lightSeparatorHex == theme.lightSeparatorHex
            && self.lightSystemBackgroundHex == theme.lightSystemBackgroundHex
            && self.lightSecondarySystemBackgroundHex == theme.lightSecondarySystemBackgroundHex
            && self.lightTertiarySystemBackgroundHex == theme.lightTertiarySystemBackgroundHex
            && self.lightSystemGroupedBackgroundHex == theme.lightSystemGroupedBackgroundHex
            && self.lightSystemFillHex == theme.lightSystemFillHex
            && self.lightSecondarySystemFillHex == theme.lightSecondarySystemFillHex
            && self.lightTertiarySystemFillHex == theme.lightTertiarySystemFillHex
            && self.lightQuaternarySystemFillHex == theme.lightQuaternarySystemFillHex
            && self.darkPrimaryHex == theme.darkPrimaryHex
            && self.darkSecondaryHex == theme.darkSecondaryHex
            && self.darkAccentHex == theme.darkAccentHex
            && self.darkSeparatorHex == theme.darkSeparatorHex
            && self.darkSystemBackgroundHex == theme.darkSystemBackgroundHex
            && self.darkSecondarySystemBackgroundHex == theme.darkSecondarySystemBackgroundHex
            && self.darkTertiarySystemBackgroundHex == theme.darkTertiarySystemBackgroundHex
            && self.darkSystemGroupedBackgroundHex == theme.darkSystemGroupedBackgroundHex
            && self.darkSystemFillHex == theme.darkSystemFillHex
            && self.darkSecondarySystemFillHex == theme.darkSecondarySystemFillHex
            && self.darkTertiarySystemFillHex == theme.darkTertiarySystemFillHex
            && self.darkQuaternarySystemFillHex == theme.darkQuaternarySystemFillHex
    }

    public convenience init(params: [String: Any], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
        self.init(entity: entity, insertInto: context)

        self.title = params["title"] as? String
        self.lightPrimaryHex = params["lightPrimaryHex"] as? String
        self.lightSecondaryHex = params["lightSecondaryHex"] as? String
        self.lightAccentHex = params["lightAccentHex"] as? String
        self.lightSeparatorHex = params["lightSeparatorHex"] as? String
        self.lightSystemBackgroundHex = params["lightSystemBackgroundHex"] as? String
        self.lightSecondarySystemBackgroundHex = params["lightSecondarySystemBackgroundHex"] as? String
        self.lightTertiarySystemBackgroundHex = params["lightTertiarySystemBackgroundHex"] as? String
        self.lightSystemGroupedBackgroundHex = params["lightSystemGroupedBackgroundHex"] as? String
        self.lightSystemFillHex = params["lightSystemFillHex"] as? String
        self.lightSecondarySystemFillHex = params["lightSecondarySystemFillHex"] as? String
        self.lightTertiarySystemFillHex = params["lightTertiarySystemFillHex"] as? String
        self.lightQuaternarySystemFillHex = params["lightQuaternarySystemFillHex"] as? String
        self.darkPrimaryHex = params["darkPrimaryHex"] as? String
        self.darkSecondaryHex = params["darkSecondaryHex"] as? String
        self.darkAccentHex = params["darkAccentHex"] as? String
        self.darkSeparatorHex = params["darkSeparatorHex"] as? String
        self.darkSystemBackgroundHex = params["darkSystemBackgroundHex"] as? String
        self.darkSecondarySystemBackgroundHex = params["darkSecondarySystemBackgroundHex"] as? String
        self.darkTertiarySystemBackgroundHex = params["darkTertiarySystemBackgroundHex"] as? String
        self.darkSystemGroupedBackgroundHex = params["darkSystemGroupedBackgroundHex"] as? String
        self.darkSystemFillHex = params["darkSystemFillHex"] as? String
        self.darkSecondarySystemFillHex = params["darkSecondarySystemFillHex"] as? String
        self.darkTertiarySystemFillHex = params["darkTertiarySystemFillHex"] as? String
        self.darkQuaternarySystemFillHex = params["darkQuaternarySystemFillHex"] as? String
        self.locked = params["locked"] as? Bool ?? false
    }

    // W3C recommends contrast values larger 4 or 7 (strict), but 3.0 should be fine for our use case
    public convenience init(from image: UIImage?, context: NSManagedObjectContext, darknessThreshold: CGFloat = 0.2, minimumContrastRatio: CGFloat = 3.0) {
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
        self.lightPrimaryHex = Constants.DefaultArtworkColors.primary.lightColor
        self.lightSecondaryHex = Constants.DefaultArtworkColors.secondary.lightColor
        self.lightAccentHex = Constants.DefaultArtworkColors.accent.lightColor
        self.lightSeparatorHex = Constants.DefaultArtworkColors.separator.lightColor
        self.lightSystemBackgroundHex = Constants.DefaultArtworkColors.systemBackground.lightColor
        self.lightSecondarySystemBackgroundHex = Constants.DefaultArtworkColors.secondarySystemBackground.lightColor
        self.lightTertiarySystemBackgroundHex = Constants.DefaultArtworkColors.tertiarySystemBackground.lightColor
        self.lightSystemGroupedBackgroundHex = Constants.DefaultArtworkColors.systemGroupedBackground.lightColor
        self.lightSystemFillHex = Constants.DefaultArtworkColors.systemFill.lightColor
        self.lightSecondarySystemFillHex = Constants.DefaultArtworkColors.secondarySystemFill.lightColor
        self.lightTertiarySystemFillHex = Constants.DefaultArtworkColors.tertiarySystemFill.lightColor
        self.lightQuaternarySystemFillHex = Constants.DefaultArtworkColors.quaternarySystemFill.lightColor
        self.darkPrimaryHex = Constants.DefaultArtworkColors.primary.darkColor
        self.darkSecondaryHex = Constants.DefaultArtworkColors.secondary.darkColor
        self.darkAccentHex = Constants.DefaultArtworkColors.accent.darkColor
        self.darkSeparatorHex = Constants.DefaultArtworkColors.separator.darkColor
        self.darkSystemBackgroundHex = Constants.DefaultArtworkColors.systemBackground.darkColor
        self.darkSecondarySystemBackgroundHex = Constants.DefaultArtworkColors.secondarySystemBackground.darkColor
        self.darkTertiarySystemBackgroundHex = Constants.DefaultArtworkColors.tertiarySystemBackground.darkColor
        self.darkSystemGroupedBackgroundHex = Constants.DefaultArtworkColors.systemGroupedBackground.darkColor
        self.darkSystemFillHex = Constants.DefaultArtworkColors.systemFill.darkColor
        self.darkSecondarySystemFillHex = Constants.DefaultArtworkColors.secondarySystemFill.darkColor
        self.darkTertiarySystemFillHex = Constants.DefaultArtworkColors.tertiarySystemFill.darkColor
        self.darkQuaternarySystemFillHex = Constants.DefaultArtworkColors.quaternarySystemFill.darkColor
    }

    enum CodingKeys: String, CodingKey {
        case title, lightPrimaryHex, lightSecondaryHex, lightAccentHex, lightSeparatorHex, lightSystemBackgroundHex, lightSecondarySystemBackgroundHex, lightTertiarySystemBackgroundHex, lightSystemGroupedBackgroundHex, lightSystemFillHex, lightSecondarySystemFillHex, lightTertiarySystemFillHex, lightQuaternarySystemFillHex, darkPrimaryHex, darkSecondaryHex, darkAccentHex, darkSeparatorHex, darkSystemBackgroundHex, darkSecondarySystemBackgroundHex, darkTertiarySystemBackgroundHex, darkSystemGroupedBackgroundHex, darkSystemFillHex, darkSecondarySystemFillHex, darkTertiarySystemFillHex, darkQuaternarySystemFillHex
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(lightPrimaryHex, forKey: .lightPrimaryHex)
        try container.encode(lightSecondaryHex, forKey: .lightSecondaryHex)
        try container.encode(lightAccentHex, forKey: .lightAccentHex)
        try container.encode(lightSeparatorHex, forKey: .lightSeparatorHex)
        try container.encode(lightSystemBackgroundHex, forKey: .lightSystemBackgroundHex)
        try container.encode(lightSecondarySystemBackgroundHex, forKey: .lightSecondarySystemBackgroundHex)
        try container.encode(lightTertiarySystemBackgroundHex, forKey: .lightTertiarySystemBackgroundHex)
        try container.encode(lightSystemGroupedBackgroundHex, forKey: .lightSystemGroupedBackgroundHex)
        try container.encode(lightSystemFillHex, forKey: .lightSystemFillHex)
        try container.encode(lightSecondarySystemFillHex, forKey: .lightSecondarySystemFillHex)
        try container.encode(lightTertiarySystemFillHex, forKey: .lightTertiarySystemFillHex)
        try container.encode(lightQuaternarySystemFillHex, forKey: .lightQuaternarySystemFillHex)
        try container.encode(darkPrimaryHex, forKey: .darkPrimaryHex)
        try container.encode(darkSecondaryHex, forKey: .darkSecondaryHex)
        try container.encode(darkAccentHex, forKey: .darkAccentHex)
        try container.encode(darkSeparatorHex, forKey: .darkSeparatorHex)
        try container.encode(darkSystemBackgroundHex, forKey: .darkSystemBackgroundHex)
        try container.encode(darkSecondarySystemBackgroundHex, forKey: .darkSecondarySystemBackgroundHex)
        try container.encode(darkTertiarySystemBackgroundHex, forKey: .darkTertiarySystemBackgroundHex)
        try container.encode(darkSystemGroupedBackgroundHex, forKey: .darkSystemGroupedBackgroundHex)
        try container.encode(darkSystemFillHex, forKey: .darkSystemFillHex)
        try container.encode(darkSecondarySystemFillHex, forKey: .darkSecondarySystemFillHex)
        try container.encode(darkTertiarySystemFillHex, forKey: .darkTertiarySystemFillHex)
        try container.encode(darkQuaternarySystemFillHex, forKey: .darkQuaternarySystemFillHex)
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
              let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
              let entity = NSEntityDescription.entity(forEntityName: "Theme", in: managedObjectContext)
        else {
            fatalError("Failed to decode Theme!")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)

        lightPrimaryHex = try values.decode(String.self, forKey: .lightPrimaryHex)
        lightSecondaryHex = try values.decode(String.self, forKey: .lightSecondaryHex)
        lightAccentHex = try values.decode(String.self, forKey: .lightAccentHex)
        lightSeparatorHex = try values.decode(String.self, forKey: .lightSeparatorHex)
        lightSystemBackgroundHex = try values.decode(String.self, forKey: .lightSystemBackgroundHex)
        lightSecondarySystemBackgroundHex = try values.decode(String.self, forKey: .lightSecondarySystemBackgroundHex)
        lightTertiarySystemBackgroundHex = try values.decode(String.self, forKey: .lightTertiarySystemBackgroundHex)
        lightSystemGroupedBackgroundHex = try values.decode(String.self, forKey: .lightSystemGroupedBackgroundHex)
        lightSystemFillHex = try values.decode(String.self, forKey: .lightSystemFillHex)
        lightSecondarySystemFillHex = try values.decode(String.self, forKey: .lightSecondarySystemFillHex)
        lightTertiarySystemFillHex = try values.decode(String.self, forKey: .lightTertiarySystemFillHex)
        lightQuaternarySystemFillHex = try values.decode(String.self, forKey: .lightQuaternarySystemFillHex)
        darkPrimaryHex = try values.decode(String.self, forKey: .darkPrimaryHex)
        darkSecondaryHex = try values.decode(String.self, forKey: .darkSecondaryHex)
        darkAccentHex = try values.decode(String.self, forKey: .darkAccentHex)
        darkSeparatorHex = try values.decode(String.self, forKey: .darkSeparatorHex)
        darkSystemBackgroundHex = try values.decode(String.self, forKey: .darkSystemBackgroundHex)
        darkSecondarySystemBackgroundHex = try values.decode(String.self, forKey: .darkSecondarySystemBackgroundHex)
        darkTertiarySystemBackgroundHex = try values.decode(String.self, forKey: .darkTertiarySystemBackgroundHex)
        darkSystemGroupedBackgroundHex = try values.decode(String.self, forKey: .darkSystemGroupedBackgroundHex)
        darkSystemFillHex = try values.decode(String.self, forKey: .darkSystemFillHex)
        darkSecondarySystemFillHex = try values.decode(String.self, forKey: .darkSecondarySystemFillHex)
        darkTertiarySystemFillHex = try values.decode(String.self, forKey: .darkTertiarySystemFillHex)
        darkQuaternarySystemFillHex = try values.decode(String.self, forKey: .darkQuaternarySystemFillHex)
    }
}

// MARK: - Color getters

public extension Theme {
    var lightPrimaryColor: UIColor {
        return UIColor(hex: lightPrimaryHex)
    }

    var lightSecondaryColor: UIColor {
        return UIColor(hex: lightSecondaryHex)
    }

    var lightLinkColor: UIColor {
        return UIColor(hex: lightAccentHex)
    }

    var lightSystemBackgroundColor: UIColor {
        return UIColor(hex: lightSystemBackgroundHex)
    }

    var primaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkPrimaryHex
            : lightPrimaryHex
        return UIColor(hex: hex)
    }

    var secondaryColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSecondaryHex
            : lightSecondaryHex
        return UIColor(hex: hex)
    }

    var linkColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkAccentHex
            : lightAccentHex
        return UIColor(hex: hex)
    }

    var separatorColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSeparatorHex
            : lightSeparatorHex
        return UIColor(hex: hex)
    }

    var systemBackgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSystemBackgroundHex
            : lightSystemBackgroundHex
        return UIColor(hex: hex)
    }

    var secondarySystemBackgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSecondarySystemBackgroundHex
            : lightSecondarySystemBackgroundHex
        return UIColor(hex: hex)
    }

    var tertiarySystemBackgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkTertiarySystemBackgroundHex
            : lightTertiarySystemBackgroundHex
        return UIColor(hex: hex)
    }

    var systemGroupedBackgroundColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSystemGroupedBackgroundHex
            : lightSystemGroupedBackgroundHex
        return UIColor(hex: hex)
    }

    var systemFillColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSystemFillHex
            : lightSystemFillHex
        return UIColor(hex: hex)
    }

    var secondarySystemFillColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkSecondarySystemFillHex
            : lightSecondarySystemFillHex
        return UIColor(hex: hex)
    }

    var tertiarySystemFillColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkTertiarySystemFillHex
            : lightTertiarySystemFillHex
        return UIColor(hex: hex)
    }

    var quaternarySystemFillColor: UIColor {
        let hex: String = self.useDarkVariant
            ? darkQuaternarySystemFillHex
            : lightQuaternarySystemFillHex
        return UIColor(hex: hex)
    }
}
