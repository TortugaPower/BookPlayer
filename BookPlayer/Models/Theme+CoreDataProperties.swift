//
//  Theme+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/14/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension Theme {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Theme> {
        return NSFetchRequest<Theme>(entityName: "Theme")
    }

    @NSManaged public var defaultBackgroundHex: String!
    @NSManaged public var defaultPrimaryHex: String!
    @NSManaged public var defaultSecondaryHex: String!
    @NSManaged public var defaultAccentHex: String!
    @NSManaged public var darkBackgroundHex: String!
    @NSManaged public var darkPrimaryHex: String!
    @NSManaged public var darkSecondaryHex: String!
    @NSManaged public var darkAccentHex: String!
    @NSManaged public var title: String?
    @NSManaged public var book: Book?
    @NSManaged public var library: Library?

    public class func searchPredicate(_ params: [String: Any]) -> NSPredicate? {
        guard let defaultBackgroundHex = params["defaultBackground"] as? String,
            let defaultPrimaryHex = params["defaultPrimary"] as? String,
            let defaultSecondaryHex = params["defaultSecondary"] as? String,
            let defaultAccentHex = params["defaultAccent"] as? String,
            let darkBackgroundHex = params["darkBackground"] as? String,
            let darkPrimaryHex = params["darkPrimary"] as? String,
            let darkSecondaryHex = params["darkSecondary"] as? String,
            let darkAccentHex = params["darkAccent"] as? String,
            let title = params["title"] as? String else { return nil }

        let predicateFormat =
            """
            defaultBackgroundHex = %@
            && defaultPrimaryHex = %@
            && defaultSecondaryHex = %@
            && defaultAccentHex = %@
            && darkBackgroundHex = %@
            && darkPrimaryHex = %@
            && darkSecondaryHex = %@
            && darkAccentHex = %@
            && title = %@
            """

        return NSPredicate(format: predicateFormat,
                           defaultBackgroundHex,
                           defaultPrimaryHex,
                           defaultSecondaryHex,
                           defaultAccentHex,
                           darkBackgroundHex,
                           darkPrimaryHex,
                           darkSecondaryHex,
                           darkAccentHex,
                           title)
    }
}
