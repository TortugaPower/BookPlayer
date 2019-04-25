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
public class Library: NSManagedObject {
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
        guard let items = self.items?.array as? [LibraryItem] else { return nil }

        guard let indexFound = items.firstIndex(of: item) else { return nil }

        for (index, item) in items.enumerated() {
            guard index > indexFound,
                !item.isFinished else { continue }

            if let playlist = item as? Playlist, !playlist.hasBooks() { continue }

            return item
        }

        return nil
    }
}

extension Library: Sortable {
    public func sort(by sortType: PlayListSortOrder) {
        guard let items = items else { return }
        self.items = BookSortService.sort(items, by: sortType)
        DataManager.saveContext()
    }
}
