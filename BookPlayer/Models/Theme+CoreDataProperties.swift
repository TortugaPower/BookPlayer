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

    public class func searchPredicate(_ params: [String: String]) -> NSPredicate? {
        guard let defaultBackgroundHex = params["defaultBackground"],
            let defaultPrimaryHex = params["defaultPrimary"],
            let defaultSecondaryHex = params["defaultSecondary"],
            let defaultAccentHex = params["defaultAccent"],
            let darkBackgroundHex = params["darkBackground"],
            let darkPrimaryHex = params["darkPrimary"],
            let darkSecondaryHex = params["darkSecondary"],
            let darkAccentHex = params["darkAccent"],
            let title = params["title"] else { return nil }

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
