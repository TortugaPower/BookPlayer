//
//  Playlist+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

@objc(Playlist)
public class Playlist: LibraryItem {
    override public var artwork: UIImage {
        guard let books = self.books?.array as? [Book], let book = books.first(where: { (book) -> Bool in
            !book.usesDefaultArtwork
        }) else {
            return #imageLiteral(resourceName: "defaultPlaylist")
        }

        return book.artwork
    }

    override var isCompleted: Bool {
        return round(self.totalProgress()) >= round(self.totalDuration())
    }

    // MARK: - Init

    convenience init(title: String, books: [Book], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)!

        self.init(entity: entity, insertInto: context)
        self.identifier = title
        self.title = title
        self.originalFileName = title
        self.desc = "\(books.count) Files"
        self.addToBooks(NSOrderedSet(array: books))
    }

    // MARK: - Methods

    func totalDuration() -> Double {
        guard let books = self.books?.array as? [Book] else {
            return 0.0
        }

        var totalDuration = 0.0

        for book in books {
            totalDuration += book.duration
        }

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalDuration
    }

    public func totalProgress() -> Double {
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

    public func hasBooks() -> Bool {
        guard let books = self.books else {
            return false
        }

        return books.count > 0
    }

    public func itemIndex(with url: URL) -> Int? {
        let hash = url.lastPathComponent

        return self.itemIndex(with: hash)
    }

    public func itemIndex(with identifier: String) -> Int? {
        guard let books = self.books?.array as? [Book] else {
            return nil
        }

        return books.index { (storedBook) -> Bool in
            storedBook.identifier == identifier
        }
    }

    func getBook(at index: Int) -> Book? {
        guard let books = self.books?.array as? [Book] else {
            return nil
        }

        return books[index]
    }

    public func getBook(with url: URL) -> Book? {
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

    override func getBookToPlay() -> Book? {
        guard let books = self.books else { return nil }

        for item in books {
            guard let book = item as? Book, !book.isCompleted else { continue }

            return book
        }

        return nil
    }

    func getNextBook(after book: Book) -> Book? {
        guard let books = self.books else {
            return nil
        }

        let index = books.index(of: book)

        guard
            index != NSNotFound,
            index + 1 < books.count,
            let nextBook = books[index + 1] as? Book
        else {
            return nil
        }

        return nextBook
    }

    public func info() -> String {
        let count = self.books?.array.count ?? 0

        return "\(count) Files"
    }
}

extension Playlist: Sortable {
    func sort(by sortType: PlayListSortOrder) throws {
        guard let books = books else { return }
        self.books = try BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
