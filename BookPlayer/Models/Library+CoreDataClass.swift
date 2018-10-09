//
//  LibraryCoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

public class Library: NSManagedObject {
    func itemIndex(with identifier: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        for (index, item) in items.enumerated() {
            if let storedBook = item as? Book,
                storedBook.identifier == identifier {
                return index
            }
            //check if playlist
            if let playlist = item as? Playlist,
                let storedBooks = playlist.books?.array as? [Book],
                storedBooks.contains(where: { (storedBook) -> Bool in
                    return storedBook.identifier == identifier
                }) {
                //check playlist books
                return index
            }
        }

        return nil
    }

    func itemIndex(with url: URL) -> Int? {
        let hash = url.lastPathComponent
        return self.itemIndex(with: hash)
    }

    func getItem(at index: Int) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items[index]
    }

    func getItem(with url: URL) -> LibraryItem? {
        guard let index = self.itemIndex(with: url) else {
            return nil
        }
        return self.getItem(at: index)
    }

    func getItem(with identifier: String) -> LibraryItem? {
        guard let index = self.itemIndex(with: identifier) else {
            return nil
        }
        return self.getItem(at: index)
    }

    func getItem(at indexPath: IndexPath) -> LibraryItem? {
        if indexPath.indices.count == 0 {
            return nil
        }

        guard let item = self.getItem(at: indexPath[0]) else {
            return nil
        }

        guard
            indexPath.indices.count == 2,
            let playlist = item as? Playlist,
            let book = playlist.getBook(at: indexPath[1])
            else {
                return item
        }

        return book
    }

    func queueItemsForPlayback(from startItem: LibraryItem, forceAutoplay: Bool = false) -> [Book] {
        var books = [Book]()

        let shouldAutoplayLibrary = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
        let shouldAutoplay = shouldAutoplayLibrary || forceAutoplay

        if let playlist = startItem as? Playlist {
            books.append(contentsOf: playlist.getRemainingBooks())
        }

        var selectedItem = startItem

        if let book = selectedItem as? Book {
            books.append(book)

            if let playlist = book.playlist {
                selectedItem = playlist
            }
        }

        guard
            shouldAutoplay,
            let items = self.items?.array as? [LibraryItem],
            let remainingItems = items.split(whereSeparator: { $0 == selectedItem }).last
            else {
                return books
        }

        for item in remainingItems {
            if let playlist = item as? Playlist {
                books.append(contentsOf: playlist.getRemainingBooks())
            } else if let book = item as? Book, !book.isCompleted {
                books.append(book)
            }
        }

        return books
    }
}
