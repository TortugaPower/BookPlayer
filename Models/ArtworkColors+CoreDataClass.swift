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
public class ArtworkColors: NSManagedObject {
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
}
