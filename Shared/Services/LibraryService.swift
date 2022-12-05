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
  func getLibraryLastItem() throws -> LibraryItem?

  func getLibraryCurrentTheme() throws -> Theme?
  func getTheme(with title: String) -> Theme?
  func setLibraryTheme(with title: String)
  func setLibraryLastBook(with relativePath: String?)
  func createTheme(params: [String: Any]) -> Theme

  func createBook(from url: URL) -> Book
  func getChapters(from relativePath: String) -> [SimpleChapter]?
  func getItem(with relativePath: String) -> LibraryItem?
  func findBooks(containing fileURL: URL) -> [Book]?
  func getLastPlayedItems(limit: Int?) -> [LibraryItem]?
  func getItemProperty(_ property: String, relativePath: String) -> Any?
  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> LibraryItem?
  func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> LibraryItem?
  func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) -> LibraryItem?
  func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) -> [SimpleLibraryItem]?

  func updateFolder(at relativePath: String, type: SimpleItemType) throws
  func rebuildFolderDetails(_ relativePath: String)
  func recursiveFolderProgressUpdate(from relativePath: String)
  func findFolder(with fileURL: URL) -> Folder?
  func findFolder(with relativePath: String) -> Folder?
  func hasLibraryLinked(item: LibraryItem) -> Bool
  func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]?
  func getMaxItemsCount(at relativePath: String?) -> Int
  func sortContents(at relativePath: String?, by type: SortType)
  func reorderItem(at relativePath: String, inside folderRelativePath: String?, sourceIndexPath: IndexPath, destinationIndexPath: IndexPath)

  func updatePlaybackTime(relativePath: String, time: Double, date: Date)
  func updateBookSpeed(at relativePath: String, speed: Float)
  func getItemSpeed(at relativePath: String) -> Float
  func markAsFinished(flag: Bool, relativePath: String)
  func jumpToStart(relativePath: String)
  func getCurrentPlaybackRecord() -> PlaybackRecord
  func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]?
  func recordTime(_ playbackRecord: PlaybackRecord)
  func getTotalListenedTime() -> TimeInterval

  func getBookmarks(of type: BookmarkType, relativePath: String) -> [Bookmark]?
  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark?
  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark?
  func addNote(_ note: String, bookmark: Bookmark)
  func deleteBookmark(_ bookmark: Bookmark)

  func renameItem(at relativePath: String, with newTitle: String) throws

  func insertItems(from files: [URL], into folder: Folder?, library: Library, processedItems: [LibraryItem]?) -> [LibraryItem]
  func handleDirectory(item: URL, folder: Folder, library: Library)
  func moveItems(_ items: [LibraryItem], inside relativePath: String?, moveFiles: Bool) throws
  func delete(_ items: [LibraryItem], mode: DeleteMode) throws
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

  public func getLibraryLastItem() throws -> LibraryItem? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["lastPlayedItem"]
    fetchRequest.resultType = .dictionaryResultType

    guard let dict = try context.fetch(fetchRequest).first as? [String: NSManagedObjectID],
          let lastPlayedItemId = dict["lastPlayedItem"] else {
            return nil
          }

    return try? context.existingObject(with: lastPlayedItemId) as? LibraryItem
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
      library.lastPlayedItem = self.getItem(with: relativePath)
    } else {
      library.lastPlayedItem = nil
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

  public func getChapters(from relativePath: String) -> [SimpleChapter]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Chapter")
    fetchRequest.propertiesToFetch = ["title", "start", "duration", "index"]
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.predicate = NSPredicate(format: "%K == %@",
                                         #keyPath(Chapter.book.relativePath),
                                         relativePath)
    let sort = NSSortDescriptor(key: #keyPath(Chapter.index), ascending: true)
    fetchRequest.sortDescriptors = [sort]

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return results?.compactMap({ dictionary -> SimpleChapter? in
      guard
        let title = dictionary["title"] as? String,
        let start = dictionary["start"] as? Double,
        let duration = dictionary["duration"] as? Double,
        let index = dictionary["index"] as? Int16
      else { return nil }

      return SimpleChapter(
        title: title,
        start: start,
        duration: duration,
        index: index
      )
    })
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

  public func getLastPlayedItems(limit: Int?) -> [LibraryItem]? {
    let fetch: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetch.predicate = NSPredicate(format: "type != 0 && lastPlayDate != nil")

    if let limit = limit {
      fetch.fetchLimit = limit
    }

    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.lastPlayDate), ascending: false)
    fetch.sortDescriptors = [sort]

    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  public func getItemProperty(_ property: String, relativePath: String) -> Any? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = [property]
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(LibraryItem.relativePath),
      relativePath
    )
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.fetchLimit = 1

    let results = try? self.dataManager.getContext().fetch(fetchRequest).first as? [String: Any]

    return results?[property]
  }

  func findFirstItem(
    in parentFolder: String?,
    rankPredicate: NSPredicate?,
    sortAscending: Bool,
    isUnfinished: Bool?
  ) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()

    let pathPredicate: NSPredicate

    if let parentFolder = parentFolder {
      pathPredicate = NSPredicate(
        format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), parentFolder
      )
    } else {
      pathPredicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }

    var predicates = [
      pathPredicate
    ]

    if let rankPredicate = rankPredicate {
      predicates.append(rankPredicate)
    }

    if isUnfinished != nil {
      // TODO: Add default value for `isFinished`
      predicates.append(NSPredicate(
        format: "%K == 0 || %K == nil",
        #keyPath(LibraryItem.isFinished),
        #keyPath(LibraryItem.isFinished)
      ))
    }

    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: sortAscending)
    fetchRequest.sortDescriptors = [sort]
    fetchRequest.fetchLimit = 1

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> LibraryItem? {
    return findFirstItem(
      in: parentFolder,
      rankPredicate: nil,
      sortAscending: true,
      isUnfinished: isUnfinished
    )
  }

  public func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> LibraryItem? {
    var rankPredicate: NSPredicate?
    if let beforeRank = beforeRank {
      rankPredicate = NSPredicate(format: "%K < %d", #keyPath(LibraryItem.orderRank), beforeRank)
    }
    return findFirstItem(
      in: parentFolder,
      rankPredicate: rankPredicate,
      sortAscending: false,
      isUnfinished: nil
    )
  }

  public func findFirstItem(
    in parentFolder: String?,
    afterRank: Int16?,
    isUnfinished: Bool?
  ) -> LibraryItem? {
    var rankPredicate: NSPredicate?
    if let afterRank = afterRank {
      rankPredicate = NSPredicate(format: "%K > %d", #keyPath(LibraryItem.orderRank), afterRank)
    }
    return findFirstItem(
      in: parentFolder,
      rankPredicate: rankPredicate,
      sortAscending: true,
      isUnfinished: isUnfinished
    )
  }

  // MARK: - Folders
  public func updateFolder(at relativePath: String, type: SimpleItemType) throws {
    guard let folder = self.getItem(with: relativePath) as? Folder else {
      throw BookPlayerError.runtimeError("Can't find the folder")
    }

    switch type {
    case .folder:
      folder.type = .folder
      folder.lastPlayDate = nil
    case .bound:
      guard let items = folder.items?.array as? [Book] else {
        throw BookPlayerError.runtimeError("The folder needs to only contain book items")
      }

      guard !items.isEmpty else {
        throw BookPlayerError.runtimeError("The folder can't be empty")
      }

      items.forEach({ $0.lastPlayDate = nil })

      folder.type = .bound
    case .book:
      return
    }

    self.dataManager.saveContext()
  }

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

  func createFolderOnDisk(title: String, inside relativePath: String?) throws {
    let processedFolder = DataManager.getProcessedFolderURL()
    let destinationURL: URL

    if let relativePath = relativePath {
      destinationURL = processedFolder.appendingPathComponent(relativePath).appendingPathComponent(title)
    } else {
      destinationURL = processedFolder.appendingPathComponent(title)
    }

    try? removeFolderIfNeeded(destinationURL)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false, attributes: nil)
  }

  public func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem {
    try createFolderOnDisk(title: title, inside: relativePath)

    var parentFolder: Folder?

    if let relativePath = relativePath {
      // The folder object must exist
      parentFolder = self.findFolder(with: relativePath)!
    }

    let newFolder = Folder(title: title, context: self.dataManager.getContext())

    // insert into existing folder or library at index
    if let parentFolder = parentFolder {
      parentFolder.insert(item: newFolder)
    } else {
      let library = self.getLibrary()
      library.insert(item: newFolder)
    }

    self.dataManager.saveContext()

    return SimpleLibraryItem(from: newFolder)
  }

  func buildListContentsFetchRequest(
    properties: [String],
    relativePath: String?,
    limit: Int?,
    offset: Int?
  ) -> NSFetchRequest<NSDictionary> {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = properties
    fetchRequest.resultType = .dictionaryResultType
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

    return fetchRequest
  }

  public func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: SimpleLibraryItem.fetchRequestProperties,
      relativePath: relativePath,
      limit: limit,
      offset: offset
    )

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)
  }

  func parseFetchedItems(from results: [[String: Any]]?) -> [SimpleLibraryItem]? {
    return results?.compactMap({ dictionary -> SimpleLibraryItem? in
      guard
        let title = dictionary["title"] as? String,
        let details = dictionary["details"] as? String,
        let duration = dictionary["duration"] as? Double,
        let percentCompleted = dictionary["percentCompleted"] as? Double,
        let isFinished = dictionary["isFinished"] as? Bool,
        let relativePath = dictionary["relativePath"] as? String,
        let originalFileName = dictionary["originalFileName"] as? String,
        let rawType = dictionary["type"] as? Int16,
        let type = SimpleItemType(rawValue: rawType),
        let rawSyncStatus = dictionary["syncStatus"] as? Int16,
        let syncStatus = SyncStatus(rawValue: rawSyncStatus)
      else { return nil }

      return SimpleLibraryItem(
        title: title,
        details: details,
        duration: duration,
        percentCompleted: percentCompleted,
        isFinished: isFinished,
        relativePath: relativePath,
        parentFolder: dictionary["folder.relativePath"] as? String,
        originalFileName: originalFileName,
        lastPlayDate: dictionary["lastPlayDate"] as? Date,
        type: type,
        syncStatus: syncStatus
      )
    })
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

  public func sortContents(at relativePath: String?, by type: SortType) {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.propertiesToFetch = type.fetchProperties()

    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)]

    guard
      let results = try? self.dataManager.getContext().fetch(fetchRequest),
      !results.isEmpty
    else { return }

    let sortedResults = type.sortItems(results)

    if let relativePath,
       let folder = self.getItem(with: relativePath) as? Folder {
      folder.items = NSOrderedSet(array: sortedResults)
      folder.rebuildOrderRank()
    } else {
      let library = self.getLibrary()
      library.items = NSOrderedSet(array: sortedResults)
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

  public func updatePlaybackTime(relativePath: String, time: Double, date: Date) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.currentTime = time
    item.lastPlayDate = date
    item.percentCompleted = round((item.currentTime / item.duration) * 100)
    if let parentFolderPath = item.folder?.relativePath {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date)
    }

    self.dataManager.scheduleSaveContext()
  }

  public func updateBookSpeed(at relativePath: String, speed: Float) {
    guard let item = self.getItem(with: relativePath) else { return }

    item.speed = speed
    item.folder?.speed = speed

    self.dataManager.saveContext()
  }

  public func getItemSpeed(at relativePath: String) -> Float {
    guard let item = self.getItem(with: relativePath) else { return 1.0 }

    return item.folder?.speed ?? item.speed
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

    guard let items = self.fetchContents(at: folder.relativePath, limit: nil, offset: nil) else { return }

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
    guard let items = self.fetchContents(at: folder.relativePath, limit: nil, offset: nil) else { return }

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

  public func getTotalListenedTime() -> TimeInterval {
    let totalTimeExpression = NSExpressionDescription()
    totalTimeExpression.expression = NSExpression(
      forFunction: "sum:",
      arguments: [NSExpression(forKeyPath: #keyPath(PlaybackRecord.time))]
    )
    totalTimeExpression.name = "totalTime"
    totalTimeExpression.expressionResultType = NSAttributeType.doubleAttributeType

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "PlaybackRecord")
    fetchRequest.propertiesToFetch = [totalTimeExpression]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let results = try? self.dataManager.getContext().fetch(fetchRequest).first as? [String: Double]
    else {
      return 0
    }

    return results["totalTime"] ?? 0

  }

  public func recordTime(_ playbackRecord: PlaybackRecord) {
    playbackRecord.time += 1
    self.dataManager.scheduleSaveContext()
  }

  // MARK: - Bookmarks

  public func getBookmarks(of type: BookmarkType, relativePath: String) -> [Bookmark]? {
    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d",
                                         #keyPath(Bookmark.item.relativePath),
                                         relativePath,
                                         type.rawValue)

    return try? self.dataManager.getContext().fetch(fetchRequest)
  }

  public func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark? {
    let time = floor(time)

    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@ && type == %d && time == %f",
                                         #keyPath(Bookmark.item.relativePath),
                                         relativePath,
                                         type.rawValue,
                                         floor(time))

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> Bookmark? {
    if let bookmark = self.getBookmark(at: time, relativePath: relativePath, type: type) {
      return bookmark
    }

    guard let item = self.getItem(with: relativePath) else { return nil }

    let bookmark = Bookmark(with: floor(time), type: type, context: self.dataManager.getContext())
    item.addToBookmarks(bookmark)

    self.dataManager.saveContext()

    return bookmark
  }

  public func addNote(_ note: String, bookmark: Bookmark) {
    bookmark.note = note
    self.dataManager.saveContext()
  }

  public func deleteBookmark(_ bookmark: Bookmark) {
    let item = bookmark.item
    item?.removeFromBookmarks(bookmark)
    self.dataManager.delete(bookmark)
  }

  public func renameItem(at relativePath: String, with newTitle: String) throws {
    guard let item = self.getItem(with: relativePath) else { return }

    // Rename folder on disk too
    if let folder = item as? Folder {
      let processedFolderURL = DataManager.getProcessedFolderURL()

      let sourceUrl = processedFolderURL
        .appendingPathComponent(item.relativePath)

      let destinationUrl: URL
      let newRelativePath: String

      if let parentFolder = item.folder {
        destinationUrl = processedFolderURL
          .appendingPathComponent(parentFolder.relativePath)
          .appendingPathComponent(newTitle)
        newRelativePath = String(destinationUrl.relativePath(to: processedFolderURL).dropFirst())
      } else {
        destinationUrl = processedFolderURL
          .appendingPathComponent(newTitle)
        newRelativePath = newTitle
      }

      try FileManager.default.moveItem(
        at: sourceUrl,
        to: destinationUrl
      )

      item.originalFileName = newTitle
      item.relativePath = newRelativePath
      if let items = folder.items?.array as? [LibraryItem] {
        items.forEach({ folder.rebuildRelativePaths(for: $0) })
      }
    }

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

    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(array: files)
    // swiftlint:disable force_cast
    let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]

    _ = self.insertItems(from: sortedFiles, into: folder, library: library, processedItems: [])
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
      folder.updateDetails()
    }

    self.dataManager.saveContext()
  }

  public func delete(_ items: [LibraryItem], mode: DeleteMode) throws {
    for item in items {
      switch item {
      case let book as Book:
        try self.delete(book: book)
      case let folder as Folder:
        if mode == .deep {
          try self.deepDelete(folder: folder)
        } else {
          try self.shallowDelete(folder: folder)
        }
      default:
        continue
      }
    }
  }

  func delete(book: Book) throws {
    // Delete file item if it exists
    if let fileURL = book.fileURL,
       FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    self.dataManager.delete(book)
  }

  func deepDelete(folder: Folder) throws {
    // Delete folder if it exists
    if let fileURL = folder.fileURL,
       FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    defer {
      self.dataManager.delete(folder)
    }

    // Fetch folder items
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()

    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(LibraryItem.folder.relativePath),
      folder.relativePath
    )

    fetchRequest.includesPropertyValues = false

    let items = try self.dataManager.getContext().fetch(fetchRequest)
    // Delete items
    try self.delete(items, mode: .deep)
  }

  func shallowDelete(folder: Folder) throws {
    // Move children to parent folder or library
    if let items = folder.items?.array as? [LibraryItem] {
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
        } else if let library = folder.library {
          try FileManager.default.moveItem(
            at: fileURL,
            to: DataManager.getProcessedFolderURL().appendingPathComponent(fileURL.lastPathComponent)
          )
          library.insert(item: item)
        }
      }
    }

    // Delete empty folder
    if let folderURL = folder.fileURL {
      if FileManager.default.fileExists(atPath: folderURL.path) {
        try FileManager.default.removeItem(at: folderURL)
      }
    }

    self.dataManager.delete(folder)
  }

  /// Internal function to calculate the entire folder's duration
  func calculateFolderDuration(at relativePath: String) -> Double {
    let durationExpression = NSExpressionDescription()
    durationExpression.expression = NSExpression(
      forFunction: "sum:",
      arguments: [NSExpression(forKeyPath: #keyPath(LibraryItem.duration))]
    )
    durationExpression.name = "totalDuration"
    durationExpression.expressionResultType = NSAttributeType.doubleAttributeType

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    fetchRequest.propertiesToFetch = [durationExpression]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let results = try? self.dataManager.getContext().fetch(fetchRequest).first as? [String: Double]
    else {
      return 0
    }

    return results["totalDuration"] ?? 0
  }

  /// Internal function to calculate the entire folder's progress
  func calculateFolderProgress(at relativePath: String) -> (Double, Int) {
    let progressExpression = NSExpressionDescription()
    progressExpression.expression = NSExpression(
      forConditional: NSPredicate(format: "%K == 1", #keyPath(LibraryItem.isFinished)),
      trueExpression: NSExpression(forConstantValue: 100.0),
      falseExpression: NSExpression(forKeyPath: #keyPath(LibraryItem.percentCompleted))
    )
    progressExpression.name = "parsedPercentCompleted"
    progressExpression.expressionResultType = NSAttributeType.doubleAttributeType

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    fetchRequest.propertiesToFetch = [progressExpression]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Double]],
      !results.isEmpty
    else {
      return (0, 0)
    }

    let count = results.count
    let totalProgress = results.reduce(into: Double(0)) { partialResult, dict in
      partialResult += dict.values.first ?? 0
    }

    return (totalProgress / Double(count), count)
  }

  public func rebuildFolderDetails(_ relativePath: String) {
    guard let folder = findFolder(with: relativePath) else { return }

    let (progress, contentsCount) = calculateFolderProgress(at: relativePath)
    folder.percentCompleted = progress
    folder.duration = calculateFolderDuration(at: relativePath)
    folder.updateDetails(with: contentsCount)

    dataManager.saveContext()

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      rebuildFolderDetails(parentFolderPath)
    }
  }

  func recursiveFolderLastPlayedDateUpdate(from relativePath: String, date: Date) {
    guard let folder = findFolder(with: relativePath) else { return }

    folder.lastPlayDate = date

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date)
    }
  }

  public func recursiveFolderProgressUpdate(from relativePath: String) {
    guard let folder = findFolder(with: relativePath) else { return }

    let (progress, _) = calculateFolderProgress(at: relativePath)
    folder.percentCompleted = progress
    /// TODO: verify if necessary to mark the folder as finished

    NotificationCenter.default.post(
      name: .folderProgressUpdated,
      object: nil,
      userInfo: [
        "relativePath": relativePath,
        "progress": progress
      ]
    )

    dataManager.saveContext()

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      recursiveFolderProgressUpdate(from: parentFolderPath)
    }
  }

  public func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) -> [SimpleLibraryItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.predicate = buildFilterPredicate(
      relativePath: relativePath,
      query: query,
      scope: scope
    )

    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.lastPlayDate), ascending: false)
    fetchRequest.sortDescriptors = [sort]

    if let limit = limit {
      fetchRequest.fetchLimit = limit
    }

    if let offset = offset {
      fetchRequest.fetchOffset = offset
    }

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)
  }

  private func buildFilterPredicate(
    relativePath: String?,
    query: String?,
    scope: SimpleItemType
  ) -> NSPredicate {
    var predicates = [NSPredicate]()

    switch scope {
    case .folder:
      predicates.append(
        NSPredicate(format: "%K == \(SimpleItemType.folder.rawValue)", #keyPath(LibraryItem.type))
      )
    case .bound, .book:
      predicates.append(
        NSPredicate(format: "%K != \(SimpleItemType.folder.rawValue)", #keyPath(LibraryItem.type))
      )
    }

    if let query = query,
       !query.isEmpty {
      predicates.append(
        NSPredicate(
          format: "%K CONTAINS[cd] %@",
          #keyPath(LibraryItem.title),
          query
        )
      )
    }

    if let relativePath = relativePath {
      predicates.append(
        NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
      )
    }

    return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
  }
}
