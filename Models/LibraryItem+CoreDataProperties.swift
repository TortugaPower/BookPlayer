//
//  LibraryItem+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension LibraryItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LibraryItem> {
        return NSFetchRequest<LibraryItem>(entityName: "LibraryItem")
    }

    @NSManaged public var artworkData: NSData?
    @NSManaged public var currentTime: Double
    @NSManaged public var duration: Double
    @NSManaged public var identifier: String!
    @NSManaged public var percentCompleted: Double
    @NSManaged public var title: String!
    @NSManaged public var library: Library?
    @NSManaged public var originalFileName: String?
}
