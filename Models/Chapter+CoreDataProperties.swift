//
//  Chapter+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension Chapter {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chapter> {
        return NSFetchRequest<Chapter>(entityName: "Chapter")
    }

    @NSManaged public var duration: Double
    @NSManaged public var index: Int16
    @NSManaged public var start: Double
    @NSManaged public var title: String!
    @NSManaged public var book: Book!
}
