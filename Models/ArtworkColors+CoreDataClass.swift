//
//  ArtworkColors+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit

public enum ArtworkColorsError: Error {
    case averageColorFailed
}

@objc(ArtworkColors)
public class ArtworkColors: NSManagedObject, Codable {
    public var background: UIColor {
        return UIColor(hex: self.backgroundHex)
    }
    public var primary: UIColor {
        return UIColor(hex: self.primaryHex)
    }
    public var secondary: UIColor {
        return UIColor(hex: self.secondaryHex)
    }
    public var tertiary: UIColor {
        return UIColor(hex: self.tertiaryHex)
    }

    public func setColorsFromArray(_ colors: [UIColor] = [], displayOnDark: Bool = false) {
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
    public convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: context)!
        self.init(entity: entity, insertInto: context)

        self.setColorsFromArray()
    }

    enum CodingKeys: String, CodingKey {
        case backgroundHex, displayOnDark, primaryHex, secondaryHex, tertiaryHex
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(backgroundHex, forKey: .backgroundHex)
        try container.encode(displayOnDark, forKey: .displayOnDark)
        try container.encode(primaryHex, forKey: .primaryHex)
        try container.encode(secondaryHex, forKey: .secondaryHex)
        try container.encode(tertiaryHex, forKey: .tertiaryHex)
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "ArtworkColors", in: managedObjectContext) else {
                fatalError("Failed to decode Library")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        backgroundHex = try values.decode(String.self, forKey: .backgroundHex)
        displayOnDark = try values.decode(Bool.self, forKey: .displayOnDark)
        primaryHex = try values.decode(String.self, forKey: .primaryHex)
        secondaryHex = try values.decode(String.self, forKey: .secondaryHex)
        tertiaryHex = try values.decode(String.self, forKey: .tertiaryHex)
    }
}
