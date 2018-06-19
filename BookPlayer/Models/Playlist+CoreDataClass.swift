//
//  Playlist+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import UIKit

public class Playlist: LibraryItem {
    override var artwork: UIImage {
        guard let books = self.books?.array as? [Book], let book = books.first(where: { (book) -> Bool in
            return !book.usesDefaultArtwork
        }) else {
            return #imageLiteral(resourceName: "defaultPlaylist")
        }

        return book.artwork
    }

    func totalPercentage() -> Double {
        guard let books = self.books?.array as? [Book] else {
            return 0.0
        }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for book in books {
            totalDuration += book.duration
            totalProgress += book.currentTime
        }

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalProgress / totalDuration
    }

    func getRemainingBooks() -> [Book] {
        guard
            let books = self.books?.array as? [Book], let firstUnfinishedBook = books.first(where: { (book) -> Bool in
                return round(book.currentTime) < round(book.duration)
            }),
            let count = books.index(of: firstUnfinishedBook),
            let slice = self.books?.array.dropFirst(count),
            let remainingBooks = Array(slice) as? [Book]
        else {
            return []
        }

        return remainingBooks
    }

    func itemIndex(with url: URL) -> Int? {
        let hash = url.lastPathComponent

        return itemIndex(with: hash)
    }

    func itemIndex(with identifier: String) -> Int? {
        guard let books = self.books?.array as? [Book] else {
            return nil
        }

        return books.index { (storedBook) -> Bool in
            return storedBook.identifier == identifier
        }
    }

    func getBook(at index: Int) -> Book? {
        guard let books = self.books?.array as? [Book] else {
            return nil
        }

        return books[index]
    }

    func getBook(with url: URL) -> Book? {
        guard let index = self.itemIndex(with: url) else {
            return nil
        }
        return self.getBook(at: index)
    }

    func getBook(with identifier: String) -> Book? {
        guard let index = self.itemIndex(with: identifier) else {
            return nil
        }
        return self.getBook(at: index)
    }

    func info() -> String {
        let count = self.books?.array.count ?? 0
        return "\(count) Files"
    }

    convenience init(title: String, books: [Book], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)!
        self.init(entity: entity, insertInto: context)
        self.identifier = title
        self.title = title
        self.desc = "\(books.count) Files"
        self.addToBooks(NSOrderedSet(array: books))
    }
}
