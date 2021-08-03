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

    // MARK: - Properties

    public override func getArtwork(for theme: Theme?) -> UIImage? {
        if let cachedArtwork = self.cachedArtwork {
            return cachedArtwork
        }

        guard let book = self.getFirstBookWithArtwork() else {
            #if os(iOS)
            self.cachedArtwork = DefaultArtworkFactory.generateArtwork(from: theme?.linkColor)
            #endif

            return self.cachedArtwork
        }

        self.cachedArtwork = book.getArtwork(for: theme)
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

  public convenience init(title: String, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    self.identifier = "\(title)\(Date().timeIntervalSince1970)"
    self.relativePath = title
    self.title = title
    self.originalFileName = title
  }

  public convenience init(from fileURL: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    let fileTitle = fileURL.lastPathComponent
    self.identifier = "\(fileTitle)\(Date().timeIntervalSince1970)"
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    self.title = fileTitle
    self.originalFileName = fileTitle
  }

    // MARK: - Methods

    public func resetCachedProgress() {
        self.cachedProgress = nil
        self.cachedDuration = nil
        self.folder?.resetCachedProgress()
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

        return itemTime.progress
    }

    public override var progressPercentage: Double {
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
                : item.progress
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

  override public func index(for item: LibraryItem) -> Int? {
    guard let items = self.items?.array as? [LibraryItem] else {
      return nil
    }

    return items.firstIndex { (libraryItem) -> Bool in
      if let book = libraryItem as? Book {
        return book.relativePath == item.relativePath
      } else if let folder = libraryItem as? Folder {
        return folder.index(for: item) != nil
      }

      return false
    }
  }

    override public func getItem(with relativePath: String) -> LibraryItem? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        var itemFound: LibraryItem?

        for item in items {
            if let libraryItem = item.getItem(with: relativePath) {
                itemFound = libraryItem
                break
            }
        }

        return itemFound
    }

    public func itemIndex(with relativePath: String) -> Int? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        return items.firstIndex { (item) -> Bool in
            if let book = item as? Book {
                return book.relativePath == relativePath
            } else if let folder = item as? Folder {
                return folder.getItem(with: relativePath) != nil
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

    // Used for manual autoplay
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

    // Used for player autoplay
    func getNextBook(after book: Book) -> Book? {
        guard let items = self.items?.array as? [LibraryItem] else {
            return nil
        }

        guard let indexFound = self.itemIndex(with: book.relativePath) else {
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
                return folder.getNextBook(after: book)
            }
        }

        return nil
    }

    public func insert(item: LibraryItem, at index: Int? = nil) {
        if let parent = item.folder {
            parent.removeFromItems(item)
            parent.updateCompletionState()
        } else if let library = item.library {
            library.removeFromItems(item)
        }

        if let index = index {
            self.insertIntoItems(item, at: index)
        } else {
            self.addToItems(item)
        }

        self.rebuildRelativePaths(for: item)
    }

    public func rebuildRelativePaths(for item: LibraryItem) {
        item.relativePath = self.relativePathBuilder(for: item)

        if let folder = item as? Folder,
           let items = folder.items?.array as? [LibraryItem] {
            items.forEach({ folder.rebuildRelativePaths(for: $0) })
        }
    }

    public func relativePathBuilder(for item: LibraryItem) -> String {
        let itemRelativePath = item.relativePath.split(separator: "/").map({ String($0) }).last ?? item.relativePath

        return "\(self.relativePath!)/\(itemRelativePath!)"
    }

    public override func info() -> String {
        let count = self.items?.array.count ?? 0

        return "\(count) \("files_title".localized)"
    }

    enum CodingKeys: String, CodingKey {
        case title, desc, books, folders, library
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(desc, forKey: .desc)

        guard let itemsArray = self.items?.array as? [LibraryItem] else { return }

        var books = [Int: Book]()
        var folders = [Int: Folder]()

        for (index, item) in itemsArray.enumerated() {
            if let book = item as? Book {
                books[index] = book
            }
            if let folder = item as? Folder {
                folders[index] = folder
            }
        }

        if !books.isEmpty {
            try container.encode(books, forKey: .books)
        }

        if !folders.isEmpty {
            try container.encode(folders, forKey: .folders)
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

        var books = [Int: LibraryItem]()
        var folders = [Int: LibraryItem]()

        if let decodedBooks = try? values.decode([Int: Book].self, forKey: .books) {
            books = decodedBooks
        }

        if let decodedFolders = try? values.decode([Int: Folder].self, forKey: .folders) {
            folders = decodedFolders
        }

        let unsortedItemsDict: [Int: LibraryItem] = books.merging(folders) { (_, new) -> LibraryItem in new }
        let sortedItemsTuple = unsortedItemsDict.sorted { $0.key < $1.key }
        let sortedItems = Array(sortedItemsTuple.map { $0.value })

        items = NSOrderedSet(array: sortedItems)
    }
}

extension Folder: Sortable {
    public func sort(by sortType: PlayListSortOrder) {
        guard let books = items else { return }
        self.items = BookSortService.sort(books, by: sortType)
        DataManager.saveContext()
    }
}
