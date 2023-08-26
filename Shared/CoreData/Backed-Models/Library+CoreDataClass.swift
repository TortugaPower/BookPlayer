//
//  Library+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

@objc(Library)
public class Library: NSManagedObject, Codable {
  public var itemsArray: [LibraryItem] {
    return self.items?.allObjects as? [LibraryItem] ?? []
  }

  enum CodingKeys: String, CodingKey {
    case items, books, folders, lastPlayedItem, currentTheme
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    if let item = self.lastPlayedItem {
      try container.encode(item, forKey: .lastPlayedItem)
    }

    try container.encode(currentTheme, forKey: .currentTheme)
  }

  public required convenience init(from decoder: Decoder) throws {
    // Create NSEntityDescription with NSManagedObjectContext
    guard let contextUserInfoKey = CodingUserInfoKey.context,
          let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
          let entity = NSEntityDescription.entity(forEntityName: "Library", in: managedObjectContext) else {
      fatalError("Failed to decode Library")
    }
    self.init(entity: entity, insertInto: nil)

    let values = try decoder.container(keyedBy: CodingKeys.self)

    if let book = try? values.decode(Book.self, forKey: .lastPlayedItem) {
      self.lastPlayedItem = book
    }

    currentTheme = try? values.decode(Theme.self, forKey: .currentTheme)
  }
}
