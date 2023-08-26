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

@objc(Theme)
public class Theme: NSManagedObject, Codable {
  public var useDarkVariant = false

  public var locked = false

  public convenience init(simpleTheme: SimpleTheme, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Theme", in: context)!
    self.init(entity: entity, insertInto: context)

    self.title = simpleTheme.title
    self.lightPrimaryHex = simpleTheme.lightPrimaryHex
    self.lightSecondaryHex = simpleTheme.lightSecondaryHex
    self.lightAccentHex = simpleTheme.lightAccentHex
    self.lightSeparatorHex = simpleTheme.lightSeparatorHex
    self.lightSystemBackgroundHex = simpleTheme.lightSystemBackgroundHex
    self.lightSecondarySystemBackgroundHex = simpleTheme.lightSecondarySystemBackgroundHex
    self.lightTertiarySystemBackgroundHex = simpleTheme.lightTertiarySystemBackgroundHex
    self.lightSystemGroupedBackgroundHex = simpleTheme.lightSystemGroupedBackgroundHex
    self.lightSystemFillHex = simpleTheme.lightSystemFillHex
    self.lightSecondarySystemFillHex = simpleTheme.lightSecondarySystemFillHex
    self.lightTertiarySystemFillHex = simpleTheme.lightTertiarySystemFillHex
    self.lightQuaternarySystemFillHex = simpleTheme.lightQuaternarySystemFillHex
    self.darkPrimaryHex = simpleTheme.darkPrimaryHex
    self.darkSecondaryHex = simpleTheme.darkSecondaryHex
    self.darkAccentHex = simpleTheme.darkAccentHex
    self.darkSeparatorHex = simpleTheme.darkSeparatorHex
    self.darkSystemBackgroundHex = simpleTheme.darkSystemBackgroundHex
    self.darkSecondarySystemBackgroundHex = simpleTheme.darkSecondarySystemBackgroundHex
    self.darkTertiarySystemBackgroundHex = simpleTheme.darkTertiarySystemBackgroundHex
    self.darkSystemGroupedBackgroundHex = simpleTheme.darkSystemGroupedBackgroundHex
    self.darkSystemFillHex = simpleTheme.darkSystemFillHex
    self.darkSecondarySystemFillHex = simpleTheme.darkSecondarySystemFillHex
    self.darkTertiarySystemFillHex = simpleTheme.darkTertiarySystemFillHex
    self.darkQuaternarySystemFillHex = simpleTheme.darkQuaternarySystemFillHex
    self.locked = simpleTheme.locked
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
