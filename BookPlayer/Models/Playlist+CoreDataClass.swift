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
            !book.usesDefaultArtwork
        }) else {
            return #imageLiteral(resourceName: "defaultPlaylist")
        }

        return book.artwork
    }

    override func jumpToStart() {
        guard let books = self.books?.array as? [Book] else { return }

        for book in books {
            book.currentTime = 0
        }
    }

    override func markAsFinished(_ flag: Bool) {
        guard let books = self.books?.array as? [Book] else { return }

        for book in books {
            book.isFinished = flag
        }

        self.isFinished = flag
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

    override var progress: Double {
        guard let books = self.books?.array as? [Book] else {
            return 0.0
        }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for book in books {
            totalDuration += book.duration
            totalProgress += book.isFinished
                ? book.duration
                : book.currentTime
        }

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalProgress / totalDuration
    }

    func updateCompletionState() {
        guard let books = self.books?.array as? [Book] else { return }
        print(!books.contains(where: { !$0.isFinished }))
        self.isFinished = !books.contains(where: { !$0.isFinished })
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

        return books.firstIndex { (storedBook) -> Bool in
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
        guard let books = self.books else { return nil }

        for item in books {
            guard let book = item as? Book, !book.isFinished else { continue }

            return book
        }

        return nil
    }

    func getNextBook(after book: Book) -> Book? {
        guard let books = self.books?.array as? [Book] else {
            return nil
        }

        guard let indexFound = books.firstIndex(of: book) else {
            return nil
        }

        for (index, book) in books.enumerated() {
            guard index > indexFound,
                !book.isFinished else { continue }

            return book
        }

        return nil
    }

    override func info() -> String {
        let count = self.books?.array.count ?? 0

        return "\(count) Files"
    }
}

extension Playlist: Sortable {
    func sort(by sortType: PlayListSortOrder) {
        guard let books = books else { return }
        self.books = BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
