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
        return self.items?.array as? [LibraryItem] ?? []
    }

    public func itemIndex(with relativePath: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items.firstIndex { (item) -> Bool in
            if let book = item as? Book {
                return book.relativePath == relativePath
            } else if let folder = item as? Folder {
                return folder.getItem(with: relativePath) != nil
            }

            return false
        }
    }

  public func index(for item: LibraryItem) -> Int? {
    guard let items = self.items?.array as? [LibraryItem] else {
      return nil
    }

    return items.firstIndex { (libraryItem) -> Bool in
      if let book = libraryItem as? Book {
        return book.relativePath == item.relativePath
      } else if let folder = libraryItem as? Folder {
        return folder.index(for: item) != nil
      }

      return false
    }
  }

    public func getItem(with relativePath: String) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        var itemFound: LibraryItem?

        for item in items {
            if let libraryItem = item.getItem(with: relativePath) {
                itemFound = libraryItem
                break
            }
        }

        return itemFound
    }

  func getPreviousBook(before book: Book) -> Book? {
    guard let items = self.items?.array as? [LibraryItem] else {
      return nil
    }

    guard let indexFound = self.itemIndex(with: book.relativePath) else {
      return nil
    }

    let targetIndex = indexFound - 1

    for (index, item) in items.enumerated() {
      guard index == targetIndex else { continue }

      if item.isFinished {
        item.setCurrentTime(0.0)
      }

      if let book = item as? Book {
        return book
      } else if let folder = item as? Folder {
        return folder.getPreviousBook(before: book)
      }
    }

    return nil
  }

  func getNextBook(after book: Book) -> Book? {
    guard let items = self.items?.array as? [LibraryItem] else { return nil }

    guard let indexFound = self.itemIndex(with: book.relativePath) else { return nil }

    for (index, item) in items.enumerated() {
      guard index > indexFound else { continue }

      if item.isFinished {
        item.setCurrentTime(0.0)
      }

      if let book = item as? Book {
        return book
      } else if let folder = item as? Folder {
        return folder.getNextBook(after: book)
      }
    }

    return nil
  }

    public func getItemsOrderedByDate() -> [LibraryItem] {
        guard let items = self.items?.array as? [LibraryItem] else {
            return []
        }

        var filteredItems = items.compactMap { (item) -> LibraryItem? in
            guard item.lastPlayDate != nil else { return nil }

            return item
        }

        if filteredItems.isEmpty,
            let lastPlayedBook = self.lastPlayedBook {
            lastPlayedBook.lastPlayDate = Date()
            filteredItems.append(lastPlayedBook)
        }

        return filteredItems.sorted { $0.lastPlayDate! > $1.lastPlayDate! }
    }

  public func insert(item: LibraryItem, at index: Int? = nil) {
    if let parent = item.folder {
      parent.removeFromItems(item)
      parent.updateCompletionState()
    }

    if let library = item.library {
      library.removeFromItems(item)
    }

    if let index = index {
      self.insertIntoItems(item, at: index)
    } else {
      self.addToItems(item)
    }

    self.rebuildRelativePaths(for: item)
    self.rebuildOrderRank()
  }

  public func rebuildRelativePaths(for item: LibraryItem) {
    item.relativePath = item.originalFileName

    if let folder = item as? Folder,
       let items = folder.items?.array as? [LibraryItem] {
      items.forEach({ folder.rebuildRelativePaths(for: $0) })
    }
  }

  public func rebuildOrderRank() {
    guard let items = self.items?.array as? [LibraryItem] else { return }

    for (index, item) in items.enumerated() {
      item.orderRank = Int16(index)
    }
  }

    enum CodingKeys: String, CodingKey {
        case items, books, folders, lastPlayedBook, currentTheme
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)

      if let book = self.lastPlayedBook {
        try container.encode(book, forKey: .lastPlayedBook)
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

        if let book = try? values.decode(Book.self, forKey: .lastPlayedBook) {
            self.lastPlayedBook = book
        }

        currentTheme = try? values.decode(Theme.self, forKey: .currentTheme)
    }
}
