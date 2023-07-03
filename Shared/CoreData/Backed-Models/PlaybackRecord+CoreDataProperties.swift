//
//  PlaybackRecord+CoreDataProperties.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

extension PlaybackRecord {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaybackRecord> {
    return NSFetchRequest<PlaybackRecord>(entityName: "PlaybackRecord")
  }

  @nonobjc public class func create(in context: NSManagedObjectContext) -> PlaybackRecord {
    // swiftlint:disable force_cast
    return NSEntityDescription.insertNewObject(forEntityName: "PlaybackRecord", into: context) as! PlaybackRecord
    // swiftlint:enable force_cast
  }

  @NSManaged public var date: Date
  @NSManaged public var time: Double
}
