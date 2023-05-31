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

public protocol LibraryServiceProtocol {
  /// Metadata publisher that collects changes during 10 seconds before normalizing the payload
  var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> { get }

  /// Gets (or create) the library for the App. There should be only one Library object at all times
  func getLibrary() -> Library
  /// Get the stored library object with no properties loaded
  func getLibraryReference() -> Library
  /// Get last item played
  func getLibraryLastItem() -> SimpleLibraryItem?
  /// Get current theme selected
  func getLibraryCurrentTheme() -> SimpleTheme?
  /// Set a new theme for the library
  func setLibraryTheme(with simpleTheme: SimpleTheme)
  /// Set the last played book
  func setLibraryLastBook(with relativePath: String?)
  /// Import and insert items
  func insertItems(from files: [URL]) -> [SimpleLibraryItem]
  /// Move items between folders
  func moveItems(_ items: [String], inside relativePath: String?) throws
  /// Delete items
  func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) throws

  /// Fetch folder or library contents at the specified path
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]?
  /// Get max items count inside the specified path
  func getMaxItemsCount(at relativePath: String?) -> Int
  /// Fetch the most recent played items
  func getLastPlayedItems(limit: Int?) -> [SimpleLibraryItem]?
  /// Fetch the books that contain the file URL
  func findBooks(containing fileURL: URL) -> [Book]?
  /// Fetch a single item with properties loaded
  func getSimpleItem(with relativePath: String) -> SimpleLibraryItem?
  /// Get items not included in a specific set
  func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SimpleLibraryItem]?
  /// Fetch a property from a stored library item
  func getItemProperty(_ property: String, relativePath: String) -> Any?
  /// Search
  func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType,
    limit: Int?,
    offset: Int?
  ) -> [SimpleLibraryItem]?
  /// Autoplay
  /// Find first item that is unfinished in a folder
  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> SimpleLibraryItem?
  /// Fetch first item before a specific position in a folder
  func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> SimpleLibraryItem?
  /// Fetch first item after a specific position in a folder considering if it's unfinished or not
  func findFirstItem(in parentFolder: String?, afterRank: Int16?, isUnfinished: Bool?) -> SimpleLibraryItem?
  /// Get metadata chapters from item
  func getChapters(from relativePath: String) -> [SimpleChapter]?

  /// Update metadata
  /// Create book core data object
  func createBook(from url: URL) -> Book
  /// Load metadata chapters if needed
  func loadChaptersIfNeeded(relativePath: String, asset: AVAsset)
  /// Create folder
  func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem
  /// Update folder type
  func updateFolder(at relativePath: String, type: SimpleItemType) throws
  /// Rebuild folder details
  func rebuildFolderDetails(_ relativePath: String)
  /// Rebuild folder progress
  func recursiveFolderProgressUpdate(from relativePath: String)
  /// Rename book title
  func renameBook(at relativePath: String, with newTitle: String)
  /// Rename folder title
  func renameFolder(at relativePath: String, with newTitle: String) throws -> String
  /// Update item details
  func updateDetails(at relativePath: String, details: String)
  /// Update item order to new rank
  func reorderItem(
    with relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  )
  /// Sort entire list at the given path
  func sortContents(at relativePath: String?, by type: SortType)
  /// Playback
  /// Update playback time for item
  func updatePlaybackTime(relativePath: String, time: Double, date: Date, scheduleSave: Bool)
  /// Update item speed
  func updateBookSpeed(at relativePath: String, speed: Float)
  /// Get item speed
  func getItemSpeed(at relativePath: String) -> Float
  /// Mark item as finished
  func markAsFinished(flag: Bool, relativePath: String)
  /// Jump to the start of an item
  func jumpToStart(relativePath: String)

  /// Time listened
  /// Get playback record for the day
  func getCurrentPlaybackRecord() -> PlaybackRecord
  /// Get array of playback records across two dates
  func getPlaybackRecords(from startDate: Date, to endDate: Date) -> [PlaybackRecord]?
  /// Record a second of listened time
  func recordTime(_ playbackRecord: PlaybackRecord)
  /// Get total listened time across all items
  func getTotalListenedTime() -> TimeInterval

  /// Bookmarks
  /// Fetch bookmarks for an item
  func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]?
  /// Fetch a bookmark at a specific time
  func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark?
  /// Create a bookmark at the given time
  func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark?
  /// Add a note to a bookmark
  func addNote(_ note: String, bookmark: SimpleBookmark)
  /// Delete a bookmark
  func deleteBookmark(_ bookmark: SimpleBookmark)
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

  private func rebuildRelativePaths(for item: LibraryItem, parentFolder: String?) {
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
        ]
      ) ?? []

      if let parentPath = parentFolder {
        let itemRelativePath = folder.relativePath.split(separator: "/").map({ String($0) }).last ?? folder.relativePath
        folder.relativePath = "\(parentPath)/\(itemRelativePath!)"
      } else {
        folder.relativePath = folder.originalFileName
      }

      for nestedItem in contents {
        rebuildRelativePaths(for: nestedItem, parentFolder: folder.relativePath)
      }
    default:
      break
    }
  }

  func getItemReference(with relativePath: String) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = [
      #keyPath(LibraryItem.relativePath),
      #keyPath(LibraryItem.originalFileName)
    ]

    return try? self.dataManager.getContext().fetch(fetchRequest).first
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
    return results?.compactMap({ dictionary -> SimpleLibraryItem? in
      guard
        let title = dictionary["title"] as? String,
        let details = dictionary["details"] as? String,
        let speed = dictionary["speed"] as? Float,
        let currentTime = dictionary["currentTime"] as? Double,
        let duration = dictionary["duration"] as? Double,
        let percentCompleted = dictionary["percentCompleted"] as? Double,
        let isFinished = dictionary["isFinished"] as? Bool,
        let relativePath = dictionary["relativePath"] as? String,
        let orderRank = dictionary["orderRank"] as? Int16,
        let originalFileName = dictionary["originalFileName"] as? String,
        let rawType = dictionary["type"] as? Int16,
        let type = SimpleItemType(rawValue: rawType)
      else { return nil }

      return SimpleLibraryItem(
        title: title,
        details: details,
        speed: Double(speed),
        currentTime: currentTime,
        duration: duration,
        percentCompleted: percentCompleted,
        isFinished: isFinished,
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

  func getNextOrderRank(in folderPath: String?) -> Int16 {
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
      let results = try? dataManager.getContext().fetch(fetchRequest) as? [[String: Int16]],
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

    return (try? context.fetch(fetch).first) ?? self.createLibrary()
  }

  public func getLibraryReference() -> Library {
    let context = self.dataManager.getContext()
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.includesPropertyValues = false
    fetch.fetchLimit = 1

    return (try? context.fetch(fetch).first)!
  }

  private func createLibrary() -> Library {
    let context = self.dataManager.getContext()
    let library = Library.create(in: context)
    self.dataManager.saveContext()
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

    return getSimpleItem(with: relativePath)
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
    let library = self.getLibraryReference()

    library.currentTheme = getTheme(with: simpleTheme.title)
    ?? Theme(
      simpleTheme: simpleTheme,
      context: dataManager.getContext()
    )

    self.dataManager.saveContext()
  }

  private func getTheme(with title: String) -> Theme? {
    let fetchRequest: NSFetchRequest<Theme> = Theme.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "title == %@", title)
    fetchRequest.fetchLimit = 1
    fetchRequest.returnsObjectsAsFaults = false

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func setLibraryLastBook(with relativePath: String?) {
    let library = self.getLibraryReference()

    if let relativePath = relativePath {
      library.lastPlayedItem = getItemReference(with: relativePath)
    } else {
      library.lastPlayedItem = nil
    }

    self.dataManager.saveContext()
  }

  @discardableResult
  public func insertItems(from files: [URL]) -> [SimpleLibraryItem] {
    return insertItems(from: files, parentPath: nil)
  }

  /// This handles the Core Data objects creation from the Import operation. This method doesn't handle moving files on disk,
  /// as we don't want this method to throw, and the files are already in the processed folder
  @discardableResult
  func insertItems(from files: [URL], parentPath: String? = nil) -> [SimpleLibraryItem] {
    let context = dataManager.getContext()
    let library = getLibraryReference()

    var processedFiles = [SimpleLibraryItem]()
    for file in files {
      let libraryItem: LibraryItem

      if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
         let type = attributes[.type] as? FileAttributeType,
         type == .typeDirectory {
        libraryItem = Folder(from: file, context: context)
        /// Kick-off separate function to handle instatiating the folder contents
        self.handleDirectory(file)
      } else {
        libraryItem = Book(from: file, context: context)
      }

      libraryItem.orderRank = getNextOrderRank(in: parentPath)

      if let parentPath,
         let parentFolder = getItemReference(with: parentPath) as? Folder {
        parentFolder.addToItems(libraryItem)
        /// update details on parent folder
      } else {
        library.addToItems(libraryItem)
      }

      processedFiles.append(SimpleLibraryItem(from: libraryItem))
      dataManager.saveContext()
    }

    return processedFiles
  }

  private func handleDirectory(_ folderURL: URL) {
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
    insertItems(from: sortedFiles, parentPath: parentPath)
    rebuildFolderDetails(parentPath)
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

  public func moveItems(_ items: [String], inside relativePath: String?) throws {
    var folder: Folder?
    let library = self.getLibraryReference()

    if let relativePath = relativePath,
       let folderReference = getItemReference(with: relativePath) as? Folder {
      folder = folderReference
    }

    /// Preserve original parent path to rebuild order rank later
    var originalParentPath: String?
    if let firstPath = items.first {
      originalParentPath = getItemProperty(
        #keyPath(LibraryItem.folder.relativePath),
        relativePath: firstPath
       ) as? String
    }

    let processedFolderURL = DataManager.getProcessedFolderURL()
    let startingIndex = getNextOrderRank(in: relativePath)

    for (index, itemPath) in items.enumerated() {
      guard let libraryItem = getItemReference(with: itemPath) else { continue }

      let sourceUrl = processedFolderURL
        .appendingPathComponent(itemPath)

      try moveFileIfNeeded(
        from: sourceUrl,
        processedFolderURL: processedFolderURL,
        parentPath: folder?.relativePath
      )

      libraryItem.orderRank = startingIndex + Int16(index)
      rebuildRelativePaths(for: libraryItem, parentFolder: relativePath)

      if let folder = folder {
        /// Remove reference to Library if it exists
        if hasItemProperty(#keyPath(LibraryItem.library), relativePath: itemPath) {
          library.removeFromItems(libraryItem)
        }
        folder.addToItems(libraryItem)
      } else {
        if let parentPath = getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: itemPath
        ) as? String,
           let parentFolder = getItemReference(with: parentPath) as? Folder {
          parentFolder.removeFromItems(libraryItem)
        }
        library.addToItems(libraryItem)
      }
    }

    self.dataManager.saveContext()

    if let folder {
      rebuildFolderDetails(folder.relativePath)
    }
    if let originalParentPath {
      rebuildOrderRank(in: originalParentPath)
    }
  }

  func rebuildOrderRank(in folderRelativePath: String?) {
    guard
      let contents = fetchRawContents(
        at: folderRelativePath,
        propertiesToFetch: [
          #keyPath(LibraryItem.relativePath),
          #keyPath(LibraryItem.orderRank)
        ]
      )
    else { return }

    for (index, item) in contents.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank
      ])
    }

    self.dataManager.saveContext()
  }

  public func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) throws {
    for item in items {
      switch item.type {
      case .book:
        try deleteItem(item)
      case .bound, .folder:
        switch mode {
        case .deep:
          try deleteFolderContents(item)
        case .shallow:
          // Move children to parent folder or library
          if let items = getItemIdentifiers(in: item.relativePath),
             !items.isEmpty {
            try moveItems(items, inside: item.parentFolder)
          }
        }

        try deleteItem(item)
      }

      /// Clean up artwork cache
      ArtworkService.removeCache(for: item.relativePath)
    }
  }

  func deleteItem(_ item: SimpleLibraryItem) throws {
    // Delete file item if it exists
    let fileURL = item.fileURL
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }

    if let bookReference = getItemReference(with: item.relativePath) {
      dataManager.delete(bookReference)
    }
  }

  func deleteFolderContents(_ folder: SimpleLibraryItem) throws {
    // Delete folder contents
    guard let items = fetchContents(at: folder.relativePath, limit: nil, offset: nil) else { return }

    try self.delete(items, mode: .deep)
  }
}

// MARK: - Fetch library items
extension LibraryService {
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

  func fetchRawContents(at relativePath: String?, propertiesToFetch: [String]) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.propertiesToFetch = propertiesToFetch

    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)
    fetchRequest.sortDescriptors = [sort]

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

  public func getLastPlayedItems(limit: Int?) -> [SimpleLibraryItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "type != 0 && lastPlayDate != nil")
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType

    if let limit = limit {
      fetchRequest.fetchLimit = limit
    }

    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.lastPlayDate), ascending: false)
    fetchRequest.sortDescriptors = [sort]

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)
  }

  public func findBooks(containing fileURL: URL) -> [Book]? {
    let fetch: NSFetchRequest<Book> = Book.fetchRequest()
    fetch.predicate = NSPredicate(format: "relativePath ENDSWITH[C] %@", fileURL.lastPathComponent)
    let context = self.dataManager.getContext()

    return try? context.fetch(fetch)
  }

  public func getSimpleItem(with relativePath: String) -> SimpleLibraryItem? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)?.first
  }

  public func getItem(with relativePath: String) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SimpleLibraryItem]? {
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

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)
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

  func findFirstItem(
    in parentFolder: String?,
    rankPredicate: NSPredicate?,
    sortAscending: Bool,
    isUnfinished: Bool?
  ) -> SimpleLibraryItem? {
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

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results)?.first
  }

  public func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> SimpleLibraryItem? {
    return findFirstItem(
      in: parentFolder,
      rankPredicate: nil,
      sortAscending: true,
      isUnfinished: isUnfinished
    )
  }

  public func findFirstItem(in parentFolder: String?, beforeRank: Int16?) -> SimpleLibraryItem? {
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
  ) -> SimpleLibraryItem? {
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
}

// MARK: - Metadata update
extension LibraryService {
  public func createBook(from url: URL) -> Book {
    let newBook = Book(from: url, context: self.dataManager.getContext())
    self.dataManager.saveContext()
    return newBook
  }

  public func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) {
    guard let book = self.getItem(with: relativePath) as? Book else { return }

    book.loadChaptersIfNeeded(from: asset, context: dataManager.getContext())

    dataManager.saveContext()
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

  func hasLibraryLinked(item: LibraryItem) -> Bool {
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

    let folderPath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())

    // Delete folder if it belongs to an orphaned folder
    if let existingFolder = getItemReference(with: folderPath) as? Folder {
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

  public func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem {
    try createFolderOnDisk(title: title, inside: relativePath)

    let newFolder = Folder(title: title, context: dataManager.getContext())
    newFolder.orderRank = getNextOrderRank(in: relativePath)
    /// Override relative path
    if let relativePath {
      newFolder.relativePath = "\(relativePath)/\(title)"
    }

    // insert into existing folder or library at index
    if let parentPath = relativePath {
      guard
        let parentFolder = getItemReference(with: parentPath) as? Folder
      else {
        throw BookPlayerError.runtimeError("Parent folder does not exist at: \(parentPath)")
      }

      let existingParentContentsCount = getMaxItemsCount(at: parentPath)
      parentFolder.addToItems(newFolder)
      parentFolder.details = String.localizedStringWithFormat("files_title".localized, existingParentContentsCount + 1)
    } else {
      getLibraryReference().addToItems(newFolder)
    }

    dataManager.saveContext()

    return SimpleLibraryItem(from: newFolder)
  }

  public func updateFolder(at relativePath: String, type: SimpleItemType) throws {
    guard let folder = self.getItem(with: relativePath) as? Folder else {
      throw BookPlayerError.runtimeError("Can't find the folder")
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
        throw BookPlayerError.runtimeError("The folder needs to only contain book items")
      }

      guard !items.isEmpty else {
        throw BookPlayerError.runtimeError("The folder can't be empty")
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

    self.dataManager.saveContext()
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
    guard let folder = getItemReference(with: relativePath) as? Folder else { return }

    let (progress, contentsCount) = calculateFolderProgress(at: relativePath)
    folder.percentCompleted = progress
    folder.duration = calculateFolderDuration(at: relativePath)
    folder.details = String.localizedStringWithFormat("files_title".localized, contentsCount)

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.percentCompleted): progress,
      #keyPath(LibraryItem.duration): folder.duration,
      #keyPath(LibraryItem.details): folder.details!,
    ])

    dataManager.saveContext()

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      rebuildFolderDetails(parentFolderPath)
    }
  }

  public func recursiveFolderProgressUpdate(from relativePath: String) {
    guard let folder = getItemReference(with: relativePath) as? Folder else { return }

    let (progress, _) = calculateFolderProgress(at: relativePath)
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

    dataManager.saveContext()

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      recursiveFolderProgressUpdate(from: parentFolderPath)
    }
  }

  public func renameBook(at relativePath: String, with newTitle: String) {
    guard let item = self.getItemReference(with: relativePath) else { return }

    item.title = newTitle

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.title): newTitle,
    ])

    self.dataManager.saveContext()
  }

  public func renameFolder(at relativePath: String, with newTitle: String) throws -> String {
    guard let folder = self.getItemReference(with: relativePath) as? Folder else { return relativePath }

    let processedFolderURL = DataManager.getProcessedFolderURL()

    let sourceUrl = processedFolderURL
      .appendingPathComponent(folder.relativePath)

    let destinationUrl: URL
    let newRelativePath: String

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: folder.relativePath
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

    try FileManager.default.moveItem(
      at: sourceUrl,
      to: destinationUrl
    )

    folder.originalFileName = newTitle
    folder.relativePath = newRelativePath
    folder.title = newTitle

    if let items = fetchRawContents(
      at: relativePath,
      propertiesToFetch: [
        #keyPath(LibraryItem.relativePath),
        #keyPath(LibraryItem.originalFileName)
      ]
    ) {
      items.forEach({ rebuildRelativePaths(for: $0, parentFolder: folder.relativePath) })
    }

    // TODO: Sync folder rename

    self.dataManager.saveContext()

    return newRelativePath
  }

  public func updateDetails(at relativePath: String, details: String) {
    guard let item = self.getItemReference(with: relativePath) else { return }

    item.details = details

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.details): details,
    ])
    self.dataManager.saveContext()
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

  public func reorderItem(
    with relativePath: String,
    inside folderRelativePath: String?,
    sourceIndexPath: IndexPath,
    destinationIndexPath: IndexPath
  ) {
    guard
      var contents = fetchRawContents(
        at: folderRelativePath,
        propertiesToFetch: [
          #keyPath(LibraryItem.relativePath),
          #keyPath(LibraryItem.orderRank)
        ]
      )
    else { return }

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

    self.dataManager.saveContext()
  }

  public func sortContents(at relativePath: String?, by type: SortType) {
    guard
      let results = fetchRawContents(at: relativePath, propertiesToFetch: type.fetchProperties()),
      !results.isEmpty
    else { return }

    let sortedResults = type.sortItems(results)

    /// Rebuild order rank
    for (index, item) in sortedResults.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank,
      ])
    }

    self.dataManager.saveContext()
  }

  public func updatePlaybackTime(relativePath: String, time: Double, date: Date, scheduleSave: Bool) {
    guard let item = self.getItem(with: relativePath) else { return }

    /// Metadata update already handled by the socket for playback
    item.currentTime = time
    item.lastPlayDate = date
    item.percentCompleted = round((item.currentTime / item.duration) * 100)

    if let parentFolderPath = item.folder?.relativePath {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date)
    }

    if scheduleSave {
      dataManager.scheduleSaveContext()
    } else {
      dataManager.saveContext()
    }

  }

  func recursiveFolderLastPlayedDateUpdate(from relativePath: String, date: Date) {
    guard let folder = getItemReference(with: relativePath) as? Folder else { return }

    folder.lastPlayDate = date

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.lastPlayDate): date.timeIntervalSince1970,
    ])

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath
    ) as? String {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date)
    }
  }

  public func updateBookSpeed(at relativePath: String, speed: Float) {
    guard let item = self.getItem(with: relativePath) else { return }

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

    self.dataManager.saveContext()
  }

  func markAsFinished(flag: Bool, folder: Folder) {
    folder.isFinished = flag

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): folder.relativePath!,
      #keyPath(LibraryItem.isFinished): flag,
    ])

    guard let itemIdentifiers = getItemIdentifiers(in: folder.relativePath) else { return }

    itemIdentifiers.forEach({ self.markAsFinished(flag: flag, relativePath: $0) })
  }

  public func jumpToStart(relativePath: String) {
    guard let item = getItemReference(with: relativePath) else { return }

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
    book.percentCompleted = 0
    book.isFinished = false

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): book.relativePath!,
      #keyPath(LibraryItem.currentTime): 0,
      #keyPath(LibraryItem.percentCompleted): 0,
      #keyPath(LibraryItem.isFinished): false,
    ])

    self.dataManager.saveContext()
  }

  func jumpToStart(folder: Folder) {
    folder.currentTime = 0
    folder.percentCompleted = 0
    folder.isFinished = false

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): folder.relativePath!,
      #keyPath(LibraryItem.currentTime): 0,
      #keyPath(LibraryItem.percentCompleted): 0,
      #keyPath(LibraryItem.isFinished): false,
    ])

    guard let itemIdentifiers = getItemIdentifiers(in: folder.relativePath) else { return }

    itemIdentifiers.forEach({ self.jumpToStart(relativePath: $0) })
  }
}

// MARK: - Time record
extension LibraryService {
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
    self.dataManager.scheduleSaveContext()
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

  func getBookmarkReference(from bookmark: SimpleBookmark) -> Bookmark? {

    let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@ && type == %d && time == %f",
      #keyPath(Bookmark.item.relativePath),
      bookmark.relativePath,
      bookmark.type.rawValue,
      bookmark.time
    )
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = [
      #keyPath(Bookmark.time),
      #keyPath(Bookmark.note),
      #keyPath(Bookmark.type),
    ]

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]? {
    let fetchRequest = buildBookmarksFetchRequest(
      properties: SimpleBookmark.fetchRequestProperties,
      time: nil,
      relativePath: relativePath,
      type: type
    )

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedBookmarks(from: results)
  }

  public func getBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
    let fetchRequest = buildBookmarksFetchRequest(
      properties: SimpleBookmark.fetchRequestProperties,
      time: time,
      relativePath: relativePath,
      type: type
    )
    fetchRequest.fetchLimit = 1

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedBookmarks(from: results)?.first
  }

  public func createBookmark(at time: Double, relativePath: String, type: BookmarkType) -> SimpleBookmark? {
    let finalTime = floor(time)

    if let bookmark = self.getBookmark(at: finalTime, relativePath: relativePath, type: type) {
      return bookmark
    }

    guard let item = self.getItemReference(with: relativePath) else { return nil }

    let bookmark = Bookmark(with: finalTime, type: type, context: self.dataManager.getContext())
    item.addToBookmarks(bookmark)

    self.dataManager.saveContext()

    return SimpleBookmark(
      time: finalTime,
      note: nil,
      type: type,
      relativePath: relativePath
    )
  }

  public func addNote(_ note: String, bookmark: SimpleBookmark) {
    guard
      let bookmarkReference = getBookmarkReference(from: bookmark)
    else { return }
    bookmarkReference.note = note
    self.dataManager.saveContext()
  }

  public func deleteBookmark(_ bookmark: SimpleBookmark) {
    guard
      let bookmarkReference = getBookmarkReference(from: bookmark)
    else { return }

    let item = getItemReference(with: bookmark.relativePath)
    item?.removeFromBookmarks(bookmarkReference)
    self.dataManager.delete(bookmarkReference)
  }
}
