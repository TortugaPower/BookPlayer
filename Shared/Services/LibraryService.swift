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
  func getLibrary() -> Library
  func getLibraryLastBook() throws -> Book?

  func getLibraryCurrentTheme() throws -> Theme?
  func getTheme(with title: String) -> Theme?
  func setLibraryTheme(with title: String)
  func setLibraryLastBook(with relativePath: String?)
  func createTheme(params: [String: Any]) -> Theme

  func createBook(from url: URL) -> Book
  func getItem(with relativePath: String) -> LibraryItem?
  func findBooks(containing fileURL: URL) -> [Book]?
  func getOrderedBooks(limit: Int?) -> [Book]?
  func findFolder(with fileURL: URL) -> Folder?
  func findFolder(with relativePath: String) -> Folder?
  func hasLibraryLinked(item: LibraryItem) -> Bool
  func createFolder(with title: String, inside relativePath: String?) throws -> Folder
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [LibraryItem]?
  func getMaxItemsCount(at relativePath: String?) -> Int
  func replaceOrderedItems(_ items: NSOrderedSet, at relativePath: String?)
  func reorderItem(at relativePath: String, inside folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath)

  func updatePlaybackTime(relativePath: String, time: Double)
  func updateBookSpeed(at relativePath: String, speed: Float)
  func updateBookLastPlayDate(at relativePath: String, date: Date)
  func markAsFinished(flag: Bool, relativePath: String)
  func jumpToStart(relativePath: String)
  func getCurrentPlaybackRecord() -> PlaybackRecord
  func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]?
  func recordTime(_ playbackRecord: PlaybackRecord)

  func getBookmarks(of type: BookmarkType, relativePath: String) -> [Bookmark]?
  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark?
  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark
  func addNote(_ note: String, bookmark: Bookmark)
  func deleteBookmark(_ bookmark: Bookmark)

  func renameItem(at relativePath: String, with newTitle: String)

  func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]?) -> [LibraryItem]
  func handleDirectory(item: URL, folder: Folder, library: Library)
  func moveItems(_ items: [LibraryItem], inside relativePath: String?, moveFiles: Bool) throws
  func delete(_ items: [LibraryItem], library: Library, mode: DeleteMode) throws
  func delete(_ item: LibraryItem, library: Library, mode: DeleteMode) throws
}

public final class LibraryService: LibraryServiceProtocol {
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
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

  public func setLibraryLastBook(with relativePath: String?) {
    let library = self.getLibrary()

    if let relativePath = relativePath {
      library.lastPlayedBook = self.getItem(with: relativePath) as? Book
    } else {
      library.lastPlayedBook = nil
    }

    self.dataManager.saveContext()
  }

  public func createTheme(params: [String: Any]) -> Theme {
    let newTheme = Theme(params: params, context: self.dataManager.getContext())
    self.dataManager.saveContext()
    return newTheme
  }

  public func createBook(from url: URL) -> Book {
    let newBook = Book(from: url, context: self.dataManager.getContext())
    self.dataManager.saveContext()
    return newBook
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

  public func createFolder(with title: String, inside relativePath: String?) throws -> Folder {
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
      folder.insert(item: newFolder)
    } else {
      let library = self.getLibrary()
      library.insert(item: newFolder)
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

  public func getMaxItemsCount(at relativePath: String?) -> Int {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }

    return (try? self.dataManager.getContext().count(for: fetchRequest)) ?? 0
  }

  public func replaceOrderedItems(_ items: NSOrderedSet, at relativePath: String?) {
    if let relativePath = relativePath,
       let folder = self.getItem(with: relativePath) as? Folder {
      folder.items = items
      folder.rebuildOrderRank()
    } else {
      let library = self.getLibrary()
      library.items = items
      library.rebuildOrderRank()
    }

    self.dataManager.saveContext()
  }

  public func reorderItem(
    at relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  ) {
    guard let storedItem = self.getItem(with: relativePath) else { return }

    if let folderRelativePath = folderRelativePath,
       let folder = self.getItem(with: folderRelativePath) as? Folder {
      folder.removeFromItems(at: sourceIndexPath.row)
      folder.insertIntoItems(storedItem, at: destinationIndexPath.row)
      folder.rebuildOrderRank()
    } else {
      let library = self.getLibrary()
      library.removeFromItems(at: sourceIndexPath.row)
      library.insertIntoItems(storedItem, at: destinationIndexPath.row)
      library.rebuildOrderRank()
    }

    self.dataManager.saveContext()
  }

  public func updatePlaybackTime(relativePath: String, time: Double) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.currentTime = time
    item.percentCompleted = round((item.currentTime / item.duration) * 100)

    self.dataManager.saveContext()
  }

  public func updateBookSpeed(at relativePath: String, speed: Float) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.speed = speed
    item.folder?.speed = speed

    self.dataManager.saveContext()
  }

  public func updateBookLastPlayDate(at relativePath: String, date: Date) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.lastPlayDate = date
    item.folder?.lastPlayDate = date

    self.dataManager.saveContext()
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

  public func getBookmarks(of type: BookmarkType, relativePath: String) -> [Bookmark]? {
    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d",
                                         #keyPath(Bookmark.book.relativePath),
                                         relativePath,
                                         type.rawValue)

    return try? self.dataManager.getContext().fetch(fetchRequest)
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

  public func renameItem(at relativePath: String, with newTitle: String) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.title = newTitle

    self.dataManager.saveContext()
  }

  // This handles the Core Data objects creation from the Import operation
  // This method doesn't handle moving files on disk, only creating the core data structure for a given file tree
  public func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]?) -> [LibraryItem] {
    guard !files.isEmpty else {
      self.dataManager.saveContext()
      return processedItems ?? []
    }

    var remainingFiles = files
    var resultingFiles = processedItems

    let nextFile = remainingFiles.removeFirst()
    let context = self.dataManager.getContext()

    let libraryItem: LibraryItem

    if let attributes = try? FileManager.default.attributesOfItem(atPath: nextFile.path),
       let type = attributes[.type] as? FileAttributeType,
       type == .typeDirectory {
      let folder = Folder(from: nextFile, context: context)
      self.handleDirectory(item: nextFile, folder: folder, library: library)
      libraryItem = folder
    } else {
      libraryItem = Book(from: nextFile, context: context)
    }

    if let folder = folder {
      folder.insert(item: libraryItem)
    } else {
      library.insert(item: libraryItem)
    }

    resultingFiles?.append(libraryItem)

    return self.insertItems(from: remainingFiles, into: folder, library: library, processedItems: resultingFiles)
  }

  public func handleDirectory(item: URL, folder: Folder, library: Library) {
    let enumerator = FileManager.default.enumerator(
      at: item,
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    _ = self.insertItems(from: files, into: folder, library: library, processedItems: [])
  }

  public func moveItems(_ items: [LibraryItem], inside relativePath: String?, moveFiles: Bool) throws {
    let processedFolderURL = DataManager.getProcessedFolderURL()

    var folder: Folder?
    var library: Library?

    // insert into existing folder or library at index
    if let relativePath = relativePath {
      // The folder object must exist
      folder = self.findFolder(with: relativePath)!
    } else {
      library = self.getLibrary()
    }

    for item in items {
      if moveFiles {
        let sourceUrl = processedFolderURL
          .appendingPathComponent(item.relativePath)
        let destinationUrl: URL

        if let folder = folder {
          destinationUrl = processedFolderURL
            .appendingPathComponent(folder.relativePath)
            .appendingPathComponent(item.originalFileName)
        } else {
          destinationUrl = processedFolderURL
            .appendingPathComponent(item.originalFileName)
        }

        try FileManager.default.moveItem(
          at: sourceUrl,
          to: destinationUrl
        )
      }

      if let folder = folder {
        folder.insert(item: item)
      } else {
        library?.insert(item: item)
      }
    }

    if let folder = folder {
      folder.updateCompletionState()
    }

    self.dataManager.saveContext()
  }

  public func delete(_ items: [LibraryItem], library: Library, mode: DeleteMode) throws {
    for item in items {
      guard let folder = item as? Folder else {
        // swiftlint:disable force_cast
        try self.delete(item as! Book, library: library, mode: mode)
        // swiftlint:enable force_cast
        continue
      }

      try self.delete(folder, library: library, mode: mode)
    }
  }

  public func delete(_ folder: Folder, library: Library, mode: DeleteMode) throws {

    if mode == .shallow,
       let items = folder.items?.array as? [LibraryItem] {
      for item in items {
        guard let fileURL = item.fileURL else { continue }

        if let parent = folder.folder {
          if let parentURL = parent.fileURL {
            try FileManager.default.moveItem(
              at: fileURL,
              to: parentURL.appendingPathComponent(fileURL.lastPathComponent)
            )
          }
          parent.insert(item: item)
        } else {
          try FileManager.default.moveItem(
            at: fileURL,
            to: DataManager.getProcessedFolderURL().appendingPathComponent(fileURL.lastPathComponent)
          )
          library.insert(item: item)
        }
      }
    }

    // swiftlint:disable force_cast
    for item in folder.items?.array as! [LibraryItem] {
      // swiftlint:enable force_cast
      guard mode == .deep else { continue }
      try self.delete(item, library: library, mode: .deep)
    }

    library.removeFromItems(folder)

    if let folderURL = folder.fileURL {
      if FileManager.default.fileExists(atPath: folderURL.path) {
        try FileManager.default.removeItem(at: folderURL)
      }
    }

    self.dataManager.delete(folder)
  }

  public func delete(_ item: LibraryItem, library: Library, mode: DeleteMode) throws {
    guard mode == .deep else {
      if item.folder != nil {
        library.insert(item: item)
        self.dataManager.saveContext()
      }

      return
    }

    if let book = item as? Book {
      if let fileURL = book.fileURL {
        if FileManager.default.fileExists(atPath: fileURL.path) {
          try FileManager.default.removeItem(at: fileURL)
        }
      }
    }

    self.dataManager.delete(item)
  }
}
