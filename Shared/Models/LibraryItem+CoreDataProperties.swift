//
//  LibraryItem+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
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
    @NSManaged public var title: String!
    @NSManaged public var percentCompleted: Double
    @NSManaged public var speed: Float
    @NSManaged public var library: Library?
    @NSManaged public var folder: Folder?
    @NSManaged public var isFinished: Bool
    @NSManaged public var lastPlayDate: Date?
    @NSManaged public var relativePath: String!
    @NSManaged public var originalFileName: String!
    @NSManaged public var identifier: String!
    @NSManaged public var orderRank: Int16
}
