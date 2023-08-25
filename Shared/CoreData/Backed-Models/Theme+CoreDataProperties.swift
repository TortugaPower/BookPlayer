//
//  Theme+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension Theme {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Theme> {
    return NSFetchRequest<Theme>(entityName: "Theme")
  }
  
  @NSManaged public var lightPrimaryHex: String!
  @NSManaged public var lightSecondaryHex: String!
  @NSManaged public var lightAccentHex: String!
  @NSManaged public var lightSeparatorHex: String!
  @NSManaged public var lightSystemBackgroundHex: String!
  @NSManaged public var lightSecondarySystemBackgroundHex: String!
  @NSManaged public var lightTertiarySystemBackgroundHex: String!
  @NSManaged public var lightSystemGroupedBackgroundHex: String!
  @NSManaged public var lightSystemFillHex: String!
  @NSManaged public var lightSecondarySystemFillHex: String!
  @NSManaged public var lightTertiarySystemFillHex: String!
  @NSManaged public var lightQuaternarySystemFillHex: String!
  @NSManaged public var darkPrimaryHex: String!
  @NSManaged public var darkSecondaryHex: String!
  @NSManaged public var darkAccentHex: String!
  @NSManaged public var darkSeparatorHex: String!
  @NSManaged public var darkSystemBackgroundHex: String!
  @NSManaged public var darkSecondarySystemBackgroundHex: String!
  @NSManaged public var darkTertiarySystemBackgroundHex: String!
  @NSManaged public var darkSystemGroupedBackgroundHex: String!
  @NSManaged public var darkSystemFillHex: String!
  @NSManaged public var darkSecondarySystemFillHex: String!
  @NSManaged public var darkTertiarySystemFillHex: String!
  @NSManaged public var darkQuaternarySystemFillHex: String!
  
  @NSManaged public var title: String!
  @NSManaged public var book: Book?
  @NSManaged public var library: Library?
  
  // swiftlint:disable:next function_body_length
  public class func searchPredicate(_ params: [String: Any]) -> NSPredicate? {
    guard let title = params["title"] as? String,
          let lightPrimaryHex = params["lightPrimaryHex"] as? String,
          let lightSecondaryHex = params["lightSecondaryHex"] as? String,
          let lightAccentHex = params["lightAccentHex"] as? String,
          let lightSeparatorHex = params["lightSeparatorHex"] as? String,
          let lightSystemBackgroundHex = params["lightSystemBackgroundHex"] as? String,
          let lightSecondarySystemBackgroundHex = params["lightSecondarySystemBackgroundHex"] as? String,
          let lightTertiarySystemBackgroundHex = params["lightTertiarySystemBackgroundHex"] as? String,
          let lightSystemGroupedBackgroundHex = params["lightSystemGroupedBackgroundHex"] as? String,
          let lightSystemFillHex = params["lightSystemFillHex"] as? String,
          let lightSecondarySystemFillHex = params["lightSecondarySystemFillHex"] as? String,
          let lightTertiarySystemFillHex = params["lightTertiarySystemFillHex"] as? String,
          let lightQuaternarySystemFillHex = params["lightQuaternarySystemFillHex"] as? String,
          let darkPrimaryHex = params["darkPrimaryHex"] as? String,
          let darkSecondaryHex = params["darkSecondaryHex"] as? String,
          let darkAccentHex = params["darkAccentHex"] as? String,
          let darkSeparatorHex = params["darkSeparatorHex"] as? String,
          let darkSystemBackgroundHex = params["darkSystemBackgroundHex"] as? String,
          let darkSecondarySystemBackgroundHex = params["darkSecondarySystemBackgroundHex"] as? String,
          let darkTertiarySystemBackgroundHex = params["darkTertiarySystemBackgroundHex"] as? String,
          let darkSystemGroupedBackgroundHex = params["darkSystemGroupedBackgroundHex"] as? String,
          let darkSystemFillHex = params["darkSystemFillHex"] as? String,
          let darkSecondarySystemFillHex = params["darkSecondarySystemFillHex"] as? String,
          let darkTertiarySystemFillHex = params["darkTertiarySystemFillHex"] as? String,
          let darkQuaternarySystemFillHex = params["darkQuaternarySystemFillHex"] as? String else { return nil }
    
    let predicateFormat =
            """
            title = %@
            && lightPrimaryHex = %@
            && lightSecondaryHex = %@
            && lightAccentHex = %@
            && lightSeparatorHex = %@
            && lightSystemBackgroundHex = %@
            && lightSecondarySystemBackgroundHex = %@
            && lightTertiarySystemBackgroundHex = %@
            && lightSystemGroupedBackgroundHex = %@
            && lightSystemFillHex = %@
            && lightSecondarySystemFillHex = %@
            && lightTertiarySystemFillHex = %@
            && lightQuaternarySystemFillHex = %@
            && darkPrimaryHex = %@
            && darkSecondaryHex = %@
            && darkAccentHex = %@
            && darkSeparatorHex = %@
            && darkSystemBackgroundHex = %@
            && darkSecondarySystemBackgroundHex = %@
            && darkTertiarySystemBackgroundHex = %@
            && darkSystemGroupedBackgroundHex = %@
            && darkSystemFillHex = %@
            && darkSecondarySystemFillHex = %@
            && darkTertiarySystemFillHex = %@
            && darkQuaternarySystemFillHex = %@
            """
    
    return NSPredicate(format: predicateFormat,
                       title,
                       lightPrimaryHex,
                       lightSecondaryHex,
                       lightAccentHex,
                       lightSeparatorHex,
                       lightSystemBackgroundHex,
                       lightSecondarySystemBackgroundHex,
                       lightTertiarySystemBackgroundHex,
                       lightSystemGroupedBackgroundHex,
                       lightSystemFillHex,
                       lightSecondarySystemFillHex,
                       lightTertiarySystemFillHex,
                       lightQuaternarySystemFillHex,
                       darkPrimaryHex,
                       darkSecondaryHex,
                       darkAccentHex,
                       darkSeparatorHex,
                       darkSystemBackgroundHex,
                       darkSecondarySystemBackgroundHex,
                       darkTertiarySystemBackgroundHex,
                       darkSystemGroupedBackgroundHex,
                       darkSystemFillHex,
                       darkSecondarySystemFillHex,
                       darkTertiarySystemFillHex,
                       darkQuaternarySystemFillHex)
  }
}
