//
//  LibraryService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/21/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation
import Combine

/// sourcery: AutoMockable
public protocol LibraryServiceProtocol {
  /// Metadata publisher that collects changes during 10 seconds before normalizing the payload
  var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> { get }

  /// Gets (or create) the library for the App. There should be only one Library object at all times
  func getLibrary() -> Library
  /// Get last item played
  func getLibraryLastItem() -> SimpleLibraryItem?
  /// Get current theme selected
  func getLibraryCurrentTheme() -> SimpleTheme?
  /// Set a new theme for the library
  func setLibraryTheme(with simpleTheme: SimpleTheme)
  /// Set the last played book
  func setLibraryLastBook(with relativePath: String?)
  /// Import and insert items
  func insertItems(from files: [URL]) async -> [SimpleLibraryItem]
  /// Move items between folders
  func moveItems(_ items: [String], inside relativePath: String?) async throws
  /// Delete items
  func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) async throws

  /// Fetch folder or library contents at the specified path
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]?
  /// Get max items count inside the specified path
  func getMaxItemsCount(at relativePath: String?) -> Int
  /// Fetch the most recent played items
  func getLastPlayedItems(limit: Int?) async -> [SimpleLibraryItem]?
  /// Fetch the books that contain the file URL
  func findBooks(containing fileURL: URL) async -> [Book]?
  /// Fetch a single item with properties loaded
  func getSimpleItem(with relativePath: String) async -> SimpleLibraryItem?
  /// Get items not included in a specific set
  func getItems(notIn relativePaths: [String], parentFolder: String?) async -> [SimpleLibraryItem]?
  /// Fetch a property from a stored library item
  func getItemProperty(_ property: String, relativePath: String) -> Any?
  /// Search
  func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) async -> [SimpleLibraryItem]?
  /// Autoplay
  /// Find first item that is unfinished in a folder
  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) async -> SimpleLibraryItem?
  /// Fetch first item before a specific position in a folder
  func findFirstItem(in parentFolder: String?, beforeRank: Int16?) async -> SimpleLibraryItem?
  /// Fetch first item after a specific position in a folder considering if it's unfinished or not
  func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) async -> SimpleLibraryItem?
  /// Get metadata chapters from item
  func getChapters(from relativePath: String) async -> [SimpleChapter]?

  /// Update metadata
  /// Create book core data object
  func createBook(from url: URL) async -> Book
  /// Load metadata chapters if needed
  func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async
  /// Create folder
  func createFolder(with title: String, inside relativePath: String?) async throws -> SimpleLibraryItem
  /// Update folder type
  func updateFolder(at relativePath: String, type: SimpleItemType) async throws
  /// Rebuild folder details
  func rebuildFolderDetails(_ relativePath: String)
  /// Rebuild folder progress
  func recursiveFolderProgressUpdate(from relativePath: String)
  /// Rename book title
  func renameBook(at relativePath: String, with newTitle: String) async
  /// Rename folder title
  func renameFolder(at relativePath: String, with newTitle: String) async throws -> String
  /// Update item details
  func updateDetails(at relativePath: String, details: String) async
  /// Update item order to new rank
  func reorderItem(
    with relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  ) async
  /// Sort entire list at the given path
  func sortContents(at relativePath: String?, by type: SortType) async
  /// Playback
  /// Update playback time for item
  func updatePlaybackTime(relativePath: String, time: Double, date: Date, scheduleSave: Bool)
  /// Update item speed
  func updateBookSpeed(at relativePath: String, speed: Float)
  /// Get item speed
  func getItemSpeed(at relativePath: String) -> Float
  /// Mark item as finished
  func markAsFinished(flag: Bool, relativePath: String) async
  /// Jump to the start of an item
  func jumpToStart(relativePath: String) async

  /// Time listened
  /// Get playback time for today
  func getCurrentPlaybackRecordTime() async -> Double
  /// Get the first playback time for a specific range of dates
  func getFirstPlaybackRecordTime(
    from startDate: Date,
    to endDate: Date
  ) async -> Double
  /// Record a second of listened time
  func recordTime()
  /// Get total listened time across all items
  func getTotalListenedTime() async -> TimeInterval

  /// Bookmarks
  /// Fetch bookmarks for an item
  func getBookmarks(of type: BookmarkType, relativePath: String) async -> [SimpleBookmark]?

  func getBookmark(
    at time: Double,
    relativePath: String,
    type: BookmarkType
  ) -> SimpleBookmark?
  /// Create a bookmark at the given time
  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) async -> SimpleBookmark?
  /// Add a note to a bookmark
  func addNote(_ note: String, bookmark: SimpleBookmark) async
  /// Delete a bookmark
  func deleteBookmark(_ bookmark: SimpleBookmark) async
}

// swiftlint:disable force_cast
public final class LibraryService: LibraryServiceProtocol {
  let dataManager: DataManager

  /// Internal passthrough publisher for emitting metadata update events
  private var metadataPassthroughPublisher = PassthroughSubject<[String: Any], Never>()
  /// Public metadata publisher that collects changes during 4 seconds before normalizing the payload
  public lazy var metadataUpdatePublisher = metadataPassthroughPublisher
    .collect(.byTime(DispatchQueue.main, .seconds(10)))
    .flatMap({ changes in
      var results = [String: [String: Any]]()
      for change in changes {
        guard let relativePath = change["relativePath"] as? String else { continue }

        if let itemDict = results[relativePath] {
          results[relativePath] = itemDict.merging(change) { (_, new) in new }
        } else {
          results[relativePath] = change
        }
      }

      let resultsArray = Array(results.values) as [[String: Any]]
      return resultsArray.publisher
    })
    .eraseToAnyPublisher()

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
  }

  private func rebuildRelativePaths(for item: LibraryItem, parentFolder: String?, context: NSManagedObjectContext) {
    switch item {
    case let book as Book:
      if let parentPath = parentFolder {
        let itemRelativePath = book.relativePath.split(separator: "/").map({ String($0) }).last ?? book.relativePath
        book.relativePath = "\(parentPath)/\(itemRelativePath!)"
      } else {
        book.relativePath = book.originalFileName
      }
    case let folder as Folder:
      /// Get contents before updating relative path
      let contents = fetchRawContents(
        at: folder.relativePath,
        propertiesToFetch: [
        #keyPath(LibraryItem.relativePath),
        #keyPath(LibraryItem.originalFileName)
        ],
        context: context
      ) ?? []

      if let parentPath = parentFolder {
        let itemRelativePath = folder.relativePath.split(separator: "/").map({ String($0) }).last ?? folder.relativePath
        folder.relativePath = "\(parentPath)/\(itemRelativePath!)"
      } else {
        folder.relativePath = folder.originalFileName
      }

      for nestedItem in contents {
        rebuildRelativePaths(for: nestedItem, parentFolder: folder.relativePath, context: context)
      }
    default:
      break
    }
  }

  func getItemReference(with relativePath: String, context: NSManagedObjectContext) -> LibraryItem? {
    let fetchRequest = Self.itemReferenceFetchRequest(relativePath: relativePath)

    return try? context.fetch(fetchRequest).first
  }

  public func hasItemProperty(_ property: String, relativePath: String) -> Bool {
    let booleanExpression = NSExpressionDescription()
    booleanExpression.name = "hasProperty"
    booleanExpression.expressionResultType = NSAttributeType.booleanAttributeType
    booleanExpression.expression = NSExpression(
      forConditional: NSPredicate(
        format: "%@ != nil",
        property
      ),
      trueExpression: NSExpression(forConstantValue: true),
      falseExpression: NSExpression(forConstantValue: false)
    )
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(LibraryItem.relativePath),
      relativePath
    )
    fetchRequest.propertiesToFetch = [booleanExpression]
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.fetchLimit = 1

    let result = try? self.dataManager.getContext().fetch(fetchRequest).first as? [String: Bool]

    return result?["hasProperty"] ?? false
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

  func parseFetchedItems(from results: [[String: Any]]?) -> [SimpleLibraryItem]? {
    return results?.compactMap({ [weak self] dictionary -> SimpleLibraryItem? in
      guard
        let title = dictionary["title"] as? String,
        let speed = dictionary["speed"] as? Float,
        let currentTime = dictionary["currentTime"] as? Double,
        let duration = dictionary["duration"] as? Double,
        let percentCompleted = dictionary["percentCompleted"] as? Double,
        let relativePath = dictionary["relativePath"] as? String,
        let orderRank = dictionary["orderRank"] as? Int16,
        let originalFileName = dictionary["originalFileName"] as? String,
        let rawType = dictionary["type"] as? Int16,
        let type = SimpleItemType(rawValue: rawType)
      else { return nil }

      /// Patch for optional CoreData properties until we migrate to Realm
      if dictionary["details"] == nil {
        self?.rebuildFolderDetails(relativePath)
      }

      return SimpleLibraryItem(
        title: title,
        details: dictionary["details"] as? String ?? "",
        speed: Double(speed),
        currentTime: currentTime,
        duration: duration,
        percentCompleted: percentCompleted,
        isFinished: dictionary["isFinished"] as? Bool ?? false,
        relativePath: relativePath,
        remoteURL: dictionary["remoteURL"] as? URL,
        artworkURL: dictionary["artworkURL"] as? URL,
        orderRank: orderRank,
        parentFolder: dictionary["folder.relativePath"] as? String,
        originalFileName: originalFileName,
        lastPlayDate: dictionary["lastPlayDate"] as? Date,
        type: type
      )
    })
  }

  func getNextOrderRank(in folderPath: String?, context: NSManagedObjectContext) -> Int16 {
    let maxExpression = NSExpressionDescription()
    maxExpression.expression = NSExpression(
      forFunction: "max:",
      arguments: [NSExpression(forKeyPath: #keyPath(LibraryItem.orderRank))]
    )
    maxExpression.name = "maxOrderRank"
    maxExpression.expressionResultType = NSAttributeType.integer16AttributeType

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    if let folderPath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), folderPath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    fetchRequest.propertiesToFetch = [maxExpression]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let results = try? context.fetch(fetchRequest) as? [[String: Int16]],
      let maxOrderRank = results.first?["maxOrderRank"]
    else {
      return 0
    }

    return maxOrderRank + 1
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

// MARK: - Library (class)
extension LibraryService {
  ///  Gets the library for the App. There should be only one Library object at all times
  public func getLibrary() -> Library {
    let context = self.dataManager.getContext()
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.returnsObjectsAsFaults = false

    return (try? context.fetch(fetch).first) ?? self.createLibrary(context: context)
  }

  func getLibraryReference(context: NSManagedObjectContext) -> Library {
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.includesPropertyValues = false
    fetch.fetchLimit = 1

    return (try? context.fetch(fetch).first)!
  }

  private func createLibrary(context: NSManagedObjectContext) -> Library {
    let library = Library.create(in: context)
    self.dataManager.saveContext(context)
    return library
  }

  public func getLibraryLastItem() -> SimpleLibraryItem? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["lastPlayedItem.relativePath"]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let dict = (try? context.fetch(fetchRequest))?.first as? [String: String],
      let relativePath = dict["lastPlayedItem.relativePath"]
    else {
      return nil
    }

    return getSimpleItem(with: relativePath, context: context)
  }

  public func getLibraryCurrentTheme() -> SimpleTheme? {
    let context = self.dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["currentTheme"]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let dict = (try? context.fetch(fetchRequest))?.first as? [String: NSManagedObjectID],
      let themeId = dict["currentTheme"],
      let theme = try? context.existingObject(with: themeId) as? Theme
    else {
      return nil
    }

    return SimpleTheme(with: theme)
  }

  public func setLibraryTheme(with simpleTheme: SimpleTheme) {
    dataManager.performTask { [weak self] context in
      guard let self else { return }

      let library = self.getLibraryReference(context: context)

      library.currentTheme = getTheme(with: simpleTheme.title, context: context)
      ?? Theme(
        simpleTheme: simpleTheme,
        context: context
      )

      self.dataManager.saveContext(context)
    }
  }

  private func getTheme(with title: String, context: NSManagedObjectContext) -> Theme? {
    let fetchRequest: NSFetchRequest<Theme> = Theme.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "title == %@", title)
    fetchRequest.fetchLimit = 1
    fetchRequest.returnsObjectsAsFaults = false

    return try? context.fetch(fetchRequest).first
  }

  public func setLibraryLastBook(with relativePath: String?) {
    dataManager.performBackgroundTask { [weak self] context in
      guard let self else { return }

      let library = self.getLibraryReference(context: context)

      if let relativePath = relativePath {
        library.lastPlayedItem = getItemReference(with: relativePath, context: context)
      } else {
        library.lastPlayedItem = nil
      }

      self.dataManager.saveContext(context)
    }
  }

  @discardableResult
  public func insertItems(from files: [URL]) async -> [SimpleLibraryItem] {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard let self else {
          continuation.resume(returning: [])
          return
        }

        continuation.resume(returning: insertItems(from: files, parentPath: nil, context: context))
      }
    }
  }

  /// This handles the Core Data objects creation from the Import operation. This method doesn't handle moving files on disk,
  /// as we don't want this method to throw, and the files are already in the processed folder
  @discardableResult
  func insertItems(from files: [URL], parentPath: String? = nil, context: NSManagedObjectContext) -> [SimpleLibraryItem] {
    let context = dataManager.getContext()
    let library = getLibraryReference(context: context)

    var processedFiles = [SimpleLibraryItem]()
    for file in files {
      let libraryItem: LibraryItem

      if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
         let type = attributes[.type] as? FileAttributeType,
         type == .typeDirectory {
        libraryItem = Folder(from: file, context: context)
        /// Kick-off separate function to handle instatiating the folder contents
        self.handleDirectory(file, context: context)
      } else {
        libraryItem = Book(from: file, context: context)
      }

      libraryItem.orderRank = getNextOrderRank(in: parentPath, context: context)

      if let parentPath,
         let parentFolder = getItemReference(with: parentPath, context: context) as? Folder {
        parentFolder.addToItems(libraryItem)
        /// update details on parent folder
      } else {
        library.addToItems(libraryItem)
      }

      processedFiles.append(SimpleLibraryItem(from: libraryItem))
      dataManager.saveContext(context)
    }

    return processedFiles
  }

  private func handleDirectory(_ folderURL: URL, context: NSManagedObjectContext) {
    let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      }
    )!

    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    let sortDescriptor = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
    let orderedSet = NSOrderedSet(array: files)

    let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]

    let parentPath = folderURL.relativePath(to: DataManager.getProcessedFolderURL())
    insertItems(from: sortedFiles, parentPath: parentPath, context: context)
    rebuildFolderDetails(parentPath, context: context)
  }

  private func moveFileIfNeeded(
    from sourceUrl: URL,
    processedFolderURL: URL,
    parentPath: String?
  ) throws {
    guard FileManager.default.fileExists(atPath: sourceUrl.path) else { return }

    let destinationUrl: URL

    if let parentPath {
      destinationUrl = processedFolderURL
        .appendingPathComponent(parentPath)
        .appendingPathComponent(sourceUrl.lastPathComponent)
    } else {
      destinationUrl = processedFolderURL
        .appendingPathComponent(sourceUrl.lastPathComponent)
    }

    try FileManager.default.moveItem(
      at: sourceUrl,
      to: destinationUrl
    )
  }

  public func moveItems(_ items: [String], inside relativePath: String?) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        do {
          try self?.moveItems(items, inside: relativePath, context: context)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  // swiftlint:disable:next function_body_length
  func moveItems(_ items: [String], inside relativePath: String?, context: NSManagedObjectContext) throws {
    var folder: Folder?
    let library = self.getLibraryReference(context: context)

    if let relativePath = relativePath,
       let folderReference = getItemReference(with: relativePath, context: context) as? Folder {
      folder = folderReference
    }

    /// Preserve original parent path to rebuild order rank later
    var originalParentPath: String?
    if let firstPath = items.first {
      originalParentPath = getItemProperty(
        #keyPath(LibraryItem.folder.relativePath),
        relativePath: firstPath,
        context: context
       ) as? String
    }

    let processedFolderURL = DataManager.getProcessedFolderURL()
    let startingIndex = getNextOrderRank(in: relativePath, context: context)

    for (index, itemPath) in items.enumerated() {
      guard let libraryItem = getItemReference(with: itemPath, context: context) else { continue }

      let sourceUrl = processedFolderURL
        .appendingPathComponent(itemPath)

      try moveFileIfNeeded(
        from: sourceUrl,
        processedFolderURL: processedFolderURL,
        parentPath: folder?.relativePath
      )

      libraryItem.orderRank = startingIndex + Int16(index)
      rebuildRelativePaths(for: libraryItem, parentFolder: relativePath, context: context)

      if let folder = folder {
        /// Remove reference to Library if it exists
        if hasItemProperty(#keyPath(LibraryItem.library), relativePath: itemPath) {
          library.removeFromItems(libraryItem)
        }
        folder.addToItems(libraryItem)
      } else {
        if let parentPath = getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: itemPath,
          context: context
        ) as? String,
           let parentFolder = getItemReference(with: parentPath, context: context) as? Folder {
          parentFolder.removeFromItems(libraryItem)
        }
        library.addToItems(libraryItem)
      }
    }

    self.dataManager.saveContext(context)

    if let folder {
      rebuildFolderDetails(folder.relativePath, context: context)
    }
    if let originalParentPath {
      rebuildOrderRank(in: originalParentPath, context: context)
    }
  }

  func rebuildOrderRank(in folderRelativePath: String?, context: NSManagedObjectContext) {
    guard
      let contents = fetchRawContents(
        at: folderRelativePath,
        propertiesToFetch: [
          #keyPath(LibraryItem.relativePath),
          #keyPath(LibraryItem.orderRank)
        ],
        context: context
      )
    else { return }

    for (index, item) in contents.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank
      ])
    }

    self.dataManager.saveContext(context)
  }

  func getItemIdentifiers(in parentFolder: String?, context: NSManagedObjectContext) -> [String]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: ["relativePath"],
      relativePath: parentFolder,
      limit: nil,
      offset: nil
    )

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return results?.compactMap({ $0["relativePath"] as? String })
  }

  public func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        do {
          try self?.delete(items, mode: mode, context: context)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  func delete(_ items: [SimpleLibraryItem], mode: DeleteMode, context: NSManagedObjectContext) throws {
    for item in items {
      switch item.type {
      case .book:
        try deleteItem(item, context: context)
      case .bound, .folder:
        switch mode {
        case .deep:
          try deleteFolderContents(item, context: context)
        case .shallow:
          // Move children to parent folder or library
          if let items = getItemIdentifiers(in: item.relativePath, context: context),
             !items.isEmpty {
            try moveItems(items, inside: item.parentFolder, context: context)
          }
        }

        try deleteItem(item, context: context)
      }

      /// Clean up artwork cache
      ArtworkService.removeCache(for: item.relativePath)
    }
  }

  func deleteItem(_ item: SimpleLibraryItem, context: NSManagedObjectContext) throws {
    // Delete file item if it exists
    let fileURL = item.fileURL
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    if let bookReference = getItemReference(with: item.relativePath, context: context) {
      dataManager.delete(bookReference, context: context)
    }
  }

  func deleteFolderContents(_ folder: SimpleLibraryItem, context: NSManagedObjectContext) throws {
    // Delete folder contents
    guard let items = fetchContents(
      at: folder.relativePath,
      limit: nil,
      offset: nil,
      context: context
    ) else { return }

    try self.delete(items, mode: .deep, context: context)
  }
}

// MARK: - Fetch library items
extension LibraryService {
  public func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
    return fetchContents(
      at: relativePath,
      limit: limit,
      offset: offset,
      context: dataManager.getContext()
    )
  }

  func fetchContents(
    at relativePath: String?,
    limit: Int?,
    offset: Int?,
    context: NSManagedObjectContext
  ) -> [SimpleLibraryItem]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: SimpleLibraryItem.fetchRequestProperties,
      relativePath: relativePath,
      limit: limit,
      offset: offset
    )

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)
  }

  func fetchRawContents(at relativePath: String?, propertiesToFetch: [String], context: NSManagedObjectContext) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.propertiesToFetch = propertiesToFetch

    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)
    fetchRequest.sortDescriptors = [sort]

    return try? context.fetch(fetchRequest)
  }

  public func getMaxItemsCount(at relativePath: String?) -> Int {
    return getMaxItemsCount(at: relativePath, context: dataManager.getContext())
  }

  func getMaxItemsCount(at relativePath: String?, context: NSManagedObjectContext) -> Int {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }

    return (try? context.count(for: fetchRequest)) ?? 0
  }

  public func getLastPlayedItems(limit: Int?) async -> [SimpleLibraryItem]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
        fetchRequest.predicate = NSPredicate(format: "type != 0 && lastPlayDate != nil")
        fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
        fetchRequest.resultType = .dictionaryResultType

        if let limit = limit {
          fetchRequest.fetchLimit = limit
        }

        let sort = NSSortDescriptor(key: #keyPath(LibraryItem.lastPlayDate), ascending: false)
        fetchRequest.sortDescriptors = [sort]

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        continuation.resume(returning: self?.parseFetchedItems(from: results))
      }
    }
  }

  public func findBooks(containing fileURL: URL) async -> [Book]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { context in
        let fetch: NSFetchRequest<Book> = Book.fetchRequest()
        fetch.predicate = NSPredicate(format: "relativePath ENDSWITH[C] %@", fileURL.lastPathComponent)

        let books = try? context.fetch(fetch)
        continuation.resume(returning: books)
      }
    }
  }

  public func getSimpleItem(with relativePath: String) async -> SimpleLibraryItem? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let item = self?.getSimpleItem(with: relativePath, context: context)
        continuation.resume(returning: item)
      }
    }
  }

  func getSimpleItem(with relativePath: String, context: NSManagedObjectContext) -> SimpleLibraryItem? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)?.first
  }

  public func getItem(with relativePath: String, context: NSManagedObjectContext) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1

    return try? context.fetch(fetchRequest).first
  }

  public func getItems(notIn relativePaths: [String], parentFolder: String?) async -> [SimpleLibraryItem]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
        fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
        fetchRequest.resultType = .dictionaryResultType

        if let parentFolder = parentFolder {
          fetchRequest.predicate = NSPredicate(
            format: "%K == %@ AND NOT (%K IN %@)",
            #keyPath(LibraryItem.folder.relativePath),
            parentFolder,
            #keyPath(LibraryItem.relativePath),
            relativePaths
          )
        } else {
          fetchRequest.predicate = NSPredicate(
            format: "%K != nil AND NOT (%K IN %@)",
            #keyPath(LibraryItem.library),
            #keyPath(LibraryItem.relativePath),
            relativePaths
          )
        }

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]
        continuation.resume(returning: self?.parseFetchedItems(from: results))
      }
    }
  }

  public func getItemProperty(_ property: String, relativePath: String) -> Any? {
    return getItemProperty(property, relativePath: relativePath, context: dataManager.getContext())
  }

  func getItemProperty(_ property: String, relativePath: String, context: NSManagedObjectContext) -> Any? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = [property]
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(LibraryItem.relativePath),
      relativePath
    )
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.fetchLimit = 1

    let results = try? context.fetch(fetchRequest).first as? [String: Any]

    return results?[property]
  }

  public func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) async -> [SimpleLibraryItem]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard let self else {
          continuation.resume(returning: nil)
          return
        }

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

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        continuation.resume(returning: parseFetchedItems(from: results))
      }
    }
  }

  func findFirstItem(
    in parentFolder: String?,
    rankPredicate: NSPredicate?,
    sortAscending: Bool,
    isUnfinished: Bool?
  ) async -> SimpleLibraryItem? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")

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
        fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
        fetchRequest.resultType = .dictionaryResultType

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        continuation.resume(returning: self?.parseFetchedItems(from: results)?.first)
      }
    }
  }

  public func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) async -> SimpleLibraryItem? {
    return await findFirstItem(
      in: parentFolder,
      rankPredicate: nil,
      sortAscending: true,
      isUnfinished: isUnfinished
    )
  }

  public func findFirstItem(in parentFolder: String?, beforeRank: Int16?) async -> SimpleLibraryItem? {
    var rankPredicate: NSPredicate?
    if let beforeRank = beforeRank {
      rankPredicate = NSPredicate(format: "%K < %d", #keyPath(LibraryItem.orderRank), beforeRank)
    }
    return await findFirstItem(
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
  ) async -> SimpleLibraryItem? {
    var rankPredicate: NSPredicate?
    if let afterRank = afterRank {
      rankPredicate = NSPredicate(format: "%K > %d", #keyPath(LibraryItem.orderRank), afterRank)
    }
    return await findFirstItem(
      in: parentFolder,
      rankPredicate: rankPredicate,
      sortAscending: true,
      isUnfinished: isUnfinished
    )
  }

  public func getChapters(from relativePath: String) async -> [SimpleChapter]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Chapter")
        fetchRequest.propertiesToFetch = ["title", "start", "duration", "index"]
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.predicate = NSPredicate(format: "%K == %@",
                                             #keyPath(Chapter.book.relativePath),
                                             relativePath)
        let sort = NSSortDescriptor(key: #keyPath(Chapter.index), ascending: true)
        fetchRequest.sortDescriptors = [sort]

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        let chapters = results?.compactMap({ dictionary -> SimpleChapter? in
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

        continuation.resume(returning: chapters)
      }
    }
  }
}

// MARK: - Metadata update
extension LibraryService {
  public func createBook(from url: URL) async -> Book {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let newBook = Book(from: url, context: context)
        self?.dataManager.saveContext(context)

        continuation.resume(returning: newBook)
      }
    }
  }

  public func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
        fetchRequest.fetchLimit = 1

        guard let book = try? context.fetch(fetchRequest).first as? Book else {
          continuation.resume()
          return
        }

        book.loadChaptersIfNeeded(from: asset, context: context)

        context.saveContext()

        continuation.resume()
      }
    }
  }

  func createFolderOnDisk(title: String, inside relativePath: String?, context: NSManagedObjectContext) throws {
    let processedFolder = DataManager.getProcessedFolderURL()
    let destinationURL: URL

    if let relativePath = relativePath {
      destinationURL = processedFolder.appendingPathComponent(relativePath).appendingPathComponent(title)
    } else {
      destinationURL = processedFolder.appendingPathComponent(title)
    }

    try? removeFolderIfNeeded(destinationURL, context: context)
    try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: false, attributes: nil)
  }

  func hasLibraryLinked(item: LibraryItem, context: NSManagedObjectContext) -> Bool {
    var keyPath = item.relativePath.split(separator: "/")
      .dropLast()
      .map({ _ in return "folder" })
      .joined(separator: ".")

    keyPath += keyPath.isEmpty ? "library" : ".library"

    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()

    fetchRequest.predicate = NSPredicate(format: "relativePath == %@ && \(keyPath) != nil", item.relativePath)

    return (try? context.fetch(fetchRequest).first) != nil
  }

  func removeFolderIfNeeded(_ fileURL: URL, context: NSManagedObjectContext) throws {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

    let folderPath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())

    // Delete folder if it belongs to an orphaned folder
    if let existingFolder = getItemReference(with: folderPath, context: context) as? Folder {
      if !self.hasLibraryLinked(item: existingFolder, context: context) {
        // Delete folder if it doesn't belong to active folder
        try FileManager.default.removeItem(at: fileURL)
        self.dataManager.delete(existingFolder, context: context)
      }
    } else {
      // Delete folder if it doesn't belong to active folder
      try FileManager.default.removeItem(at: fileURL)
    }
  }

  public func createFolder(with title: String, inside relativePath: String?) async throws -> SimpleLibraryItem {
    return try await withCheckedThrowingContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard let self else {
          continuation.resume(throwing: BookPlayerError.runtimeError("Deallocated self"))
          return
        }

        do {
          try createFolderOnDisk(title: title, inside: relativePath, context: context)
        } catch {
          continuation.resume(throwing: error)
          return
        }

        let newFolder = Folder(title: title, context: context)
        newFolder.orderRank = getNextOrderRank(in: relativePath, context: context)
        /// Override relative path
        if let relativePath {
          newFolder.relativePath = "\(relativePath)/\(title)"
        }

        // insert into existing folder or library at index
        if let parentPath = relativePath {
          guard
            let parentFolder = getItemReference(with: parentPath, context: context) as? Folder
          else {
            continuation.resume(throwing: BookPlayerError.runtimeError("Parent folder does not exist at: \(parentPath)"))
            return
          }

          let existingParentContentsCount = getMaxItemsCount(at: parentPath, context: context)
          parentFolder.addToItems(newFolder)
          parentFolder.details = String.localizedStringWithFormat("files_title".localized, existingParentContentsCount + 1)
        } else {
          getLibraryReference(context: context).addToItems(newFolder)
        }

        dataManager.saveContext(context)

        continuation.resume(returning: SimpleLibraryItem(from: newFolder))
      }
    }
  }

  public func updateFolder(at relativePath: String, type: SimpleItemType) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          let folder = self.getItem(with: relativePath, context: context) as? Folder
        else {
          continuation.resume(throwing: BookPlayerError.runtimeError("Can't find the folder"))
          return
        }

        var metadataUpdates: [String: Any] = [
          #keyPath(LibraryItem.relativePath): relativePath,
          #keyPath(LibraryItem.type): type.rawValue,
        ]

        switch type {
        case .folder:
          folder.type = .folder
          folder.lastPlayDate = nil
          metadataUpdates[#keyPath(LibraryItem.lastPlayDate)] = ""
        case .bound:
          guard let items = folder.items?.allObjects as? [Book] else {
            continuation.resume(throwing: BookPlayerError.runtimeError("The folder needs to only contain book items"))
            return
          }

          guard !items.isEmpty else {
            continuation.resume(throwing: BookPlayerError.runtimeError("The folder can't be empty"))
            return
          }

          for item in items {
            item.lastPlayDate = nil
            metadataPassthroughPublisher.send([
              #keyPath(LibraryItem.relativePath): item.relativePath!,
              #keyPath(LibraryItem.lastPlayDate): "",
            ])
          }

          folder.type = .bound
        case .book:
          return
        }

        metadataPassthroughPublisher.send(metadataUpdates)

        self.dataManager.saveContext(context)
      }
    }
  }

  /// Internal function to calculate the entire folder's progress
  func calculateFolderProgress(at relativePath: String, context: NSManagedObjectContext) -> (Double, Int) {
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
      let results = try? context.fetch(fetchRequest) as? [[String: Double]],
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
    dataManager.performBackgroundTask { [weak self] context in
      self?.rebuildFolderDetails(relativePath, context: context)
    }
  }

  func rebuildFolderDetails(_ relativePath: String, context: NSManagedObjectContext) {
    guard let folder = getItemReference(with: relativePath, context: context) as? Folder else { return }

    let (progress, contentsCount) = calculateFolderProgress(at: relativePath, context: context)
    folder.percentCompleted = progress
    folder.duration = calculateFolderDuration(at: relativePath, context: context)
    folder.details = String.localizedStringWithFormat("files_title".localized, contentsCount)

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.percentCompleted): progress,
      #keyPath(LibraryItem.duration): folder.duration,
      #keyPath(LibraryItem.details): folder.details!,
    ])

    dataManager.saveContext(context)

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath,
      context: context
    ) as? String {
      rebuildFolderDetails(parentFolderPath, context: context)
    }
  }

  public func recursiveFolderProgressUpdate(from relativePath: String) {
    dataManager.performBackgroundTask { [weak self] context in
      self?.recursiveFolderProgressUpdate(from: relativePath, context: context)
    }
  }

  func recursiveFolderProgressUpdate(from relativePath: String, context: NSManagedObjectContext) {
    guard let folder = getItemReference(with: relativePath, context: context) as? Folder else { return }

    let (progress, _) = calculateFolderProgress(at: relativePath, context: context)
    folder.percentCompleted = progress

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.percentCompleted): progress,
    ])
    /// TODO: verify if necessary to mark the folder as finished

    NotificationCenter.default.post(
      name: .folderProgressUpdated,
      object: nil,
      userInfo: [
        "relativePath": relativePath,
        "progress": progress
      ]
    )

    dataManager.saveContext(context)

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath,
      context: context
    ) as? String {
      recursiveFolderProgressUpdate(from: parentFolderPath, context: context)
    }
  }

  public func renameBook(at relativePath: String, with newTitle: String) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          let item = self.getItemReference(with: relativePath, context: context)
        else {
          continuation.resume()
          return
        }

        item.title = newTitle

        metadataPassthroughPublisher.send([
          #keyPath(LibraryItem.relativePath): relativePath,
          #keyPath(LibraryItem.title): newTitle,
        ])

        self.dataManager.saveContext(context)
      }
    }
  }

  // swiftlint:disable:next function_body_length
  public func renameFolder(at relativePath: String, with newTitle: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          let folder = self.getItemReference(with: relativePath, context: context) as? Folder
        else {
          continuation.resume(returning: relativePath)
          return
        }

        let processedFolderURL = DataManager.getProcessedFolderURL()

        let sourceUrl = processedFolderURL
          .appendingPathComponent(folder.relativePath)

        let destinationUrl: URL
        let newRelativePath: String

        if let parentFolderPath = getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: folder.relativePath,
          context: context
        ) as? String {
          destinationUrl = processedFolderURL
            .appendingPathComponent(parentFolderPath)
            .appendingPathComponent(newTitle)
          newRelativePath = destinationUrl.relativePath(to: processedFolderURL)
        } else {
          destinationUrl = processedFolderURL
            .appendingPathComponent(newTitle)
          newRelativePath = newTitle
        }

        do {
          try FileManager.default.moveItem(
            at: sourceUrl,
            to: destinationUrl
          )
        } catch {
          continuation.resume(throwing: error)
          return
        }

        folder.originalFileName = newTitle
        folder.relativePath = newRelativePath
        folder.title = newTitle

        if let items = fetchRawContents(
          at: relativePath,
          propertiesToFetch: [
            #keyPath(LibraryItem.relativePath),
            #keyPath(LibraryItem.originalFileName)
          ],
          context: context
        ) {
          for item in items {
            rebuildRelativePaths(for: item, parentFolder: folder.relativePath, context: context)
          }
        }

        self.dataManager.saveContext(context)

        continuation.resume(returning: newRelativePath)
      }
    }
  }

  public func updateDetails(at relativePath: String, details: String) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          let item = self.getItemReference(with: relativePath, context: context)
        else {
          continuation.resume()
          return
        }

        item.details = details

        metadataPassthroughPublisher.send([
          #keyPath(LibraryItem.relativePath): relativePath,
          #keyPath(LibraryItem.details): details,
        ])

        self.dataManager.saveContext(context)
        continuation.resume()
      }
    }
  }

  /// Internal function to calculate the entire folder's duration
  func calculateFolderDuration(at relativePath: String, context: NSManagedObjectContext) -> Double {
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
      let results = try? context.fetch(fetchRequest).first as? [String: Double]
    else {
      return 0
    }

    return results["totalDuration"] ?? 0
  }

  public func reorderItem(
    with relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  ) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          var contents = fetchRawContents(
            at: folderRelativePath,
            propertiesToFetch: [
              #keyPath(LibraryItem.relativePath),
              #keyPath(LibraryItem.orderRank)
            ],
            context: context
          )
        else {
          continuation.resume()
          return
        }

        let movedItem = contents.remove(at: sourceIndexPath.row)
        contents.insert(movedItem, at: destinationIndexPath.row)

        /// Rebuild order rank
        for (index, item) in contents.enumerated() {
          item.orderRank = Int16(index)
          metadataPassthroughPublisher.send([
            #keyPath(LibraryItem.relativePath): item.relativePath!,
            #keyPath(LibraryItem.orderRank): item.orderRank,
          ])
        }

        self.dataManager.saveContext(context)
        continuation.resume()
      }
    }
  }

  public func sortContents(at relativePath: String?, by type: SortType) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard
          let self,
          let results = fetchRawContents(at: relativePath, propertiesToFetch: type.fetchProperties(), context: context),
          !results.isEmpty
        else {
          continuation.resume()
          return
        }

        let sortedResults = type.sortItems(results)

        /// Rebuild order rank
        for (index, item) in sortedResults.enumerated() {
          item.orderRank = Int16(index)
          metadataPassthroughPublisher.send([
            #keyPath(LibraryItem.relativePath): item.relativePath!,
            #keyPath(LibraryItem.orderRank): item.orderRank,
          ])
        }

        self.dataManager.saveContext(context)
        continuation.resume()
      }
    }
  }

  public func updatePlaybackTime(relativePath: String, time: Double, date: Date, scheduleSave: Bool) {
    dataManager.performBackgroundTask { [weak self] context in
      guard
        let self,
        let item = self.getItem(with: relativePath, context: context)
      else { return }

      /// Metadata update already handled by the socket for playback
      item.currentTime = time
      item.lastPlayDate = date
      item.percentCompleted = round((item.currentTime / item.duration) * 100)

      if let parentFolderPath = item.folder?.relativePath {
        recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date, context: context)
      }

      if scheduleSave {
        dataManager.scheduleSaveContext(context)
      } else {
        dataManager.saveContext(context)
      }
    }
  }

  func recursiveFolderLastPlayedDateUpdate(from relativePath: String, date: Date, context: NSManagedObjectContext) {
    guard let folder = getItemReference(with: relativePath, context: context) as? Folder else { return }

    folder.lastPlayDate = date

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.lastPlayDate): date.timeIntervalSince1970,
    ])

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath,
      context: context
    ) as? String {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date, context: context)
    }
  }

  public func updateBookSpeed(at relativePath: String, speed: Float) {
    dataManager.performBackgroundTask { [weak self] context in
      guard
        let self,
        let item = self.getItem(with: relativePath, context: context)
      else { return }

      item.speed = speed
      item.folder?.speed = speed

      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): relativePath,
        #keyPath(LibraryItem.speed): speed,
      ])

      if let folder = item.folder,
         let folderPath = folder.relativePath {
        metadataPassthroughPublisher.send([
          #keyPath(LibraryItem.relativePath): folderPath,
          #keyPath(LibraryItem.speed): speed,
        ])
      }

      self.dataManager.saveContext(context)
    }
  }

  public func getItemSpeed(at relativePath: String) -> Float {
    guard let item = self.getItem(with: relativePath, context: dataManager.getContext()) else { return 1.0 }

    return item.folder?.speed ?? item.speed
  }

  public func markAsFinished(flag: Bool, relativePath: String) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        self?.markAsFinished(flag: flag, relativePath: relativePath, context: context)
        continuation.resume()
      }
    }
  }

  func markAsFinished(flag: Bool, relativePath: String, context: NSManagedObjectContext) {
    guard let item = self.getItem(with: relativePath, context: context) else { return }

    switch item {
    case let folder as Folder:
      self.markAsFinished(flag: flag, folder: folder, context: context)
    case let book as Book:
      self.markAsFinished(flag: flag, book: book, context: context)
    default:
      break
    }
  }

  func markAsFinished(flag: Bool, book: Book, context: NSManagedObjectContext) {
    var metadataUpdates: [String: Any] = [
      #keyPath(LibraryItem.relativePath): book.relativePath!,
      #keyPath(LibraryItem.isFinished): flag,
    ]

    book.isFinished = flag
    // To avoid progress display side-effects
    if !flag,
       book.currentTime.rounded(.up) == book.duration.rounded(.up) {
      book.currentTime = 0.0
      metadataUpdates[#keyPath(LibraryItem.currentTime)] = 0
    }

    metadataPassthroughPublisher.send(metadataUpdates)

    self.dataManager.saveContext(context)
  }

  func markAsFinished(flag: Bool, folder: Folder, context: NSManagedObjectContext) {
    folder.isFinished = flag

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): folder.relativePath!,
      #keyPath(LibraryItem.isFinished): flag,
    ])

    guard let itemIdentifiers = getItemIdentifiers(in: folder.relativePath, context: context) else {
      context.saveContext()
      return
    }

    for itemIdentifier in itemIdentifiers {
      markAsFinished(flag: flag, relativePath: itemIdentifier, context: context)
    }
  }

  public func jumpToStart(relativePath: String) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        self?.jumpToStart(relativePath: relativePath, context: context)
        continuation.resume()
      }
    }
  }

  func jumpToStart(relativePath: String, context: NSManagedObjectContext) {
    guard let item = getItemReference(with: relativePath, context: context) else { return }

    switch item {
    case let folder as Folder:
      self.jumpToStart(folder: folder, context: context)
    case let book as Book:
      self.jumpToStart(book: book, context: context)
    default:
      break
    }
  }

  func jumpToStart(book: Book, context: NSManagedObjectContext) {
    book.currentTime = 0
    book.percentCompleted = 0
    book.isFinished = false

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): book.relativePath!,
      #keyPath(LibraryItem.currentTime): 0,
      #keyPath(LibraryItem.percentCompleted): 0,
      #keyPath(LibraryItem.isFinished): false,
    ])

    dataManager.saveContext(context)
  }

  func jumpToStart(folder: Folder, context: NSManagedObjectContext) {
    folder.currentTime = 0
    folder.percentCompleted = 0
    folder.isFinished = false

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): folder.relativePath!,
      #keyPath(LibraryItem.currentTime): 0,
      #keyPath(LibraryItem.percentCompleted): 0,
      #keyPath(LibraryItem.isFinished): false,
    ])

    guard let itemIdentifiers = getItemIdentifiers(in: folder.relativePath, context: context) else {
      context.saveContext()
      return
    }

    for itemIdentifier in itemIdentifiers {
      jumpToStart(relativePath: itemIdentifier, context: context)
    }
  }
}

// MARK: - Time record

extension LibraryService {
  public func getCurrentPlaybackRecordTime() async -> Double {
    let calendar = Calendar.current
    let today = Date()
    let dateFrom = calendar.startOfDay(for: today)
    let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)!

    return await getFirstPlaybackRecordTime(from: dateFrom, to: dateTo)
  }

  public func getFirstPlaybackRecordTime(
    from startDate: Date,
    to endDate: Date
  ) async -> Double {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let playbackRecord = self?.getFirstPlaybackRecord(from: startDate, to: endDate, context: context)

        continuation.resume(returning: playbackRecord?.time ?? 0)
      }
    }
  }

  func getCurrentPlaybackRecord(context: NSManagedObjectContext) -> PlaybackRecord {
    let calendar = Calendar.current
    let today = Date()
    let dateFrom = calendar.startOfDay(for: today)
    let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)!

    if let playbackRecord = getFirstPlaybackRecord(from: dateFrom, to: dateTo, context: context) {
      return playbackRecord
    }

    let playbackRecord = PlaybackRecord.create(in: context)
    context.saveContext()

    return playbackRecord
  }

  /// Fetch the first playback record found between two dates
  func getFirstPlaybackRecord(
    from startDate: Date,
    to endDate: Date,
    context: NSManagedObjectContext
  ) -> PlaybackRecord? {
    let fromPredicate = NSPredicate(format: "date >= %@", startDate as NSDate)
    let toPredicate = NSPredicate(format: "date < %@", endDate as NSDate)
    let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])

    let fetch: NSFetchRequest<PlaybackRecord> = PlaybackRecord.fetchRequest()
    fetch.predicate = datePredicate

    return try? context.fetch(fetch).first
  }

  public func recordTime() {
    dataManager.performBackgroundTask { [weak self] context in
      guard let playbackRecord = self?.getCurrentPlaybackRecord(context: context) else {
        return
      }

      playbackRecord.time += 1
      self?.dataManager.scheduleSaveContext(context)
    }
  }

  public func getTotalListenedTime() async -> TimeInterval {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { context in
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
          let results = try? context.fetch(fetchRequest).first as? [String: Double]
        else {
          continuation.resume(returning: 0)
          return
        }

        continuation.resume(returning: results["totalTime"] ?? 0)
      }
    }
  }
}

// MARK: - Bookmarks
extension LibraryService {
  func buildBookmarksFetchRequest(
    properties: [String],
    time: Double?,
    relativePath: String,
    type: BookmarkType
  ) -> NSFetchRequest<NSDictionary> {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Bookmark")
    fetchRequest.propertiesToFetch = SimpleBookmark.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType
    if let time {
      fetchRequest.predicate = NSPredicate(
        format: "%K == %@ && type == %d && time == %f",
        #keyPath(Bookmark.item.relativePath),
        relativePath,
        type.rawValue,
        floor(time)
      )
    } else {
      fetchRequest.predicate = NSPredicate(
        format: "%K == %@ && type == %d",
        #keyPath(Bookmark.item.relativePath),
        relativePath,
        type.rawValue
      )
    }
    let sort = NSSortDescriptor(key: #keyPath(Bookmark.time), ascending: true)
    fetchRequest.sortDescriptors = [sort]

    return fetchRequest
  }

  func parseFetchedBookmarks(from results: [[String: Any]]?) -> [SimpleBookmark]? {
    return results?.compactMap({ dictionary -> SimpleBookmark? in
      guard
        let time = dictionary["time"] as? Double,
        let relativePath = dictionary["item.relativePath"] as? String,
        let rawType = dictionary["type"] as? Int16,
        let type = BookmarkType(rawValue: rawType)
      else { return nil }

      return SimpleBookmark(
        time: time,
        note: dictionary["note"] as? String,
        type: type,
        relativePath: relativePath
      )
    })
  }

  func getBookmarkReference(from bookmark: SimpleBookmark, context: NSManagedObjectContext) -> Bookmark? {
    let fetchRequest = Self.bookmarkReferenceFetchRequest(bookmark: bookmark)

    return try? context.fetch(fetchRequest).first
  }

  public func getBookmarks(of type: BookmarkType, relativePath: String) async -> [SimpleBookmark]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let fetchRequest = Self.simpleBookmarkFetchRequest(
          time: nil,
          relativePath: relativePath,
          type: type
        )

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        continuation.resume(returning: self?.parseFetchedBookmarks(from: results))
      }
    }
  }

  public func getBookmark(
    at time: Double,
    relativePath: String,
    type: BookmarkType
  ) -> SimpleBookmark? {
    return getBookmark(at: time, relativePath: relativePath, type: type, context: dataManager.getContext())
  }

  func getBookmark(
    at time: Double,
    relativePath: String,
    type: BookmarkType,
    context: NSManagedObjectContext
  ) -> SimpleBookmark? {
    let fetchRequest = Self.simpleBookmarkFetchRequest(
      time: time,
      relativePath: relativePath,
      type: type
    )
    fetchRequest.fetchLimit = 1

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedBookmarks(from: results)?.first
  }

  public func createBookmark(at time: Double, relativePath: String, type: BookmarkType) async -> SimpleBookmark? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        guard let self else {
          continuation.resume(returning: nil)
          return
        }

        let finalTime = floor(time)

        if let bookmark = self.getBookmark(at: finalTime, relativePath: relativePath, type: type, context: context) {
          continuation.resume(returning: bookmark)
          return
        }

        guard let item = self.getItemReference(with: relativePath, context: context) else {
          continuation.resume(returning: nil)
          return
        }

        let bookmark = Bookmark(with: finalTime, type: type, context: context)
        item.addToBookmarks(bookmark)

        self.dataManager.saveContext(context)

        continuation.resume(returning: SimpleBookmark(
          time: finalTime,
          note: nil,
          type: type,
          relativePath: relativePath
        ))
      }
    }
  }

  public func addNote(_ note: String, bookmark: SimpleBookmark) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        if let bookmarkReference = self?.getBookmarkReference(from: bookmark, context: context) {
          bookmarkReference.note = note
        }

        self?.dataManager.saveContext(context)

        continuation.resume()
      }
    }
  }

  public func deleteBookmark(_ bookmark: SimpleBookmark) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        if let bookmarkReference = self?.getBookmarkReference(from: bookmark, context: context) {
          let itemReference = self?.getItemReference(with: bookmark.relativePath, context: context)
          itemReference?.removeFromBookmarks(bookmarkReference)
          self?.dataManager.delete(bookmarkReference, context: context)
        }

        continuation.resume()
      }
    }
  }
}
