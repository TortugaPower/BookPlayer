//
//  Playlist+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

public class Playlist: LibraryItem {
    // MARK: - Properties

    override var artwork: UIImage {
        guard let books = self.books?.array as? [Book], let book = books.first(where: { (book) -> Bool in
            return !book.usesDefaultArtwork
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
        identifier = title
        self.title = title
        desc = "\(books.count) Files"
        addToBooks(NSOrderedSet(array: books))
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

    func totalProgress() -> Double {
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

    func hasBooks() -> Bool {
        guard let books = self.books else {
            return false
        }

        return books.count > 0
    }

    func itemIndex(with url: URL) -> Int? {
        let hash = url.lastPathComponent

        return self.itemIndex(with: hash)
    }

    func itemIndex(with identifier: String) -> Int? {
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

    override func getBookToPlay() -> Book? {
        guard
            let books = self.books?.array as? [Book],
            let firstUnfinishedBook = books.first(where: { !$0.isCompleted })
            else { return nil }

        return firstUnfinishedBook
    }

    func getNextBook(after book: Book) -> Book? {
        guard let books = self.books?.array as? [Book] else { return nil }

        if let index = books.firstIndex(of: book), index + 1 <= books.count {
            return books[index + 1]
        }

        return nil
    }

    func info() -> String {
        let count = self.books?.array.count ?? 0

        return "\(count) Files"
    }
}
