//
//  LibraryService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/21/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public protocol LibraryServiceProtocol {
  func saveContext()
  func getLibrary() -> Library
  func getLibraryLastBook() throws -> Book?

  func getLibraryCurrentTheme() throws -> Theme?
  func getTheme(with title: String) -> Theme?
  func setLibraryTheme(with title: String)
  func createTheme(params: [String: Any]) -> Theme

  func getItem(with relativePath: String) -> LibraryItem?
  func findBooks(containing fileURL: URL) -> [Book]?
  func getOrderedBooks(limit: Int?) -> [Book]?
  func findFolder(with fileURL: URL) -> Folder?
  func findFolder(with relativePath: String) -> Folder?
  func hasLibraryLinked(item: LibraryItem) -> Bool
  func createFolder(with title: String, inside relativePath: String?, at index: Int?) throws -> Folder
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [LibraryItem]?
  func markAsFinished(flag: Bool, relativePath: String)
  func jumpToStart(relativePath: String)
  func getCurrentPlaybackRecord() -> PlaybackRecord
  func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]?
  func recordTime(_ playbackRecord: PlaybackRecord)

  func getBookmark(of type: BookmarkType, relativePath: String) -> Bookmark?
  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark?
  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark
  func addNote(_ note: String, bookmark: Bookmark)
  func deleteBookmark(_ bookmark: Bookmark)
}

public final class LibraryService: LibraryServiceProtocol {
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
  }

  public func saveContext() {
    self.dataManager.saveContext()
  }

  /**
   Gets the library for the App. There should be only one Library object at all times
   */
  public func getLibrary() -> Library {
    let context = self.dataManager.getContext()
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.returnsObjectsAsFaults = false

    return (try? context.fetch(fetch).first) ?? self.createLibrary()
  }

  func createLibrary() -> Library {
    let context = self.dataManager.getContext()
    let library = Library.create(in: context)
    self.dataManager.saveContext()
    return library
  }

  public func getLibraryLastBook() throws -> Book? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["lastPlayedBook"]
    fetchRequest.resultType = .dictionaryResultType

    guard let dict = try context.fetch(fetchRequest).first as? [String: NSManagedObjectID],
          let lastPlayedBookId = dict["lastPlayedBook"] else {
            return nil
          }

    return try? context.existingObject(with: lastPlayedBookId) as? Book
  }

  public func getLibraryCurrentTheme() throws -> Theme? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["currentTheme"]
    fetchRequest.resultType = .dictionaryResultType

    guard let dict = try context.fetch(fetchRequest).first as? [String: NSManagedObjectID],
          let themeId = dict["currentTheme"] else {
            return self.getTheme(with: "Default / Dark")
          }

    return try? context.existingObject(with: themeId) as? Theme
  }

  public func getTheme(with title: String) -> Theme? {
    let fetchRequest: NSFetchRequest<Theme> = Theme.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "title == %@", title)
    fetchRequest.fetchLimit = 1

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func setLibraryTheme(with title: String) {
    guard let theme = self.getTheme(with: title) else { return }
    let library = self.getLibrary()
    library.currentTheme = theme
    self.dataManager.saveContext()
  }

  public func createTheme(params: [String: Any]) -> Theme {
    let newTheme = Theme(params: params, context: self.dataManager.getContext())
    self.dataManager.saveContext()
    return newTheme
  }

  public func getItem(with relativePath: String) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func findBooks(containing fileURL: URL) -> [Book]? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "relativePath ENDSWITH[C] %@", fileURL.lastPathComponent)
    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  public func getOrderedBooks(limit: Int?) -> [Book]? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "lastPlayDate != nil")

    if let limit = limit {
      fetch.fetchLimit = limit
    }

    let sort = NSSortDescriptor(key: #keyPath(Book.lastPlayDate), ascending: false)
    fetch.sortDescriptors = [sort]

    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  // MARK: - Folders
  public func findFolder(with fileURL: URL) -> Folder? {
    return self.findFolder(
      with: String(fileURL.relativePath(to: DataManager.getProcessedFolderURL()).dropFirst())
    )
  }

  public func findFolder(with relativePath: String) -> Folder? {
    let fetch: NSFetchRequest<Folder> = Folder.fetchRequest()

    fetch.predicate = NSPredicate(format: "relativePath == %@", relativePath)

    return try? self.dataManager.getContext().fetch(fetch).first
  }

  public func hasLibraryLinked(item: LibraryItem) -> Bool {

    var keyPath = item.relativePath.split(separator: "/")
      .dropLast()
      .map({ _ in return "folder" })
      .joined(separator: ".")

    keyPath += keyPath.isEmpty ? "library" : ".library"

    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()

    fetchRequest.predicate = NSPredicate(format: "relativePath == %@ && \(keyPath) != nil", item.relativePath)

    return (try? self.dataManager.getContext().fetch(fetchRequest).first) != nil
  }

  func removeFolderIfNeeded(_ fileURL: URL) throws {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

    // Delete folder if it belongs to an orphaned folder
    if let existingFolder = self.findFolder(with: fileURL) {
      if !self.hasLibraryLinked(item: existingFolder) {
        // Delete folder if it doesn't belong to active folder
        try FileManager.default.removeItem(at: fileURL)
        self.dataManager.delete(existingFolder)
      }
    } else {
      // Delete folder if it doesn't belong to active folder
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  public func createFolder(with title: String, inside relativePath: String?, at index: Int?) throws -> Folder {
    let processedFolder = DataManager.getProcessedFolderURL()
    let destinationURL: URL

    if let relativePath = relativePath {
      destinationURL = processedFolder.appendingPathComponent(relativePath).appendingPathComponent(title)
    } else {
      destinationURL = processedFolder.appendingPathComponent(title)
    }

    try? removeFolderIfNeeded(destinationURL)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false, attributes: nil)

    let newFolder = Folder(title: title, context: self.dataManager.getContext())

    // insert into existing folder or library at index
    if let relativePath = relativePath {
      // The folder object must exist
      let folder = self.findFolder(with: relativePath)!
      folder.insert(item: newFolder, at: index)
    } else {
      let library = self.getLibrary()
      library.insert(item: newFolder, at: index)
    }

    self.dataManager.saveContext()

    return newFolder
  }

  public func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }

    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)
    fetchRequest.sortDescriptors = [sort]

    if let limit = limit {
      fetchRequest.fetchLimit = limit
    }

    if let offset = offset {
      fetchRequest.fetchOffset = offset
    }

    return try? self.dataManager.getContext().fetch(fetchRequest)
  }

  public func markAsFinished(flag: Bool, relativePath: String) {
    guard let item = self.getItem(with: relativePath) else { return }

    switch item {
    case let folder as Folder:
      self.markAsFinished(flag: flag, folder: folder)
    case let book as Book:
      self.markAsFinished(flag: flag, book: book)
    default:
      break
    }
  }

  func markAsFinished(flag: Bool, book: Book) {
    book.isFinished = flag
    // To avoid progress display side-effects
    if !flag,
       book.currentTime.rounded(.up) == book.duration.rounded(.up) {
      book.currentTime = 0.0
    }
    self.dataManager.saveContext()
  }

  func markAsFinished(flag: Bool, folder: Folder) {
    folder.isFinished = flag

    guard let items =  self.fetchContents(at: folder.relativePath, limit: nil, offset: nil) else { return }

    items.forEach({ self.markAsFinished(flag: flag, relativePath: $0.relativePath) })
  }

  public func jumpToStart(relativePath: String) {
    guard let item = self.getItem(with: relativePath) else { return }

    switch item {
    case let folder as Folder:
      self.jumpToStart(folder: folder)
    case let book as Book:
      self.jumpToStart(book: book)
    default:
      break
    }
  }

  func jumpToStart(book: Book) {
    book.currentTime = 0
    book.isFinished = false
    self.dataManager.saveContext()
  }

  func jumpToStart(folder: Folder) {
    guard let items =  self.fetchContents(at: folder.relativePath, limit: nil, offset: nil) else { return }

    items.forEach({ self.jumpToStart(relativePath: $0.relativePath) })
  }

  // MARK: - TimeRecord
  public func getCurrentPlaybackRecord() -> PlaybackRecord {
    let calendar = Calendar.current

    let today = Date()
    let dateFrom = calendar.startOfDay(for: today)
    let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)!

    let record = self.getPlaybackRecords(from: dateFrom, to: dateTo)?.first

    return record ?? PlaybackRecord.create(in: self.dataManager.getContext())
  }

  public func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]? {
    let fromPredicate = NSPredicate(format: "date >= %@", startDate as NSDate)
    let toPredicate = NSPredicate(format: "date < %@", endDate as NSDate)
    let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

    let fetch: NSFetchRequest<PlaybackRecord> = PlaybackRecord.fetchRequest()
    fetch.predicate = datePredicate
    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  public func recordTime(_ playbackRecord: PlaybackRecord) {
    playbackRecord.time += 1
    self.dataManager.saveContext()
  }

  // MARK: - Bookmarks

  public func getBookmark(of type: BookmarkType, relativePath: String) -> Bookmark? {
    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d",
                                         #keyPath(Bookmark.book.relativePath),
                                         relativePath,
                                         type.rawValue)

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark? {
    let time = floor(time)

    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d && time == %f",
                                         #keyPath(Bookmark.book.relativePath),
                                         relativePath,
                                         type.rawValue,
                                         floor(time))

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark {
    if let bookmark = self.getBookmark(at: time, relativePath: relativePath, type: type) {
      return bookmark
    }

    let bookmark = Bookmark(with: floor(time), type: type, context: self.dataManager.getContext())
    let book = self.getItem(with: relativePath) as? Book
    book?.addToBookmarks(bookmark)

    self.dataManager.saveContext()

    return bookmark
  }

  public func addNote(_ note: String, bookmark: Bookmark) {
    bookmark.note = note
    self.dataManager.saveContext()
  }

  public func deleteBookmark(_ bookmark: Bookmark) {
    let book = bookmark.book
    book?.removeFromBookmarks(bookmark)
    self.dataManager.delete(bookmark)
  }
}
