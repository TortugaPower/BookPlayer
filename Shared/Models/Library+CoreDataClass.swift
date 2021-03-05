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

    public func itemIndex(with identifier: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items.firstIndex { (item) -> Bool in
            if let book = item as? Book {
                return book.identifier == identifier
            } else if let folder = item as? Folder {
                return folder.getItem(with: identifier) != nil
            }

            return false
        }
    }

    public func getItem(with identifier: String) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        var itemFound: LibraryItem?

        for item in items {
            if let libraryItem = item.getItem(with: identifier) {
                itemFound = libraryItem
                break
            }
        }

        return itemFound
    }

    func getNextItem(after item: LibraryItem) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else { return nil }

        guard let indexFound = self.itemIndex(with: item.identifier) else { return nil }

        for (index, item) in items.enumerated() {
            guard index > indexFound,
                !item.isFinished else { continue }

            if let folder = item as? Folder, !folder.hasBooks() { continue }

            return item
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

    enum CodingKeys: String, CodingKey {
        case items, books, folders, lastPlayedBook, currentTheme
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        guard let itemsArray = self.items?.array as? [LibraryItem] else { return }

        var books = [Int: Book]()
        var folders = [Int: Folder]()

        for (index, item) in itemsArray.enumerated() {
            if let book = item as? Book {
                books[index] = book
            }
            if let folder = item as? Folder {
                folders[index] = folder
            }
        }

        if !books.isEmpty {
            try container.encode(books, forKey: .books)
        }

        if !folders.isEmpty {
            try container.encode(folders, forKey: .folders)
        }

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

        var books = [Int: LibraryItem]()
        var folders = [Int: LibraryItem]()

        if let decodedBooks = try? values.decode([Int: Book].self, forKey: .books) {
            books = decodedBooks
        }

        if let decodedFolders = try? values.decode([Int: Folder].self, forKey: .folders) {
            folders = decodedFolders
        }

        let unsortedItemsDict: [Int: LibraryItem] = books.merging(folders) { (_, new) -> LibraryItem in new }
        let sortedItemsTuple = unsortedItemsDict.sorted { $0.key < $1.key }
        let sortedItems = Array(sortedItemsTuple.map { $0.value })

        items = NSOrderedSet(array: sortedItems)

        if let book = try? values.decode(Book.self, forKey: .lastPlayedBook) {
            self.lastPlayedBook = book
        }

        currentTheme = try? values.decode(Theme.self, forKey: .currentTheme)
    }
}

extension Library: Sortable {
    public func sort(by sortType: PlayListSortOrder) {
        guard let items = items else { return }
        self.items = BookSortService.sort(items, by: sortType)
        DataManager.saveContext()
    }
}
