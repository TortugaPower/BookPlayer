//
//  Playlist+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation

extension Folder {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Folder> {
    return NSFetchRequest<Folder>(entityName: "Folder")
  }

  @NSManaged public var items: NSSet?
}

// MARK: Generated accessors for books

extension Folder {
  @objc(addItemsObject:)
  @NSManaged public func addToItems(_ value: LibraryItem)

  @objc(removeItemsObject:)
  @NSManaged public func removeFromItems(_ value: LibraryItem)

  @objc(addItems:)
  @NSManaged public func addToItems(_ values: NSSet)

  @objc(removeItems:)
  @NSManaged public func removeFromItems(_ values: NSSet)
}
