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

    func itemIndex(with identifier: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        for (index, item) in items.enumerated() {
            if let storedBook = item as? Book,
                storedBook.identifier == identifier {
                return index
            }

            // check if playlist
            if
                let playlist = item as? Folder,
                let storedBooks = playlist.books?.array as? [Book],
                storedBooks.contains(where: { (storedBook) -> Bool in
                    storedBook.identifier == identifier
                }) {
                // check playlist books
                return index
            }
        }

        return nil
    }

    public func itemIndex(with url: URL) -> Int? {
        let hash = url.lastPathComponent

        return self.itemIndex(with: hash)
    }

    func getItem(at index: Int) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items[index]
    }

    public func getItem(with url: URL) -> LibraryItem? {
        guard let index = self.itemIndex(with: url) else {
            return nil
        }

        return self.getItem(at: index)
    }

    public func getItem(with identifier: String) -> LibraryItem? {
        guard let index = self.itemIndex(with: identifier) else {
            return nil
        }

        return self.getItem(at: index)
    }

    func getNextItem(after item: LibraryItem) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else { return nil }

        guard let indexFound = items.firstIndex(of: item) else { return nil }

        for (index, item) in items.enumerated() {
            guard index > indexFound,
                !item.isFinished else { continue }

            if let playlist = item as? Folder, !playlist.hasBooks() { continue }

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
        case items, books, playlists, lastPlayedBook, currentTheme
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        guard let itemsArray = self.items?.array as? [LibraryItem] else { return }

        var books = [Int: Book]()
        var playlists = [Int: Folder]()

        for (index, item) in itemsArray.enumerated() {
            if let book = item as? Book {
                books[index] = book
            }
            if let playlist = item as? Folder {
                playlists[index] = playlist
            }
        }

        if !books.isEmpty {
            try container.encode(books, forKey: .books)
        }

        if !playlists.isEmpty {
            try container.encode(playlists, forKey: .playlists)
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
        var playlists = [Int: LibraryItem]()

        if let decodedBooks = try? values.decode([Int: Book].self, forKey: .books) {
            books = decodedBooks
        }

        if let decodedPlaylists = try? values.decode([Int: Folder].self, forKey: .playlists) {
            playlists = decodedPlaylists
        }

        let unsortedItemsDict: [Int: LibraryItem] = books.merging(playlists) { (_, new) -> LibraryItem in new }
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
