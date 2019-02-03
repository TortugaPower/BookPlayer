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

    @NSManaged public var backgroundHex: String!
    @NSManaged public var primaryHex: String!
    @NSManaged public var secondaryHex: String!
    @NSManaged public var tertiaryHex: String!
    @NSManaged public var title: String?
    @NSManaged public var book: Book?
    @NSManaged public var library: Library?
}
