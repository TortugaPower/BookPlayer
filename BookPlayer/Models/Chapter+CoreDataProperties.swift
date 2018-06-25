//
//  Chapter+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

extension Chapter {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Chapter> {
        return NSFetchRequest<Chapter>(entityName: "Chapter")
    }

    @NSManaged public var title: String!
    @NSManaged public var start: Double
    @NSManaged public var duration: Double
    @NSManaged public var index: Int16
    @NSManaged public var book: Book!

}
