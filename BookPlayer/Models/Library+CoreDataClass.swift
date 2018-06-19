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
}
