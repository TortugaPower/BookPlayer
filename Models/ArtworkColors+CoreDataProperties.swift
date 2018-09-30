//
//  ArtworkColors+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension ArtworkColors {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ArtworkColors> {
        return NSFetchRequest<ArtworkColors>(entityName: "ArtworkColors")
    }

    @NSManaged public var backgroundHex: String!
    @NSManaged public var displayOnDark: Bool
    @NSManaged public var primaryHex: String!
    @NSManaged public var secondaryHex: String!
    @NSManaged public var tertiaryHex: String!
    @NSManaged public var book: Book?

}
