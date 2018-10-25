//
//  Library+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

@objc(Library)
public class Library: NSManagedObject, Codable {
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
                let playlist = item as? Playlist,
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
        guard let items = self.items else { return nil }

        let index = items.index(of: item)

        if index + 1 < items.count {
            return items[index + 1] as? LibraryItem
        }

        return nil
    }

    enum CodingKeys: String, CodingKey {
        case items, books, playlists
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        guard let itemsArray = self.items?.array as? [LibraryItem] else { return }

        let books = itemsArray.filter { (item) -> Bool in
            return item is Book
        }

        let playlists = itemsArray.filter { (item) -> Bool in
            return item is Playlist
        }

        if let books = books as? [Book], !books.isEmpty {
            try container.encode(books, forKey: .books)
        }

        if let playlists = playlists as? [Playlist], !playlists.isEmpty {
            try container.encode(playlists, forKey: .playlists)
        }
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

        var books = [Book]()
        var playlists = [Playlist]()
        do {
            books = try values.decode(Array<Book>.self, forKey: .books)
            playlists = try values.decode(Array<Playlist>.self, forKey: .playlists)
        } catch {
            print(error)
        }

        var derp: [LibraryItem] = books
        derp.append(contentsOf: playlists)
        items = NSOrderedSet(array: derp)
    }
}

extension Library: Sortable {
    func sort(by sortType: PlayListSortOrder) throws {
        guard let items = items else { return }
        self.items = try BookSortService.sort(items, by: sortType)
        DataManager.saveContext()
    }
}
