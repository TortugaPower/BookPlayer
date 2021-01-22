//
//  Playlist+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

@objc(Playlist)
public class Playlist: LibraryItem {
    var cachedDuration: Double?
    var cachedProgress: Double?
    // MARK: - Properties

    public override var artwork: UIImage {
        guard let books = self.books?.array as? [Book], let book = books.first(where: { (book) -> Bool in
            !book.usesDefaultArtwork
        }) else {
            return UIImage(named: "defaultArtwork")!
        }

        return book.artwork
    }

    public override func jumpToStart() {
        self.resetCachedProgress()
        guard let books = self.books?.array as? [Book] else { return }

        for book in books {
            book.currentTime = 0
        }
    }

    public override func markAsFinished(_ flag: Bool) {
        self.resetCachedProgress()
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
        self.identifier = "\(title)\(Date().timeIntervalSince1970)"
        self.title = title
        self.originalFileName = title
        self.desc = "\(books.count) \("files_title".localized)"
        self.addToBooks(NSOrderedSet(array: books))
    }

    // MARK: - Methods
    
    public func resetCachedProgress() {
        self.cachedProgress = nil
        self.cachedDuration = nil
    }

    func totalDuration() -> Double {
        guard let books = self.books?.array as? [Book] else {
            return 0.0
        }

        let totalDuration = books.reduce(0.0, {$0 + $1.duration})

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalDuration
    }
    
    public func calculateProgressAndDuration() -> (progress: Double, duration: Double) {
        if let cachedProgress = self.cachedProgress,
           let cachedDuration = self.cachedDuration {
            return (cachedProgress, cachedDuration)
        }

        guard let books = self.books?.array as? [Book] else {
            return (0.0, 0.0)
        }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for book in books {
            totalDuration += book.duration
            totalProgress += book.isFinished
                ? book.duration
                : book.currentTime
        }
        
        self.cachedProgress = totalProgress
        self.cachedDuration = totalDuration

        guard totalDuration > 0 else {
            return (0.0, 0.0)
        }

        return (totalProgress, totalDuration)
    }

    public override var progress: Double {
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

    public func updateCompletionState() {
        self.resetCachedProgress()
        guard let books = self.books?.array as? [Book] else { return }

        self.isFinished = !books.contains(where: { !$0.isFinished })
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

        return books.firstIndex { (storedBook) -> Bool in
            storedBook.identifier == identifier
        }
    }

    public func getBook(at index: Int) -> Book? {
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

    public override func getBookToPlay() -> Book? {
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
            guard index > indexFound else { continue }

            if book.isFinished {
                book.currentTime = 0
            }

            return book
        }

        return nil
    }

    public override func info() -> String {
        let count = self.books?.array.count ?? 0

        return "\(count) \("files_title".localized)"
    }

    enum CodingKeys: String, CodingKey {
        case title, desc, books, library
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(desc, forKey: .desc)

        if let booksArray = self.books?.array as? [Book] {
            try container.encode(booksArray, forKey: .books)
        }
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "Playlist", in: managedObjectContext) else {
            fatalError("Failed to decode Playlist!")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        desc = try values.decode(String.self, forKey: .desc)
        let booksArray = try values.decode([Book].self, forKey: .books)
        books = NSOrderedSet(array: booksArray)
    }
}

extension Playlist: Sortable {
    public func sort(by sortType: PlayListSortOrder) {
        guard let books = books else { return }
        self.books = BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
