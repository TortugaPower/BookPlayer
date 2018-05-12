//
//  LibraryItem+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData


extension LibraryItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LibraryItem> {
        return NSFetchRequest<LibraryItem>(entityName: "LibraryItem")
    }

    @NSManaged public var artwork: NSData?
    @NSManaged public var currentTime: Double
    @NSManaged public var duration: Double
    @NSManaged public var identifier: String!
    @NSManaged public var title: String!
    @NSManaged public var percentCompleted: Double
    @NSManaged public var library: Library?

}
