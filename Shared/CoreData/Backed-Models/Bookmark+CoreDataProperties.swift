//
//  Bookmark+CoreDataProperties.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

extension Bookmark {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Bookmark> {
    return NSFetchRequest<Bookmark>(entityName: "Bookmark")
  }

  @NSManaged public var time: Double
  @NSManaged public var note: String?
  @NSManaged public var type: BookmarkType
  @NSManaged public var book: Book?
}
