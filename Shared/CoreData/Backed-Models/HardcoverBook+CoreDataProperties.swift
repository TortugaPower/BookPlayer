//
//  HardcoverItem+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData

extension HardcoverBook {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<HardcoverBook> {
    return NSFetchRequest<HardcoverBook>(entityName: "HardcoverBook")
  }

  @nonobjc public class func create(
    _ item: SimpleHardcoverBook,
    in context: NSManagedObjectContext
  ) -> HardcoverBook {
    // swiftlint:disable:next force_cast
    let entity = NSEntityDescription.insertNewObject(forEntityName: "HardcoverBook", into: context) as! HardcoverBook

    entity.id = Int32(item.id)
    entity.artworkURL = item.artworkURL
    entity.title = item.title
    entity.author = item.author
    entity.status = item.status
    entity.userBookID = Int32(item.userBookID ?? 0)

    return entity
  }

  @NSManaged public var id: Int32
  @NSManaged public var artworkURL: URL?
  @NSManaged public var title: String
  @NSManaged public var author: String
  @NSManaged public var status: Status
  @NSManaged public var userBookID: Int32

  @objc public enum Status: Int16, Decodable, Comparable {
    case local = 0
    case library = 1
    case reading = 2
    case read = 3
    
    public static func < (lhs: Status, rhs: Status) -> Bool {
      return lhs.rawValue < rhs.rawValue
    }
  }
}
