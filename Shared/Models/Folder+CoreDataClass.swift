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

@objc(Folder)
public class Folder: LibraryItem {
    var cachedDuration: Double?
    var cachedProgress: Double?

//    var desc: String!
    // MARK: - Properties

    public override func getArtwork(for theme: Theme?) -> UIImage? {
        if let cachedArtwork = self.cachedArtwork {
            return cachedArtwork
        }

        guard let itemsArray = self.items?.array as? [LibraryItem] else {
            #if os(iOS)
            self.cachedArtwork = DefaultArtworkFactory.generateArtwork(from: theme?.linkColor)
            #endif

            return self.cachedArtwork
        }

        let item = itemsArray.first { (item) -> Bool in
            if let book = item as? Book {
                return !book.usesDefaultArtwork
            }
            guard let folder = item as? Folder else { return true }

            return folder.getFirstBookWithArtwork() != nil
        }

        var book = item as? Book

        if let folder = item as? Folder {
            book = folder.getFirstBookWithArtwork()
        }

        self.cachedArtwork = book?.getArtwork(for: theme)
        return self.cachedArtwork
    }

    public override func jumpToStart() {
        self.resetCachedProgress()
        guard let items = self.items?.array as? [LibraryItem] else { return }

        for item in items {
            if let book = item as? Book {
                book.currentTime = 0
            } else if let folder = item as? Folder {
                folder.jumpToStart()
            }
        }
    }

    public override func markAsFinished(_ flag: Bool) {
        self.resetCachedProgress()
        guard let items = self.items?.array as? [LibraryItem] else { return }

        for item in items {
            if let book = item as? Book {
                book.isFinished = flag
            } else if let folder = item as? Folder {
                folder.markAsFinished(flag)
            }
        }

        self.isFinished = flag
    }

    // MARK: - Init

    convenience init(title: String, books: [Book], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!

        self.init(entity: entity, insertInto: context)
        self.identifier = "\(title)\(Date().timeIntervalSince1970)"
        self.title = title
        self.originalFileName = title
        self.desc = "\(books.count) \("files_title".localized)"
        self.addToItems(NSOrderedSet(array: books))
    }

    convenience init(from url: URL, books: [Book], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!

        let title = url.lastPathComponent
        self.init(entity: entity, insertInto: context)

        self.identifier = UUID().uuidString
        self.title = title
        self.originalFileName = title
        self.desc = "\(books.count) \("files_title".localized)"
//        self.path = ""
        self.addToItems(NSOrderedSet(array: books))
        // swiftlint:disable force_try
        try! url.setAppIdentifier(self.identifier)
    }

    // MARK: - Methods

    public func resetCachedProgress() {
        self.cachedProgress = nil
        self.cachedDuration = nil
    }

    func totalDuration() -> Double {
        guard let items = self.items?.array as? [LibraryItem] else {
            return 0.0
        }

        let totalDuration = items.reduce(0.0, {$0 + $1.duration})

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalDuration
    }

    public override var duration: Double {
        get {
            let itemTime = self.getProgressAndDuration()
            return itemTime.duration
        }
        set {
            super.duration = newValue
        }
    }

    public override var progress: Double {
        let itemTime = self.getProgressAndDuration()

        return itemTime.progress / itemTime.duration
    }

    public func getProgressAndDuration() -> (progress: Double, duration: Double) {
        if let cachedProgress = self.cachedProgress,
           let cachedDuration = self.cachedDuration {
            return (cachedProgress, cachedDuration)
        }

        guard let items = self.items?.array as? [LibraryItem] else {
            return (0.0, 0.0)
        }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for item in items {
            totalDuration += item.duration
            totalProgress += item.isFinished
                ? item.duration
                : item.currentTime
        }

        self.cachedProgress = totalProgress
        self.cachedDuration = totalDuration

        guard totalDuration > 0 else {
            return (0.0, 0.0)
        }

        return (totalProgress, totalDuration)
    }

    public func updateCompletionState() {
        self.resetCachedProgress()
        guard let items = self.items?.array as? [LibraryItem] else { return }

        self.isFinished = !items.contains(where: { !$0.isFinished })
    }

    public func hasBooks() -> Bool {
        guard let books = self.items else {
            return false
        }

        return books.count > 0
    }

    public override func setCurrentTime(_ time: Double) {
        guard let items = self.items?.array as? [LibraryItem] else { return }

        for item in items {
            item.setCurrentTime(time)
        }
    }

    override public func getItem(with identifier: String) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        var itemFound: LibraryItem?

        for item in items {
            if let libraryItem = item.getItem(with: identifier) {
                itemFound = libraryItem
                break
            }
        }

        return itemFound
    }

    public func itemIndex(with identifier: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items.firstIndex { (item) -> Bool in
            if let book = item as? Book {
                return book.identifier == identifier
            } else if let folder = item as? Folder {
                return folder.getItem(with: identifier) != nil
            }

            return false
        }
    }

    public func getFirstBookWithArtwork() -> Book? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        let item = items.first { (item) -> Bool in
            if let book = item as? Book {
                return !book.usesDefaultArtwork
            }
            guard let folder = item as? Folder else { return true }

            return folder.getFirstBookWithArtwork() != nil
        }

        var book = item as? Book

        if let folder = item as? Folder {
            book = folder.getFirstBookWithArtwork()
        }

        return book
    }

    public func getBook(at index: Int) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items[index]
    }

    public override func getBookToPlay() -> Book? {
        guard let books = self.items else { return nil }

        for item in books {
            if let book = item as? Book,
               !book.isFinished {
                return book
            } else if let folder = item as? Folder {
                return folder.getBookToPlay()
            }
        }

        return nil
    }

    func getNextBook(after book: Book) -> Book? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        guard let indexFound = items.firstIndex(of: book) else {
            return nil
        }

        for (index, item) in items.enumerated() {
            guard index > indexFound else { continue }

            if item.isFinished {
                item.setCurrentTime(0.0)
            }

            if let book = item as? Book {
                return book
            } else if let folder = item as? Folder {
                return folder.getBookToPlay()
            }
        }

        return nil
    }

    public override func info() -> String {
        let count = self.items?.array.count ?? 0

        return "\(count) \("files_title".localized)"
    }

    enum CodingKeys: String, CodingKey {
        case title, desc, books, library
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(desc, forKey: .desc)

        if let itemsArray = self.items?.array as? [LibraryItem] {
            try container.encode(itemsArray, forKey: .books)
        }
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "Folder", in: managedObjectContext) else {
            fatalError("Failed to decode Folder!")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        title = try values.decode(String.self, forKey: .title)
        desc = try values.decode(String.self, forKey: .desc)
        let booksArray = try values.decode([Book].self, forKey: .books)
        items = NSOrderedSet(array: booksArray)
    }
}

extension Folder: Sortable {
    public func sort(by sortType: PlayListSortOrder) {
        guard let books = items else { return }
        self.items = BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
