//
//  HardcoverItem+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData

extension HardcoverItem {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<HardcoverItem> {
    return NSFetchRequest<HardcoverItem>(entityName: "HardcoverItem")
  }

  @nonobjc public class func create(
    _ item: SimpleHardcoverItem,
    in context: NSManagedObjectContext
  ) -> HardcoverItem {
    // swiftlint:disable:next force_cast
    let entity = NSEntityDescription.insertNewObject(forEntityName: "HardcoverItem", into: context) as! HardcoverItem

    entity.id = Int32(item.id)
    entity.artworkURL = item.artworkURL
    entity.title = item.title
    entity.author = item.author
    entity.status = item.status

    return entity
  }

  @NSManaged public var id: Int32
  @NSManaged public var artworkURL: URL?
  @NSManaged public var title: String
  @NSManaged public var author: String
  @NSManaged public var status: Status

  @objc public enum Status: Int16, Decodable {
    case local = 0
    case library = 1
    case reading = 2
    case read = 3
  }
}
