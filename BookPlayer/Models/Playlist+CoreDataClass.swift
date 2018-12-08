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

    // MARK: - Init

    convenience init(title: String, books: [Book], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: context)!
        self.init(entity: entity, insertInto: context)
        self.identifier = title
        self.title = title
        self.originalFileName = title
        self.desc = "\(books.count) Files"
        self.isComplete = false
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

    func totalProgress() -> Double {
        guard let books = self.books?.array as? [Book] else {
            return 0.0
        }

        if isComplete { return 1.0 }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for book in books {
            totalDuration += book.duration
            totalProgress += book.isComplete ? book.duration : book.currentTime
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
        guard let books = self.books else { return nil }

        for item in books {
            guard let book = item as? Book, !book.isComplete else { continue }

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

    func info() -> String {
        let count = self.books?.array.count ?? 0

        return "\(count) Files"
    }

    public override func setCompletionState(isComplete: Bool = true) {
        books?.forEach { book in
            guard let book = book as? Book else { return }
            book.setCompletionState(isComplete: isComplete)
        }
    }

    // Need a solution for when a book is notified to notify the enclosing
    // playlist of the change but also any associated view. Initing
    // the notification in the playlist init is useless since its only inited once

    public func registerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookDidUpdate(_:)), name: .updateBookCompletion, object: nil)
    }

    @objc private func bookDidUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book,
            let bookSet = books,
            let books = Array(bookSet) as? [Book] else { return }

        if books.contains(book) && self.allBooksComplete() {
            self.setCompletionState()
            NotificationCenter.default.post(name: .updatePlaylistCompletion, object: nil, userInfo: ["playlist": self])
        }
    }

    public func allBooksComplete() -> Bool {
        guard let books = books else { return false }
        return !books.contains(where: { (book) -> Bool in
            guard let book = book as? Book else { return false }
            return book.isComplete
        })
    }
}

extension Playlist: Sortable {
    func sort(by sortType: PlayListSortOrder) throws {
        guard let books = books else { return }
        self.books = try BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
