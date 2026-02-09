//
//  LibraryService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/21/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Combine
import CoreData
import Foundation

/// sourcery: AutoMockable
public protocol LibraryServiceProtocol: AnyObject {
  /// Metadata publisher that collects changes during 10 seconds before normalizing the payload
  var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> { get }
  /// Progress publisher that debounces changes during 10 seconds before emitting the last payload
  var progressUpdatePublisher: AnyPublisher<[String: Any], Never> { get }
  /// Immediate progress publisher for real-time UI updates (no throttling)
  var immediateProgressUpdatePublisher: AnyPublisher<[String: Any], Never> { get }

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
  @MainActor func insertItems(from files: [URL]) async -> [SimpleLibraryItem]
  /// Move items between folders
  func moveItems(_ items: [String], inside relativePath: String?) throws
  /// Delete items
  func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) throws

  /// Fetch folder or library contents at the specified path
  func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]?
  /// Fetch all the stored identifiers in the library
  /// Note: This is meant for debugging purposes
  func fetchIdentifiers() -> [String]
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
  /// Global search across all books in the library
  func searchAllBooks(
    query: String?,
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
  func createBook(from url: URL) async -> Book
  /// Load metadata chapters if needed
  func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async
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

  /// HardcoverBook
  /// Set hardcover book for an item (nil to remove)
  func setHardcoverBook(_ hardcoverBook: SimpleHardcoverBook?, for relativePath: String) async
  /// Get hardcover book for an item
  func getHardcoverBook(for relativePath: String) async -> SimpleHardcoverBook?
}

// swiftlint:disable force_cast
@Observable
public final class LibraryService: LibraryServiceProtocol, @unchecked Sendable {
  var dataManager: DataManager!
  var audioMetadataService: AudioMetadataServiceProtocol!

  /// Internal passthrough publisher for emitting metadata update events
  private var metadataPassthroughPublisher = PassthroughSubject<[String: Any], Never>()
  /// Internal passthrough publisher for emitting item's progress update events
  private var progressPassthroughPublisher = PassthroughSubject<[String: Any], Never>()
  /// Public metadata publisher that collects changes during 10 seconds before normalizing the payload
  public var metadataUpdatePublisher = PassthroughSubject<[String: Any], Never>()
    .eraseToAnyPublisher()
  /// Public progress publisher that debounces changes during 10 seconds before emitting the last event
  public var progressUpdatePublisher = PassthroughSubject<[String: Any], Never>()
    .eraseToAnyPublisher()
  /// Immediate progress publisher for real-time UI updates (no throttling)
  public var immediateProgressUpdatePublisher = PassthroughSubject<[String: Any], Never>()
    .eraseToAnyPublisher()

  public init() {}

  public func setup(dataManager: DataManager, audioMetadataService: AudioMetadataServiceProtocol) {
    self.dataManager = dataManager
    self.audioMetadataService = audioMetadataService

    metadataUpdatePublisher =
      metadataPassthroughPublisher
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

    progressUpdatePublisher =
      progressPassthroughPublisher
      .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
      .eraseToAnyPublisher()

    immediateProgressUpdatePublisher =
      metadataPassthroughPublisher
      .eraseToAnyPublisher()
  }

  private func rebuildRelativePaths(for item: LibraryItem, parentFolder: String?) {
    let context = dataManager.getContext()

    rebuildRelativePaths(
      for: item,
      parentFolder: parentFolder,
      context: context
    )
  }

  private func rebuildRelativePaths(
    for item: LibraryItem,
    parentFolder: String?,
    context: NSManagedObjectContext
  ) {
    let originalPath = item.relativePath!

    switch item {
    case let book as Book:
      if let parentPath = parentFolder {
        let itemRelativePath = book.relativePath.split(separator: "/").map({ String($0) }).last ?? book.relativePath
        book.relativePath = "\(parentPath)/\(itemRelativePath!)"
      } else {
        book.relativePath = book.originalFileName
      }

      ArtworkService.moveCachedImage(from: originalPath, to: book.relativePath)
    case let folder as Folder:
      /// Get contents before updating relative path
      let contents =
        fetchRawContents(
          at: folder.relativePath,
          propertiesToFetch: [
            #keyPath(LibraryItem.relativePath),
            #keyPath(LibraryItem.originalFileName),
          ],
          context: context
        ) ?? []

      if let parentPath = parentFolder {
        let itemRelativePath = folder.relativePath.split(separator: "/").map({ String($0) }).last ?? folder.relativePath
        folder.relativePath = "\(parentPath)/\(itemRelativePath!)"
      } else {
        folder.relativePath = folder.originalFileName
      }

      ArtworkService.moveCachedImage(from: originalPath, to: folder.relativePath)

      for nestedItem in contents {
        rebuildRelativePaths(for: nestedItem, parentFolder: folder.relativePath, context: context)
      }
    default:
      break
    }
  }

  func getItemReference(with relativePath: String, context: NSManagedObjectContext) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = [
      #keyPath(LibraryItem.relativePath),
      #keyPath(LibraryItem.originalFileName),
    ]

    return try? context.fetch(fetchRequest).first
  }

  func getItemReference(with relativePath: String) -> LibraryItem? {
    return getItemReference(with: relativePath, context: dataManager.getContext())
  }

  public func hasItemProperty(_ property: String, relativePath: String) -> Bool {
    let context = dataManager.getContext()

    return hasItemProperty(
      property,
      relativePath: relativePath,
      context: context
    )
  }

  public func hasItemProperty(
    _ property: String,
    relativePath: String,
    context: NSManagedObjectContext
  ) -> Bool {
    let booleanExpression = NSExpressionDescription()
    booleanExpression.name = "hasProperty"
    booleanExpression.expressionResultType = NSAttributeType.booleanAttributeType
    booleanExpression.expression = NSExpression(
      forConditional: NSPredicate(
        format: "%K != nil",
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

    let result = try? context.fetch(fetchRequest).first as? [String: Bool]

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

  func parseFetchedItems(from results: [[String: Any]]?, context: NSManagedObjectContext) -> [SimpleLibraryItem]? {
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
        self?.rebuildFolderDetails(relativePath, context: context)
      } else if type == .folder && (percentCompleted.isNaN || percentCompleted.isInfinite) {
        self?.rebuildFolderDetails(relativePath, context: context)
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

  func getNextOrderRank(in folderPath: String?) -> Int16 {
    let context = dataManager.getContext()

    return getNextOrderRank(in: folderPath, context: context)
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
      !query.isEmpty
    {
      predicates.append(
        NSPredicate(
          format: "%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@",
          #keyPath(LibraryItem.title),
          query,
          #keyPath(LibraryItem.details),
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

  func getLibraryReference(context: NSManagedObjectContext) -> Library {
    let fetch: NSFetchRequest<Library> = Library.fetchRequest()
    fetch.includesPropertyValues = false
    fetch.fetchLimit = 1

    return (try? context.fetch(fetch).first)!
  }

  public func getLibraryReference() -> Library {
    return getLibraryReference(context: dataManager.getContext())
  }

  private func createLibrary() -> Library {
    let context = self.dataManager.getContext()
    let library = Library.create(in: context)
    self.dataManager.saveSyncContext(context)
    return library
  }

  public func getLibraryLastItem() -> SimpleLibraryItem? {
    let context = self.dataManager.getContext()
    return getLibraryLastItem(context: context)
  }

  func getLibraryLastItem(context: NSManagedObjectContext) -> SimpleLibraryItem? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "Library")
    fetchRequest.propertiesToFetch = ["lastPlayedItem"]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let dict = (try? context.fetch(fetchRequest))?.first as? [String: NSManagedObjectID],
      let itemId = dict["lastPlayedItem"],
      let item = try? context.existingObject(with: itemId) as? LibraryItem
    else {
      return nil
    }

    return SimpleLibraryItem(from: item)
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
    let context = dataManager.getContext()
    let library = getLibraryReference(context: context)

    library.currentTheme =
      getTheme(with: simpleTheme.title)
      ?? Theme(
        simpleTheme: simpleTheme,
        context: context
      )

    self.dataManager.saveSyncContext(context)
  }

  private func getTheme(with title: String) -> Theme? {
    let fetchRequest: NSFetchRequest<Theme> = Theme.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "title == %@", title)
    fetchRequest.fetchLimit = 1
    fetchRequest.returnsObjectsAsFaults = false

    return try? self.dataManager.getContext().fetch(fetchRequest).first
  }

  public func setLibraryLastBook(with relativePath: String?) {
    setLibraryLastBook(with: relativePath, context: dataManager.getContext())
  }

  func setLibraryLastBook(with relativePath: String?, context: NSManagedObjectContext) {
    let library = getLibraryReference(context: context)

    if let relativePath = relativePath {
      let item = getItemReference(with: relativePath, context: context)
      item?.lastPlayDate = Date()
      library.lastPlayedItem = item
    } else {
      library.lastPlayedItem = nil
    }

    dataManager.saveSyncContext(context)
  }

  @MainActor
  @discardableResult
  public func insertItems(from files: [URL]) async -> [SimpleLibraryItem] {
    return await insertItems(from: files, parentPath: nil)
  }

  /// This handles the Core Data objects creation from the Import operation. This method doesn't handle moving files on disk,
  /// as we don't want this method to throw, and the files are already in the processed folder
  @MainActor
  @discardableResult
  func insertItems(from files: [URL], parentPath: String? = nil) async -> [SimpleLibraryItem] {
    let context = dataManager.getContext()
    let library = getLibraryReference()

    var processedFiles = [SimpleLibraryItem]()
    for file in files {
      let libraryItem: LibraryItem

      if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
        let type = attributes[.type] as? FileAttributeType,
        type == .typeDirectory
      {
        libraryItem = Folder(from: file, context: context)
        /// Handle folder contents and wait for completion to ensure proper metadata extraction
        await self.handleDirectory(file)
      } else {
        // Extract metadata FIRST (includes chapters)
        let metadata = await audioMetadataService.extractMetadata(from: file)

        // Create Book with metadata
        let book = createBook(from: file, metadata: metadata, context: context)
        libraryItem = book

        // Create chapters immediately if available
        if let chapters = metadata?.chapters {
          storeChapters(chapters, for: book, context: context)
        }
      }

      libraryItem.orderRank = getNextOrderRank(in: parentPath)

      if let parentPath,
        let parentFolder = getItemReference(with: parentPath) as? Folder
      {
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

  private func createBook(from url: URL, metadata: AudioMetadata?, context: NSManagedObjectContext) -> Book {
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    let book = Book(entity: entity, insertInto: context)
    
    book.relativePath = url.relativePath(to: DataManager.getProcessedFolderURL())
    book.remoteURL = nil
    book.artworkURL = nil
    let title = metadata?.title ?? ""
    book.title = title.isEmpty ? url.lastPathComponent.replacingOccurrences(of: "_", with: " ") : title
    let artist = metadata?.artist ?? ""
    book.details = artist.isEmpty ? "voiceover_unknown_author".localized : artist
    book.duration = metadata?.duration ?? 0
    book.originalFileName = url.lastPathComponent
    book.isFinished = false
    book.type = .book
    
    return book
  }
  
  private func storeChapters(_ chapters: [ChapterMetadata], for book: Book, context: NSManagedObjectContext) {
    for chapterMeta in chapters {
      let chapter = Chapter(context: context)
      chapter.title = chapterMeta.title
      chapter.start = chapterMeta.start
      chapter.duration = chapterMeta.duration
      chapter.index = Int16(chapterMeta.index)
      book.addToChapters(chapter)
    }
  }
  
  /// Overload for backwards compatibility when we need to query by relativePath
  private func storeChapters(_ chapters: [ChapterMetadata], for relativePath: String, context: NSManagedObjectContext) {
    guard let book = getItem(with: relativePath, context: context) as? Book else {
      return
    }
    storeChapters(chapters, for: book, context: context)
  }

  @MainActor
  private func handleDirectory(_ folderURL: URL) async {
    let enumerator = FileManager.default.enumerator(
      at: folderURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
      errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      }
    )!

    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    let sortDescriptor = NSSortDescriptor(
      key: "path",
      ascending: true,
      selector: #selector(NSString.localizedStandardCompare(_:))
    )
    let orderedSet = NSOrderedSet(array: files)

    let sortedFiles = orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]

    let parentPath = folderURL.relativePath(to: DataManager.getProcessedFolderURL())
    _ = await insertItems(from: sortedFiles, parentPath: parentPath)
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
      let parentURL =
        processedFolderURL
        .appendingPathComponent(parentPath)

      try DataManager.createBackingFolderIfNeeded(parentURL)

      destinationUrl =
        parentURL
        .appendingPathComponent(sourceUrl.lastPathComponent)
    } else {
      destinationUrl =
        processedFolderURL
        .appendingPathComponent(sourceUrl.lastPathComponent)
    }

    try FileManager.default.moveItem(
      at: sourceUrl,
      to: destinationUrl
    )
  }

  public func moveItems(_ items: [String], inside relativePath: String?) throws {
    let context = dataManager.getContext()

    try moveItems(items, inside: relativePath, context: context)
  }

  public func moveItems(
    _ items: [String],
    inside relativePath: String?,
    context: NSManagedObjectContext
  ) throws {
    var folder: Folder?
    let library = self.getLibraryReference(context: context)

    if let relativePath = relativePath,
      let folderReference = getItemReference(with: relativePath, context: context) as? Folder
    {
      folder = folderReference
    }

    /// Preserve original parent path to rebuild order rank later
    var originalParentPath: String?
    if let firstPath = items.first {
      originalParentPath =
        getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: firstPath,
          context: context
        ) as? String
    }

    let processedFolderURL = DataManager.getProcessedFolderURL()
    let startingIndex = getNextOrderRank(in: relativePath, context: context)

    for (index, itemPath) in items.enumerated() {
      guard let libraryItem = getItemReference(with: itemPath, context: context) else {
        continue
      }

      let sourceUrl =
        processedFolderURL
        .appendingPathComponent(itemPath)

      try moveFileIfNeeded(
        from: sourceUrl,
        processedFolderURL: processedFolderURL,
        parentPath: folder?.relativePath
      )

      libraryItem.orderRank = startingIndex + Int16(index)

      /// Perform relationship lookups BEFORE rebuildRelativePaths changes the entity's relativePath
      if let folder = folder {
        let hasLibraryRef = hasItemProperty(
          #keyPath(LibraryItem.library),
          relativePath: itemPath,
          context: context
        )

        rebuildRelativePaths(
          for: libraryItem,
          parentFolder: relativePath,
          context: context
        )

        if hasLibraryRef {
          library.removeFromItems(libraryItem)
          /// Explicitly clear the library relationship as safety net
          libraryItem.library = nil
        }
        folder.addToItems(libraryItem)
      } else {
        let previousParentPath = getItemProperty(
          #keyPath(LibraryItem.folder.relativePath),
          relativePath: itemPath,
          context: context
        ) as? String

        rebuildRelativePaths(
          for: libraryItem,
          parentFolder: relativePath,
          context: context
        )

        if let previousParentPath,
          let parentFolder = getItemReference(with: previousParentPath, context: context) as? Folder
        {
          parentFolder.removeFromItems(libraryItem)
          /// Explicitly clear the folder relationship as safety net
          libraryItem.folder = nil
        }
        library.addToItems(libraryItem)
      }
    }

    self.dataManager.saveSyncContext(context)

    if let folder {
      rebuildFolderDetails(folder.relativePath)
    }

    /// Also rebuild details for any moved folders to ensure correct counts
    for itemPath in items {
      let movedPath: String
      if let relativePath {
        let itemName = itemPath.split(separator: "/").last.map(String.init) ?? itemPath
        movedPath = "\(relativePath)/\(itemName)"
      } else {
        let itemName = itemPath.split(separator: "/").last.map(String.init) ?? itemPath
        movedPath = itemName
      }
      if let movedItem = getItemReference(with: movedPath, context: context),
        movedItem is Folder
      {
        rebuildFolderDetails(movedPath, context: context)
      }
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
          #keyPath(LibraryItem.orderRank),
        ]
      )
    else { return }

    for (index, item) in contents.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank,
      ])
    }

    self.dataManager.saveContext()
  }

  public func delete(_ items: [SimpleLibraryItem], mode: DeleteMode) throws {
    let context = dataManager.getContext()

    try delete(items, mode: mode, context: context)
  }

  public func delete(
    _ items: [SimpleLibraryItem],
    mode: DeleteMode,
    context: NSManagedObjectContext
  ) throws {
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
            !items.isEmpty
          {
            try moveItems(items, inside: item.parentFolder, context: context)
          }
        }

        try deleteItem(item, context: context)
      }

      /// Clean up artwork cache
      ArtworkService.removeCache(for: item.relativePath)
    }
  }

  func deleteItem(_ item: SimpleLibraryItem) throws {
    let context = dataManager.getContext()

    try deleteItem(item, context: context)
  }

  func deleteItem(
    _ item: SimpleLibraryItem,
    context: NSManagedObjectContext
  ) throws {
    // Delete file item if it exists
    let fileURL = item.fileURL
    if FileManager.default.fileExists(atPath: fileURL.path) {
      try FileManager.default.removeItem(at: fileURL)
    }
    if let bookReference = getItemReference(
      with: item.relativePath,
      context: context
    ) {
      dataManager.delete(bookReference, context: context)
    }
  }

  func deleteFolderContents(_ folder: SimpleLibraryItem) throws {
    let context = dataManager.getContext()

    try deleteFolderContents(folder, context: context)
  }

  func deleteFolderContents(_ folder: SimpleLibraryItem, context: NSManagedObjectContext) throws {
    // Delete folder contents
    guard
      let items = fetchContents(
        at: folder.relativePath,
        limit: nil,
        offset: nil,
        context: context
      )
    else { return }

    try self.delete(items, mode: .deep, context: context)
  }
}

// MARK: - Fetch library items
extension LibraryService {
  public func fetchIdentifiers() -> [String] {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.propertiesToFetch = [#keyPath(LibraryItem.relativePath)]
    let sortDescriptor = NSSortDescriptor(
      key: #keyPath(LibraryItem.relativePath),
      ascending: true,
      selector: #selector(NSString.localizedStandardCompare(_:))
    )
    fetchRequest.sortDescriptors = [sortDescriptor]

    let results = (try? self.dataManager.getContext().fetch(fetchRequest)) ?? []

    return results.map { $0.relativePath }
  }

  public func fetchContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SimpleLibraryItem]? {
    let context = dataManager.getContext()

    return fetchContents(
      at: relativePath,
      limit: limit,
      offset: offset,
      context: context
    )
  }

  public func fetchContents(
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

    return parseFetchedItems(from: results, context: context)
  }

  func fetchRawContents(at relativePath: String?, propertiesToFetch: [String]) -> [LibraryItem]? {
    let context = dataManager.getContext()

    return fetchRawContents(
      at: relativePath,
      propertiesToFetch: propertiesToFetch,
      context: context
    )
  }

  func fetchRawContents(
    at relativePath: String?,
    propertiesToFetch: [String],
    context: NSManagedObjectContext
  ) -> [LibraryItem]? {
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
    let context = dataManager.getContext()

    return getMaxItemsCount(at: relativePath, context: context)
  }

  public func getMaxItemsCount(at relativePath: String?, context: NSManagedObjectContext) -> Int {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }

    return (try? context.count(for: fetchRequest)) ?? 0
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

    let context = self.dataManager.getContext()
    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)
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

    let context = dataManager.getContext()
    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)?.first
  }

  func getItem(with relativePath: String, context: NSManagedObjectContext) -> LibraryItem? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.fetchLimit = 1

    return try? context.fetch(fetchRequest).first
  }

  public func getItem(with relativePath: String) -> LibraryItem? {
    return getItem(with: relativePath, context: dataManager.getContext())
  }

  public func getItems(
    notIn relativePaths: [String],
    parentFolder: String?,
    context: NSManagedObjectContext
  ) -> [SimpleLibraryItem]? {
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

    return parseFetchedItems(from: results, context: context)
  }

  public func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SimpleLibraryItem]? {
    return getItems(notIn: relativePaths, parentFolder: parentFolder, context: dataManager.getContext())
  }

  public func getItems(
    in relativePaths: [String],
    parentFolder: String?,
    context: NSManagedObjectContext
  ) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    if let parentFolder = parentFolder {
      fetchRequest.predicate = NSPredicate(
        format: "%K == %@ AND (%K IN %@)",
        #keyPath(LibraryItem.folder.relativePath),
        parentFolder,
        #keyPath(LibraryItem.relativePath),
        relativePaths
      )
    } else {
      fetchRequest.predicate = NSPredicate(
        format: "%K != nil AND (%K IN %@)",
        #keyPath(LibraryItem.library),
        #keyPath(LibraryItem.relativePath),
        relativePaths
      )
    }

    return try? context.fetch(fetchRequest)
  }

  public func getItemProperty(_ property: String, relativePath: String) -> Any? {
    let context = dataManager.getContext()

    return getItemProperty(
      property,
      relativePath: relativePath,
      context: context
    )
  }

  public func getItemProperty(
    _ property: String,
    relativePath: String,
    context: NSManagedObjectContext
  ) -> Any? {
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

  func getItemIdentifiers(in parentFolder: String?) -> [String]? {
    return getItemIdentifiers(in: parentFolder, context: dataManager.getContext())
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

    let context = dataManager.getContext()
    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)
  }

  public func searchAllBooks(
    query: String?,
    limit: Int?,
    offset: Int?
  ) -> [SimpleLibraryItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType

    var predicates = [NSPredicate]()

    // Apply scope filtering
    predicates.append(
      NSPredicate(format: "type != 0")
    )

    // Add search query predicate if provided (searches both title and author/details)
    if let query = query, !query.isEmpty {
      predicates.append(
        NSPredicate(
          format: "%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@",
          #keyPath(LibraryItem.title),
          query,
          #keyPath(LibraryItem.details),
          query
        )
      )
    }

    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

    // Sort by last play date descending (most recent first)
    let sort = NSSortDescriptor(key: "lastPlayDate", ascending: false)
    fetchRequest.sortDescriptors = [sort]

    if let limit = limit {
      fetchRequest.fetchLimit = limit
    }

    if let offset = offset {
      fetchRequest.fetchOffset = offset
    }

    let context = dataManager.getContext()
    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)
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
        format: "%K == %@",
        #keyPath(LibraryItem.folder.relativePath),
        parentFolder
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
      predicates.append(
        NSPredicate(
          format: "%K == 0 || %K == nil",
          #keyPath(LibraryItem.isFinished),
          #keyPath(LibraryItem.isFinished)
        )
      )
    }

    fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    let sort = NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: sortAscending)
    fetchRequest.sortDescriptors = [sort]
    fetchRequest.fetchLimit = 1
    fetchRequest.propertiesToFetch = SimpleLibraryItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType

    let context = dataManager.getContext()
    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)?.first
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
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@",
      #keyPath(Chapter.book.relativePath),
      relativePath
    )
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
  public func createBook(from url: URL) async -> Book {
    let context = dataManager.getContext()
    
    // Extract metadata using the new service
    let metadata = await audioMetadataService.extractMetadata(from: url)
    
    // Create book with extracted metadata
    let newBook = createBook(from: url, metadata: metadata, context: context)
    
    // Store chapters if available
    if let chapters = metadata?.chapters {
      storeChapters(chapters, for: newBook, context: context)
    }
    
    self.dataManager.saveSyncContext(context)
    return newBook
  }

  public func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async {
    let context = dataManager.getBackgroundContext()

    // First, check if we need to load chapters
    let needsChapters = await context.perform { [unowned self] in
      guard let book = self.getItem(with: relativePath, context: context) as? Book else {
        return false
      }
      return book.chapters?.count == 0
    }

    guard needsChapters else { return }

    // Extract metadata outside of context.perform
    guard let metadata = await audioMetadataService.extractMetadata(from: asset),
          let chapters = metadata.chapters else {
      return
    }

    // Store chapters in the context, re-checking if still needed to avoid race conditions
    await context.perform { [unowned self] in
      guard let book = self.getItem(with: relativePath, context: context) as? Book,
            book.chapters?.count == 0 else {
        return
      }
      self.storeChapters(chapters, for: book, context: context)
      self.dataManager.saveSyncContext(context)
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

    /// If the folder already exists, `withIntermediateDirectories` being true will not throw the error
    let destinationFolderExists = FileManager.default.fileExists(atPath: destinationURL.path)

    try FileManager.default.createDirectory(
      at: destinationURL,
      withIntermediateDirectories: !destinationFolderExists,
      attributes: nil
    )
  }

  func createFolderOnDisk(title: String, inside relativePath: String?) throws {
    try createFolderOnDisk(title: title, inside: relativePath, context: dataManager.getContext())
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

  func hasLibraryLinked(item: LibraryItem) -> Bool {
    hasLibraryLinked(item: item, context: dataManager.getContext())
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

  func removeFolderIfNeeded(_ fileURL: URL) throws {
    try removeFolderIfNeeded(fileURL, context: dataManager.getContext())
  }

  public func createFolder(with title: String, inside relativePath: String?) throws -> SimpleLibraryItem {
    let context = dataManager.getContext()
    try createFolderOnDisk(title: title, inside: relativePath, context: context)

    let newFolder = Folder(title: title, context: context)
    newFolder.orderRank = getNextOrderRank(in: relativePath)
    /// Override relative path
    if let relativePath {
      newFolder.relativePath = "\(relativePath)/\(title)"
    }

    // insert into existing folder or library at index
    if let parentPath = relativePath {
      guard
        let parentFolder = getItemReference(with: parentPath, context: context) as? Folder
      else {
        throw BookPlayerError.runtimeError("Parent folder does not exist at: \(parentPath)")
      }

      let existingParentContentsCount = getMaxItemsCount(at: parentPath)
      parentFolder.addToItems(newFolder)
      parentFolder.details = String.localizedStringWithFormat("files_title".localized, existingParentContentsCount + 1)
    } else {
      getLibraryReference(context: context).addToItems(newFolder)
    }

    dataManager.saveSyncContext(context)

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
      metadataUpdates[#keyPath(LibraryItem.lastPlayDate)] = 0
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
          #keyPath(LibraryItem.lastPlayDate): 0,
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
    let context = dataManager.getContext()

    return calculateFolderProgress(at: relativePath, context: context)
  }

  func calculateFolderProgress(at relativePath: String, context: NSManagedObjectContext) -> (Double, Int) {
    let totalCount = getMaxItemsCount(at: relativePath)

    guard totalCount > 0 else {
      return (0, 0)
    }

    let countExpression = NSExpressionDescription()
    countExpression.expression = NSExpression(
      forFunction: "count:",
      arguments: [
        NSExpression(forKeyPath: #keyPath(LibraryItem.relativePath))
      ]
    )
    countExpression.name = "totalCount"
    /// Largest 16-bit integer 65535
    countExpression.expressionResultType = .integer16AttributeType

    let sumExpression = NSExpressionDescription()
    sumExpression.expression = NSExpression(
      forFunction: "sum:",
      arguments: [
        NSExpression(forKeyPath: #keyPath(LibraryItem.percentCompleted))
      ]
    )
    sumExpression.name = "totalSum"
    sumExpression.expressionResultType = .doubleAttributeType

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(
      format: "%K == %@ && %K != 1",
      #keyPath(LibraryItem.folder.relativePath),
      relativePath,
      #keyPath(LibraryItem.isFinished)
    )
    fetchRequest.propertiesToFetch = [sumExpression, countExpression]
    fetchRequest.resultType = .dictionaryResultType

    guard
      let results = try? context.fetch(fetchRequest).first as? [String: Any],
      let fetchedCount = results["totalCount"] as? Int,
      var fetchedSum = results["totalSum"] as? Double
    else {
      return (0, 0)
    }

    /// Catch edge case and default to 0
    if fetchedSum == .infinity {
      fetchedSum = 0
    }

    let totalProgress = fetchedSum + Double((totalCount - fetchedCount) * 100)

    return (totalProgress / Double(totalCount), totalCount)
  }

  public func rebuildFolderDetails(_ relativePath: String) {
    let context = dataManager.getContext()

    rebuildFolderDetails(relativePath, context: context)
  }

  public func rebuildFolderDetails(_ relativePath: String, context: NSManagedObjectContext) {
    guard
      let folder = getItemReference(
        with: relativePath,
        context: context
      ) as? Folder
    else {
      return
    }

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

    dataManager.saveSyncContext(context)

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: relativePath,
      context: context
    ) as? String {
      rebuildFolderDetails(parentFolderPath, context: context)
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
        "progress": progress,
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

    let sourceUrl =
      processedFolderURL
      .appendingPathComponent(folder.relativePath)

    let destinationUrl: URL
    let newRelativePath: String

    if let parentFolderPath = getItemProperty(
      #keyPath(LibraryItem.folder.relativePath),
      relativePath: folder.relativePath
    ) as? String {
      destinationUrl =
        processedFolderURL
        .appendingPathComponent(parentFolderPath)
        .appendingPathComponent(newTitle)
      newRelativePath = destinationUrl.relativePath(to: processedFolderURL)
    } else {
      destinationUrl =
        processedFolderURL
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
        #keyPath(LibraryItem.originalFileName),
      ]
    ) {
      items.forEach({ rebuildRelativePaths(for: $0, parentFolder: folder.relativePath) })
    }

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
    let context = dataManager.getContext()

    return calculateFolderDuration(at: relativePath, context: context)
  }

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

  public func reorderItems(
    inside folderRelativePath: String?,
    fromOffsets source: IndexSet,
    toOffset destination: Int
  ) {
    guard
      var contents = fetchRawContents(
        at: folderRelativePath,
        propertiesToFetch: [
          #keyPath(LibraryItem.relativePath),
          #keyPath(LibraryItem.orderRank),
        ]
      )
    else { return }

    contents.move(fromOffsets: source, toOffset: destination)

    /// Rebuild order rank
    for (index, item) in contents.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank,
      ])
    }

    dataManager.saveContext()
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
          #keyPath(LibraryItem.orderRank),
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

    item.currentTime = time
    item.lastPlayDate = date
    let progress = round((item.currentTime / item.duration) * 100)
    let percentCompleted: Double =
      progress.isFinite
      ? progress
      : 0
    item.percentCompleted = percentCompleted

    if let parentFolderPath = item.folder?.relativePath {
      recursiveFolderLastPlayedDateUpdate(from: parentFolderPath, date: date)
    }

    if scheduleSave {
      dataManager.scheduleSaveContext()
    } else {
      dataManager.saveContext()
    }

    progressPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.currentTime): time,
      #keyPath(LibraryItem.lastPlayDate): date.timeIntervalSince1970,
      #keyPath(LibraryItem.percentCompleted): percentCompleted,
    ])
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
      let folderPath = folder.relativePath
    {
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
      book.currentTime.rounded(.up) == book.duration.rounded(.up)
    {
      book.currentTime = 0.0
      book.percentCompleted = 0.0
      metadataUpdates[#keyPath(LibraryItem.currentTime)] = Double(0)
      metadataUpdates[#keyPath(LibraryItem.percentCompleted)] = Double(0)
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
      #keyPath(LibraryItem.currentTime): Double(0),
      #keyPath(LibraryItem.percentCompleted): Double(0),
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
      #keyPath(LibraryItem.currentTime): Double(0),
      #keyPath(LibraryItem.percentCompleted): Double(0),
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

  func getBookmarkReference(from bookmark: SimpleBookmark, context: NSManagedObjectContext) -> Bookmark? {
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

    return try? context.fetch(fetchRequest).first
  }

  func getBookmarkReference(from bookmark: SimpleBookmark) -> Bookmark? {
    return getBookmarkReference(from: bookmark, context: dataManager.getContext())
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

// MARK: - HardcoverBook operations
extension LibraryService {
  public func setHardcoverBook(_ hardcoverBook: SimpleHardcoverBook?, for relativePath: String) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()

      context.perform { [unowned self, context] in
        guard
          let item = getItemReference(with: relativePath, context: context)
        else {
          continuation.resume()
          return
        }

        if let hardcoverBook = hardcoverBook {
          let entity =
            item.hardcoverBook?.update(with: hardcoverBook) ?? HardcoverBook.create(hardcoverBook, in: context)
          item.hardcoverBook = entity
        } else if let hardcoverBook = item.hardcoverBook {
          item.hardcoverBook = nil
          dataManager.delete(hardcoverBook, context: context)
        }

        dataManager.saveSyncContext(context)

        continuation.resume()
      }
    }
  }

  public func getHardcoverBook(for relativePath: String) async -> SimpleHardcoverBook? {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [context] in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
        fetchRequest.fetchLimit = 1
        fetchRequest.propertiesToFetch = [
          #keyPath(LibraryItem.hardcoverBook.id),
          #keyPath(LibraryItem.hardcoverBook.artworkURL),
          #keyPath(LibraryItem.hardcoverBook.title),
          #keyPath(LibraryItem.hardcoverBook.author),
          #keyPath(LibraryItem.hardcoverBook.status),
          #keyPath(LibraryItem.hardcoverBook.userBookID),
        ]
        fetchRequest.resultType = .dictionaryResultType

        guard
          let results = try? context.fetch(fetchRequest) as? [[String: Any]],
          let result = results.first,
          let id = result[#keyPath(LibraryItem.hardcoverBook.id)] as? Int32,
          let title = result[#keyPath(LibraryItem.hardcoverBook.title)] as? String,
          let author = result[#keyPath(LibraryItem.hardcoverBook.author)] as? String,
          let rawValue = result[#keyPath(LibraryItem.hardcoverBook.status)] as? Int16,
          let status = HardcoverBook.Status(rawValue: rawValue)
        else {
          continuation.resume(returning: nil)
          return
        }

        let userBookID = result[#keyPath(LibraryItem.hardcoverBook.userBookID)] as? Int32 ?? 0

        let hardcoverBook = SimpleHardcoverBook(
          id: Int(id),
          artworkURL: result["hardcoverBook.artworkURL"] as? URL,
          title: title,
          author: author,
          status: status,
          userBookID: userBookID != 0 ? Int(userBookID) : nil
        )

        continuation.resume(returning: hardcoverBook)
      }
    }
  }
}
// swiftlint:enable force_cast
