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

public enum ImportSource {
  case local(files: [URL])
  case external(files: [SimpleExternalResource])
}

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
  /// Register files/folders already present inside the Processed folder that have no CoreData entry.
  /// Creates any missing parent `Folder` entries and clears file-protection flags so the new entries
  /// can be deleted later. URLs already registered are skipped.
  @MainActor func registerExistingProcessedItems(at urls: [URL]) async -> [SimpleLibraryItem]
  /// Move items between folders
  func moveItems(_ items: [LibraryItemRef], inside relativePath: String?) throws
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
  func getSimpleItem(for uuid: String) -> SimpleLibraryItem?
  /// Get items not included in a specific set
  func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SimpleLibraryItem]?
  /// Fetch a property from a stored library item
  func getItemProperty(_ property: String, relativePath: String) -> Any?
  /// Search the items within a folder subtree (recursive). A `nil` relativePath searches the
  /// whole library; a `nil` scope matches all item types.
  func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType?,
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
  /// Find first item (optionally: first unfinished) in a folder, in the
  /// location's effective (visible) order
  func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> SimpleLibraryItem?
  /// The parent's children as lightweight navigation entries in the location's
  /// effective (visible) order — the playback prev/next walk's data source
  func getOrderedSiblings(in parentFolder: String?) -> [SimpleNavigationItem]?
  /// Get metadata chapters from item
  func getChapters(from relativePath: String) -> [SimpleChapter]?

  /// Update metadata
  /// Create book core data object
  func createBook(from url: URL) async -> Book
  /// Load metadata chapters if needed
  func loadChaptersIfNeeded(relativePath: String, asset: AVAsset) async
  /// Re-parse chapters from the file with our manual parsers, replacing the stored list only
  /// when more chapters are found. Returns the new chapter count, or nil if nothing changed.
  func reloadChapters(relativePath: String) async -> Int?
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
  /// Apply a sort to the list at the given path: persists the sticky preference
  /// for resolvable locations (order is derived at query time); performs a
  /// one-shot rank materialization for `.unresolved` locations
  func sortContents(at relativePath: String?, by type: SortType)
  /// Freeze the location's currently-visible order into `orderRank` and
  /// transition the sticky sort to `.custom` (the picker's "Custom" option)
  func adoptCurrentOrderAsCustom(at relativePath: String?)
  /// One-off reverse: flips the current visible order at the given path and transitions
  /// the location's sticky sort to `.custom` (same transition as a manual drag-drop).
  func reverseContents(at relativePath: String?)
  /// Look up the relativePath for a library item by its uuid.
  /// Returns nil for placeholder uuids or if no matching item is found.
  func getRelativePath(forUuid uuid: String) -> String?
  /// Resolves a path into a `SortLocation`, applying the bound-folder and
  /// placeholder-UUID gates. See implementation for details.
  func makeLocation(forRelativePath relativePath: String?) -> SortLocation
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
  func createBookmark(at time: Double, relativePath: String, uuid: String, type: BookmarkType) -> SimpleBookmark?
  /// Add a note to a bookmark
  func addNote(_ note: String, bookmark: SimpleBookmark)
  /// Delete a bookmark
  func deleteBookmark(_ bookmark: SimpleBookmark)

  /// HardcoverBook
  /// Set hardcover book for an item (nil to remove)
  func setHardcoverBook(_ hardcoverBook: SimpleHardcoverBook?, for relativePath: String) async
  /// Get hardcover book for an item
  func getHardcoverBook(for relativePath: String) async -> SimpleHardcoverBook?
  /// Create an external resource linking the item (by uuid) to a provider's resource.
  /// Returns the syncable representation to upload, or nil if it already exists or the item is missing.
  func setExternalResource(providerName: String, providerId: String, for uuid: String) async -> SyncableExternalResource?
  /// Remove the external resource of the given provider from the item (by uuid).
  /// Returns the deleted resource's providerId, or nil if there was nothing to delete.
  func removeExternalResource(providerName: String, for uuid: String) async -> String?
  /// Returns the item's external resources as lightweight values.
  func getExternalResources(for relativePath: String) async -> [SimpleExternalResource]

  func findResource(for providerId: String, providerName: String?, context: NSManagedObjectContext?) -> ExternalResource?
  
  func findResources(for uuid: String, context: NSManagedObjectContext?) -> [ExternalResource]?
  
  @MainActor func insertItems(from resources: [SimpleExternalResource]) async -> [SimpleLibraryItem]
  
  func handleSyncFromExternalResouce(remoteItemsDictionary: [String: JellyfinLibraryItem])
}

// swiftlint:disable force_cast
@Observable
public final class LibraryService: LibraryServiceProtocol, BPLogger, @unchecked Sendable {
  var dataManager: DataManager!
  var audioMetadataService: AudioMetadataServiceProtocol!
  /// Sticky-sort preference resolver. Injected after construction to break the
  /// circular dependency with `PreferencesSyncService`.
  public weak var preferencesService: SortPreferencesResolving?

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

  public func getItemReference(with relativePath: String) -> LibraryItem? {
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

  /// How a contents fetch orders its results.
  enum ContentsOrdering {
    /// The location's effective sticky sort: an automatic rule becomes
    /// fetch-time sort descriptors; `.custom` (and `.unresolved`/bound
    /// locations, or when no preferences service is wired, e.g. watchOS)
    /// falls back to `orderRank`.
    case effective
    /// Raw `orderRank` — for internal reconciliation reads whose consumers
    /// are order-insensitive, and for rank mutations that operate on the
    /// stored custom arrangement.
    case byRank
  }

  /// Single choke point resolving the sort descriptors for a location.
  /// `orderRank` means only the custom arrangement; every automatic rule is
  /// applied here, at query time, never materialized into the rank column.
  func resolveSortDescriptors(
    forRelativePath relativePath: String?,
    ordering: ContentsOrdering,
    context: NSManagedObjectContext
  ) -> [NSSortDescriptor] {
    let byRank = [NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)]
    guard case .effective = ordering, let prefs = preferencesService else {
      return byRank
    }
    let location = makeLocation(forRelativePath: relativePath, context: context)
    guard case .automatic(let sort) = prefs.effectiveSort(forLocation: location) else {
      return byRank
    }
    return sort.sortDescriptors
  }

  func buildListContentsFetchRequest(
    properties: [String],
    relativePath: String?,
    limit: Int?,
    offset: Int?,
    ordering: ContentsOrdering,
    context: NSManagedObjectContext
  ) -> NSFetchRequest<NSDictionary> {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = properties
    fetchRequest.resultType = .dictionaryResultType
    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    fetchRequest.sortDescriptors = resolveSortDescriptors(
      forRelativePath: relativePath,
      ordering: ordering,
      context: context
    )

    if let limit = limit {
      fetchRequest.fetchLimit = limit
    }

    if let offset = offset {
      fetchRequest.fetchOffset = offset
    }

    return fetchRequest
  }

  /// One grouped fetch for every row's external resources — a per-row fetch here is an
  /// N+1 on the main library list path.
  private func findResourcesGrouped(forUuids uuids: [String], context: NSManagedObjectContext) -> [String: [ExternalResource]] {
    guard !uuids.isEmpty else { return [:] }
    let fetch: NSFetchRequest<ExternalResource> = ExternalResource.fetchRequest()
    fetch.predicate = NSPredicate(format: "%K IN %@", #keyPath(ExternalResource.libraryItem.uuid), uuids)
    guard let resources = try? context.fetch(fetch) else { return [:] }
    return Dictionary(grouping: resources) { $0.libraryItem?.uuid ?? "" }
  }

  func parseFetchedItems(from results: [[String: Any]]?, context: NSManagedObjectContext) -> [SimpleLibraryItem]? {
    let resourcesByUuid = findResourcesGrouped(
      forUuids: results?.compactMap { $0["uuid"] as? String } ?? [],
      context: context
    )
    return results?.compactMap({ [weak self] dictionary -> SimpleLibraryItem? in
      guard
        let uuid = dictionary["uuid"] as? String,
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

      let externalResources = resourcesByUuid[uuid]

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
        type: type,
        uuid: uuid,
        externalResources: externalResources?.map({ SimpleExternalResource(from: $0, ignoreLibraryItem: true) })
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
    scope: SimpleItemType?
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
    case .none:
      break
    }

    if let query = query,
      !query.isEmpty
    {
      predicates.append(
        NSPredicate(
          format: "%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@",
          #keyPath(LibraryItem.title),
          query,
          #keyPath(LibraryItem.details),
          query,
          #keyPath(LibraryItem.originalFileName),
          query
        )
      )
    }

    /// Scope to the folder's subtree (recursive). Matching the item's own `relativePath` against
    /// the `"<folder>/"` prefix catches direct children and nested items, while the trailing slash
    /// avoids matching sibling folders that share a name prefix (e.g. "Sci-Fi" vs "Sci-Fi 2").
    if let relativePath = relativePath {
      predicates.append(
        NSPredicate(format: "%K BEGINSWITH %@", #keyPath(LibraryItem.relativePath), relativePath + "/")
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

    return SimpleLibraryItem(
      from: item,
    )
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

  // MARK: - Import data types

  /// Represents a file's pre-extracted data, computed off the main thread
  private enum PreparedImportItem {
    case book(url: URL, metadata: AudioMetadata?)
    case directory(url: URL, sortedContents: [URL])
  }

  // MARK: - Phase 1: Background preparation (no CoreData)

  /// Pre-processes files off the main thread: checks file types, enumerates directories, and extracts audio metadata.
  /// None of this touches CoreData, so it's safe to run on any thread.
  private func prepareItems(from files: [URL]) async -> [PreparedImportItem] {
    var prepared = [PreparedImportItem]()

    for file in files {
      if let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
        let type = attributes[.type] as? FileAttributeType,
        type == .typeDirectory
      {
        let sortedContents = enumerateAndSortDirectory(file)
        prepared.append(.directory(url: file, sortedContents: sortedContents))
      } else {
        let metadata = await audioMetadataService.extractMetadata(from: file)
        prepared.append(.book(url: file, metadata: metadata))
      }
    }

    return prepared
  }

  /// Enumerates a directory's immediate contents and sorts them by path.
  private func enumerateAndSortDirectory(_ folderURL: URL) -> [URL] {
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

    // swiftlint:disable:next force_cast
    return orderedSet.sortedArray(using: [sortDescriptor]) as! [URL]
  }

  // MARK: - Phase 2: CoreData creation on MainActor

  /// This handles the Core Data objects creation from the Import operation. This method doesn't handle moving files on disk,
  /// as we don't want this method to throw, and the files are already in the processed folder
  @MainActor
  @discardableResult
  public func insertItems(from files: [URL], parentPath: String? = nil) async -> [SimpleLibraryItem] {
    // Phase 1: Extract metadata and enumerate directories off the main thread
    let preparedItems = await prepareItems(from: files)

    // Phase 2: Create CoreData entities on the main thread using pre-extracted data
    let context = dataManager.getContext()
    let library = getLibraryReference()

    var processedFiles = [SimpleLibraryItem]()
    var nextOrderRank = getNextOrderRank(in: parentPath)
    for preparedItem in preparedItems {
      let libraryItem: LibraryItem

      switch preparedItem {
      case .directory(let url, let sortedContents):
        libraryItem = Folder(from: url, context: context)
        let folderPath = url.relativePath(to: DataManager.getProcessedFolderURL())
        // Recursively prepare and insert directory contents
        let childPreparedItems = await prepareItems(from: sortedContents)
        _ = await insertPreparedItems(childPreparedItems, parentPath: folderPath)
        rebuildFolderDetails(folderPath)

      case .book(let url, let metadata):
        let book = createBook(from: url, metadata: metadata, context: context)
        libraryItem = book
        if let chapters = metadata?.chapters {
          storeChapters(chapters, for: book, context: context)
        }
      }

      libraryItem.orderRank = nextOrderRank
      nextOrderRank += 1

      if let parentPath,
        let parentFolder = getItemReference(with: parentPath) as? Folder
      {
        parentFolder.addToItems(libraryItem)
      } else {
        library.addToItems(libraryItem)
      }

      processedFiles.append(SimpleLibraryItem(from: libraryItem))
    }

    dataManager.saveContext()

    // No re-sort needed: an automatically-sorted parent derives its order from
    // the rule at query time, so the appended ranks have no visible effect there.
    // (Custom parents intentionally keep new items appended at the end.)
    return processedFiles
  }

  /// Registers files/folders that physically exist inside the Processed folder but
  /// have no CoreData entry. Walks each URL's ancestor chain, creates any missing
  /// parent `Folder` entries, then delegates the leaf to `insertItems(from:parentPath:)`.
  /// URLs whose `relativePath` already resolves to a registered item are skipped;
  /// already-registered folders still recurse so unregistered children are picked up.
  ///
  /// URLs that do not live inside `DataManager.processedFolderURL` are skipped
  /// silently (a runtime guard rejects them to prevent a malformed relativePath
  /// from creating a CoreData entry that points outside Processed). Callers should
  /// still filter via `DataManager.isURLInProcessedFolder(_:)` for clarity.
  ///
  /// - Parameter urls: Absolute URLs inside the Processed folder.
  /// - Returns: The newly inserted leaves. Excludes items that were already
  ///   registered or were rejected by the in-Processed check.
  @MainActor
  @discardableResult
  public func registerExistingProcessedItems(at urls: [URL]) async -> [SimpleLibraryItem] {
    // Process in Finder-style order so the resulting orderRank assignments match
    // the regular import flow's directory enumeration (see enumerateAndSortDirectory).
    let sortedURLs = urls.sorted {
      $0.path.localizedStandardCompare($1.path) == .orderedAscending
    }

    var registered = [SimpleLibraryItem]()

    for url in sortedURLs {
      registered.append(contentsOf: await registerExistingProcessedItem(at: url))
    }

    return registered
  }

  @MainActor
  private func registerExistingProcessedItem(at url: URL) async -> [SimpleLibraryItem] {
    guard DataManager.isURLInProcessedFolder(url) else { return [] }

    let processedFolderURL = DataManager.getProcessedFolderURL()
    let relativePath = url.relativePath(to: processedFolderURL)

    guard !relativePath.isEmpty else { return [] }

    let isDirectory =
      (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

    if let existing = getItemReference(with: relativePath) {
      var registered = [SimpleLibraryItem]()

      // Reattach orphans — entries that exist in CoreData but are detached
      // from the library hierarchy. Typically left behind by failed prior
      // recovery attempts (e.g. the old StorageView Fix flow throwing after
      // creating the Book but before attaching it).
      if existing.getLibrary() == nil {
        let parentPath = ensureAncestorFolders(forRelativePath: relativePath, processedFolderURL: processedFolderURL)
        relinkOrphan(existing, parentPath: parentPath)
        registered.append(SimpleLibraryItem(from: existing))
      }

      guard isDirectory else { return registered }

      let children = (try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )) ?? []

      for child in children {
        registered.append(contentsOf: await registerExistingProcessedItem(at: child))
      }
      return registered
    }

    let parentPath = ensureAncestorFolders(forRelativePath: relativePath, processedFolderURL: processedFolderURL)
    // Files placed via Files.app may carry the user-immutable flag or strict
    // file-protection class, which would crash later deletions. Mirror the
    // regular import flow's cleanup at ImportOperation.swift:272.
    url.disableFileProtection()
    let inserted = await insertItems(from: [url], parentPath: parentPath)
    if let parentPath {
      rebuildFolderDetails(parentPath)
    }
    return inserted
  }

  /// Walks the ancestor chain of `relativePath` (excluding the leaf), creating any
  /// missing `Folder` entries along the way so the leaf can be inserted with its
  /// correct parent. Saves the context after each new folder so subsequent lookups
  /// can resolve newly created entries.
  ///
  /// - Returns: The relativePath of the leaf's immediate parent, or `nil` if the
  ///   leaf belongs at the library root.
  @MainActor
  private func ensureAncestorFolders(
    forRelativePath relativePath: String,
    processedFolderURL: URL
  ) -> String? {
    let components = relativePath.split(separator: "/").map(String.init)
    guard components.count > 1 else { return nil }

    let context = dataManager.getContext()
    let library = getLibraryReference()
    let ancestorComponents = components.dropLast()

    var currentPath = ""
    var currentParent: Folder?

    for component in ancestorComponents {
      currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"

      let folderURL = processedFolderURL.appendingPathComponent(currentPath)
      // Clear protection on the ancestor folder itself so the user can later
      // delete the registered hierarchy. Skip recursion (the leaf already
      // disables its own subtree).
      try? (folderURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
      try? (folderURL as NSURL).setResourceValue(false, forKey: .isUserImmutableKey)

      if let existing = getItemReference(with: currentPath, context: context) as? Folder {
        currentParent = existing
        continue
      }

      let newFolder = Folder(from: folderURL, context: context)
      newFolder.orderRank = getNextOrderRank(
        in: currentParent?.relativePath,
        context: context
      )

      if let parent = currentParent {
        parent.addToItems(newFolder)
      } else {
        library.addToItems(newFolder)
      }

      dataManager.saveContext()
      currentParent = newFolder
    }

    return currentParent?.relativePath
  }

  /// Reattaches an orphaned LibraryItem (one whose `getLibrary()` returns nil) to
  /// the library hierarchy at the given parent path (or library root if nil).
  /// Assigns a fresh `orderRank` and rebuilds parent folder details.
  @MainActor
  private func relinkOrphan(_ item: LibraryItem, parentPath: String?) {
    let context = dataManager.getContext()

    if let parentPath, let parent = getItemReference(with: parentPath, context: context) as? Folder {
      parent.addToItems(item)
    } else {
      getLibraryReference().addToItems(item)
    }
    item.orderRank = getNextOrderRank(in: parentPath, context: context)
    dataManager.saveContext()

    // Recompute the relinked item's stats (no-op for books) and propagate up the chain.
    rebuildFolderDetails(item.relativePath)
    if let parentPath {
      rebuildFolderDetails(parentPath)
    }
  }

  /// Inserts already-prepared items into CoreData. Used by directory handling to avoid re-preparing.
  @MainActor
  @discardableResult
  private func insertPreparedItems(_ preparedItems: [PreparedImportItem], parentPath: String?) async -> [SimpleLibraryItem] {
    let context = dataManager.getContext()
    let library = getLibraryReference()

    var processedFiles = [SimpleLibraryItem]()
    var nextOrderRank = getNextOrderRank(in: parentPath)
    for preparedItem in preparedItems {
      let libraryItem: LibraryItem

      switch preparedItem {
      case .directory(let url, let sortedContents):
        libraryItem = Folder(from: url, context: context)
        let folderPath = url.relativePath(to: DataManager.getProcessedFolderURL())
        let childPreparedItems = await prepareItems(from: sortedContents)
        _ = await insertPreparedItems(childPreparedItems, parentPath: folderPath)
        rebuildFolderDetails(folderPath)

      case .book(let url, let metadata):
        let book = createBook(from: url, metadata: metadata, context: context)
        libraryItem = book
        if let chapters = metadata?.chapters {
          storeChapters(chapters, for: book, context: context)
        }
      }

      libraryItem.orderRank = nextOrderRank
      nextOrderRank += 1

      if let parentPath,
        let parentFolder = getItemReference(with: parentPath) as? Folder
      {
        parentFolder.addToItems(libraryItem)
      } else {
        library.addToItems(libraryItem)
      }

      processedFiles.append(SimpleLibraryItem(from: libraryItem))
    }

    dataManager.saveContext()

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
    book.uuid = UUID().uuidString
    
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

  public func moveItems(_ items: [LibraryItemRef], inside relativePath: String?) throws {
    let context = dataManager.getContext()

    try moveItems(items, inside: relativePath, context: context)
  }

  public func moveItems(
    _ items: [LibraryItemRef],
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
          relativePath: firstPath.relativePath,
          context: context
        ) as? String
    }

    let processedFolderURL = DataManager.getProcessedFolderURL()
    let startingIndex = getNextOrderRank(in: relativePath, context: context)

    for (index, itemPath) in items.enumerated() {
      guard let libraryItem = getItemReference(with: itemPath.relativePath, context: context) else {
        continue
      }

      let sourceUrl =
        processedFolderURL
        .appendingPathComponent(itemPath.relativePath)

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
          relativePath: itemPath.relativePath,
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
          relativePath: itemPath.relativePath,
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
        let itemName = itemPath.relativePath.split(separator: "/").last.map(String.init) ?? itemPath.relativePath
        movedPath = "\(relativePath)/\(itemName)"
      } else {
        let itemName = itemPath.relativePath.split(separator: "/").last.map(String.init) ?? itemPath.relativePath
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

    /// The moved items' stored relativePaths (and any folder descendants, via the
    /// path-prefix rule) are now stale, so prune them from the Last Played widget
    /// snapshot. They reappear once played again at the new location.
    SharedWidgetStore.removeItems(matching: items.map(\.relativePath))
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
          if let items = getItemPair(in: item.relativePath, context: context),
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

    /// Prune deleted items (and their descendants) from the Last Played widget snapshot.
    /// Covers both the local delete path and the remote/sync delete path, which both
    /// funnel through here. Deep folder deletes recurse into this method, so this runs
    /// once per level, but the debounced reload coalesces them into a single refresh.
    SharedWidgetStore.removeItems(matching: items.map(\.relativePath))
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
    let processedFolderURL = DataManager.getProcessedFolderURL()
    let resolvedFileURL = fileURL.standardized
    let resolvedProcessedURL = processedFolderURL.standardized

    if !item.relativePath.isEmpty,
       resolvedFileURL.path.hasPrefix(resolvedProcessedURL.path + "/"),
       FileManager.default.fileExists(atPath: fileURL.path)
    {
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
    // Delete folder contents — order-insensitive, and this runs on the sync
    // background context, so skip the preference resolution.
    guard
      let items = fetchContents(
        at: folder.relativePath,
        limit: nil,
        offset: nil,
        ordering: .byRank,
        context: context
      )
    else { return }

    try self.delete(items, mode: .deep, context: context)
  }
  
  @MainActor
  @discardableResult
  public func insertItems(from resources: [SimpleExternalResource]) async -> [SimpleLibraryItem] {
    // Phase 2: Create CoreData entities on the main thread using pre-extracted data
    let library = getLibraryReference()
    var processedFiles = [SimpleLibraryItem]()
    var nextOrderRank = getNextOrderRank(in: nil)
    for resource in resources {
      // libraryItem is optional by construction (ignoreLibraryItem paths) — a resource
      // without one cannot become a book row; skip it instead of crashing.
      guard let simpleItem = resource.libraryItem else { continue }
      let libraryItem: LibraryItem
      let book = await createExternalBook(simpleItem: simpleItem, externalResource: resource)
      libraryItem = book
      libraryItem.orderRank = nextOrderRank
      nextOrderRank += 1

      library.addToItems(libraryItem)
      processedFiles.append(SimpleLibraryItem(from: libraryItem))
    }

    dataManager.saveContext()

    return processedFiles
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

  func fetchContents(
    at relativePath: String?,
    limit: Int?,
    offset: Int?,
    ordering: ContentsOrdering = .effective,
    context: NSManagedObjectContext
  ) -> [SimpleLibraryItem]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: SimpleLibraryItem.fetchRequestProperties,
      relativePath: relativePath,
      limit: limit,
      offset: offset,
      ordering: ordering,
      context: context
    )

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]

    return parseFetchedItems(from: results, context: context)
  }

  /// Rank-ordered by the `sortedBy` default — internal reads of the stored
  /// custom arrangement.
  func fetchRawContents(at relativePath: String?, propertiesToFetch: [String]) -> [LibraryItem]? {
    return fetchRawContents(
      at: relativePath,
      propertiesToFetch: propertiesToFetch,
      context: dataManager.getContext()
    )
  }

  /// Managed-object contents fetch. Defaults to rank order (the stored custom
  /// arrangement); the rank mutations (drag/reverse/freeze) resolve the
  /// effective descriptors BEFORE flipping the sticky pref to `.custom` and
  /// pass them in explicitly.
  func fetchRawContents(
    at relativePath: String?,
    propertiesToFetch: [String],
    sortedBy sortDescriptors: [NSSortDescriptor] = [
      NSSortDescriptor(key: #keyPath(LibraryItem.orderRank), ascending: true)
    ],
    context: NSManagedObjectContext
  ) -> [LibraryItem]? {
    let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetchRequest.propertiesToFetch = propertiesToFetch

    if let relativePath = relativePath {
      fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.folder.relativePath), relativePath)
    } else {
      fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(LibraryItem.library))
    }
    fetchRequest.sortDescriptors = sortDescriptors

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
  
  public func getSimpleItem(for uuid: String) -> SimpleLibraryItem? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.uuid), uuid)
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
  
  func getItemPair(in parentFolder: String?, context: NSManagedObjectContext) -> [LibraryItemRef]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: ["relativePath", "uuid"],
      relativePath: parentFolder,
      limit: nil,
      offset: nil,
      ordering: .byRank,
      context: context
    )

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]
    return results?.compactMap({ LibraryItemRef(relativePath: $0["relativePath"] as? String ?? "", uuid: $0["uuid"] as? String ?? "") })
  }

  func getItemIdentifiers(in parentFolder: String?, context: NSManagedObjectContext) -> [String]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: ["relativePath"],
      relativePath: parentFolder,
      limit: nil,
      offset: nil,
      ordering: .byRank,
      context: context
    )

    let results = try? context.fetch(fetchRequest) as? [[String: Any]]
    return results?.compactMap({ $0["relativePath"] as? String })
  }

  public func filterContents(
    at relativePath: String?,
    query: String?,
    scope: SimpleItemType?,
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

  /// First child of the parent in its EFFECTIVE (visible) order.
  /// Note: `isUnfinished` is nil-checked only (matching the pre-existing
  /// contract) — passing `false` still filters for unfinished items.
  public func findFirstItem(in parentFolder: String?, isUnfinished: Bool?) -> SimpleLibraryItem? {
    guard let siblings = getOrderedSiblings(in: parentFolder) else { return nil }
    let first: SimpleNavigationItem?
    if isUnfinished != nil {
      first = siblings.first { !$0.isFinished }
    } else {
      first = siblings.first
    }
    guard let first else { return nil }
    return getSimpleItem(with: first.relativePath)
  }

  public func getOrderedSiblings(in parentFolder: String?) -> [SimpleNavigationItem]? {
    let context = dataManager.getContext()
    let fetchRequest = buildListContentsFetchRequest(
      properties: [
        #keyPath(LibraryItem.relativePath),
        #keyPath(LibraryItem.isFinished),
      ],
      relativePath: parentFolder,
      limit: nil,
      offset: nil,
      ordering: .effective,
      context: context
    )

    guard let results = try? context.fetch(fetchRequest) as? [[String: Any]] else { return nil }

    return results.compactMap { dictionary in
      guard let relativePath = dictionary[#keyPath(LibraryItem.relativePath)] as? String else { return nil }
      return SimpleNavigationItem(
        relativePath: relativePath,
        isFinished: dictionary[#keyPath(LibraryItem.isFinished)] as? Bool ?? false
      )
    }
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
  
  /// @MainActor: creates/mutates managed objects on the main-queue viewContext — running
  /// this off the main thread is the CoreData threading violation the repo bans.
  @MainActor
  public func createExternalBook(simpleItem: SimpleLibraryItem, externalResource: SimpleExternalResource) async -> LibraryItem {
    let context = dataManager.getContext()
    
    let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
    let book = Book(entity: entity, insertInto: context)
    book.relativePath = simpleItem.originalFileName
    book.remoteURL = nil
    book.artworkURL = simpleItem.artworkURL
    let title = simpleItem.title
    book.title = title.isEmpty ? simpleItem.title.replacingOccurrences(of: "_", with: " ") : title
    let artist = simpleItem.details
    book.details = artist.isEmpty ? "voiceover_unknown_author".localized : artist
    book.duration = simpleItem.duration
    book.currentTime = simpleItem.currentTime
    book.percentCompleted = simpleItem.percentCompleted
    book.originalFileName = simpleItem.originalFileName
    book.isFinished = simpleItem.isFinished
    book.type = .book
    book.uuid = UUID().uuidString
    
    self.dataManager.saveSyncContext(context)
    
    let resourceEntity = NSEntityDescription.entity(forEntityName: "ExternalResource", in: context)!
    let external = ExternalResource(entity: resourceEntity, insertInto: context)
    
    external.providerId = externalResource.providerId
    external.providerName = externalResource.providerName
    external.syncStatus = externalResource.syncStatus
    external.lastSyncedAt = externalResource.lastSyncedAt
    external.processedFile = externalResource.processedFile
    external.hostId = externalResource.hostId
    
    external.libraryItem = book
    book.addToExternalResources(external)
    
    self.dataManager.saveSyncContext(context)
    return book
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

  public func reloadChapters(relativePath: String) async -> Int? {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

    // Parse outside of context.perform (it does file I/O).
    guard let newChapters = await audioMetadataService.extractManualChapters(from: fileURL),
          !newChapters.isEmpty else {
      return nil
    }

    let context = dataManager.getBackgroundContext()
    return await context.perform { [unowned self] in
      guard let book = self.getItem(with: relativePath, context: context) as? Book else {
        return nil
      }
      // Only replace when the manual parser found more than what's stored, so the action can
      // only improve a list — never degrade one AVFoundation already read correctly.
      let existingCount = book.chapters?.count ?? 0
      guard newChapters.count > existingCount else { return nil }

      if let existing = book.chapters?.array as? [Chapter] {
        existing.forEach { context.delete($0) }
      }
      self.storeChapters(newChapters, for: book, context: context)
      self.dataManager.saveSyncContext(context)
      return newChapters.count
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
      #keyPath(LibraryItem.uuid): folder.uuid,
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
          #keyPath(LibraryItem.uuid): item.uuid,
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
      #keyPath(LibraryItem.uuid): folder.uuid
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
      #keyPath(LibraryItem.uuid): folder.uuid
    ])
    /// TODO: verify if necessary to mark the folder as finished

    NotificationCenter.default.post(
      name: .folderProgressUpdated,
      object: nil,
      userInfo: [
        "relativePath": relativePath,
        "progress": progress,
        "uuid": folder.uuid
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
      #keyPath(LibraryItem.uuid): item.uuid,
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

    /// The old folder path and all its descendants are now stale in the Last Played
    /// widget snapshot; prune them via the path-prefix rule using the old path.
    SharedWidgetStore.removeItems(matching: [relativePath])

    return newRelativePath
  }

  public func updateDetails(at relativePath: String, details: String) {
    guard let item = self.getItemReference(with: relativePath) else { return }

    item.details = details

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.details): details,
      #keyPath(LibraryItem.uuid): item.uuid
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

  /// Shared core of the custom-arrangement mutations (drag, reverse,
  /// Custom-freeze). Two ordering invariants live here so no caller can get
  /// them wrong individually:
  /// 1. Capture-before-flip: the effective (visible) descriptors are resolved
  ///    BEFORE the pref flips to `.custom` — flipping first would resolve to
  ///    rank order and the mutation would act on an order the user isn't
  ///    looking at.
  /// 2. The `.custom` pref write precedes the rank rebuild, so the next
  ///    (query-time-sorted) fetch can't re-sort the arrangement away.
  /// Emits one sync update per actually-changed rank; the whole arrangement
  /// is user-made, so these always sync.
  private func freezeVisibleOrder(
    at relativePath: String?,
    transform: ([LibraryItem]) -> [LibraryItem]
  ) {
    let context = dataManager.getContext()
    let visibleOrder = resolveSortDescriptors(
      forRelativePath: relativePath,
      ordering: .effective,
      context: context
    )

    if let prefs = preferencesService {
      let location = makeLocation(forRelativePath: relativePath, context: context)
      prefs.setSort(.custom, forLocation: location)
    }

    guard
      let contents = fetchRawContents(
        at: relativePath,
        propertiesToFetch: [
          #keyPath(LibraryItem.relativePath),
          #keyPath(LibraryItem.orderRank),
          #keyPath(LibraryItem.uuid)
        ],
        sortedBy: visibleOrder,
        context: context
      ),
      !contents.isEmpty
    else { return }

    for (index, item) in transform(contents).enumerated() where item.orderRank != Int16(index) {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank,
        #keyPath(LibraryItem.uuid): item.uuid
      ])
    }

    dataManager.saveContext()
  }

  public func reorderItems(
    inside folderRelativePath: String?,
    fromOffsets source: IndexSet,
    toOffset destination: Int
  ) {
    /// The drag offsets are positions in the visible order; the freeze helper
    /// fetches in exactly that order before applying them.
    freezeVisibleOrder(at: folderRelativePath) { contents in
      var rearranged = contents
      rearranged.move(fromOffsets: source, toOffset: destination)
      return rearranged
    }
  }

  /// Freezes the location's currently-visible order into `orderRank` and
  /// transitions the sticky sort to `.custom` — the picker's "Custom" option.
  /// WYSIWYG by design (Android parity), and it self-heals stale server ranks
  /// the first time it runs. Idempotent: a repeat freeze changes no ranks and
  /// emits no sync updates.
  public func adoptCurrentOrderAsCustom(at relativePath: String?) {
    freezeVisibleOrder(at: relativePath) { $0 }
  }

  /// One-off reverse: flips the current VISIBLE order and transitions the location's
  /// sticky sort to `.custom`, the same transition a manual drag-drop produces.
  /// Reversing an automatically-sorted list freezes the reversed rule order —
  /// what the user sees, reversed.
  public func reverseContents(at relativePath: String?) {
    freezeVisibleOrder(at: relativePath) { $0.reversed() }
  }

  public func sortContents(at relativePath: String?, by type: SortType) {
    let context = dataManager.getContext()
    let location = makeLocation(forRelativePath: relativePath, context: context)

    // Resolvable location with a preferences service: the sort is a sticky
    // preference applied at query time — persist it and let the next fetch
    // order by it. No rank writes; `orderRank` keeps the custom arrangement.
    if let prefs = preferencesService, location != .unresolved {
      prefs.setSort(.automatic(type), forLocation: location)
      return
    }

    // One-shot path (`.unresolved` locations, or no preferences service, e.g.
    // watchOS): a bulk custom rearrangement — materialize the rule into
    // `orderRank` once and sync the new arrangement like any manual reorder.
    // No preference is (or can be) persisted.
    guard
      let results = fetchRawContents(at: relativePath, propertiesToFetch: type.fetchProperties()),
      !results.isEmpty
    else { return }

    let sortedResults = type.sortItems(results)

    for (index, item) in sortedResults.enumerated() {
      item.orderRank = Int16(index)
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): item.relativePath!,
        #keyPath(LibraryItem.orderRank): item.orderRank,
        #keyPath(LibraryItem.uuid): item.uuid,
      ])
    }

    self.dataManager.saveContext()
  }

  /// Resolves a relativePath into a `SortLocation`.
  ///
  /// Three outcomes — keep them distinct so callers (and the resolver) can't
  /// accidentally route a non-sortable location onto the library-root key:
  /// - `nil` path → `.libraryRoot`
  /// - real UUID, non-bound folder → `.folder(LibraryItemRef)`
  /// - missing/placeholder UUID, or bound folder → `.unresolved` (hooks no-op).
  ///   Bound folders are explicitly excluded because their children are a
  ///   single playable unit, not a user-sortable list — even if some path
  ///   tried to write a sticky sort for the bound's UUID, this gate keeps
  ///   the children's `orderRank` stable.
  public func makeLocation(forRelativePath relativePath: String?) -> SortLocation {
    makeLocation(forRelativePath: relativePath, context: dataManager.getContext())
  }

  /// Single-fetch resolution (uuid + type in one round trip): this runs on the
  /// render path via `resolveSortDescriptors`, so per-call cost matters.
  func makeLocation(forRelativePath relativePath: String?, context: NSManagedObjectContext) -> SortLocation {
    guard let relativePath else { return .libraryRoot }

    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), relativePath)
    fetchRequest.propertiesToFetch = [#keyPath(LibraryItem.uuid), #keyPath(LibraryItem.type)]
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.fetchLimit = 1

    guard
      let row = (try? context.fetch(fetchRequest))?.first,
      let uuid = row[#keyPath(LibraryItem.uuid)] as? String,
      Constants.isRealUuid(uuid)
    else { return .unresolved }
    if let rawType = row[#keyPath(LibraryItem.type)] as? Int16,
       rawType == ItemType.bound.rawValue {
      return .unresolved
    }
    return .folder(LibraryItemRef(relativePath: relativePath, uuid: uuid))
  }

  public func getRelativePath(forUuid uuid: String) -> String? {
    guard Constants.isRealUuid(uuid) else { return nil }

    let context = dataManager.getContext()
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "LibraryItem")
    fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.uuid), uuid)
    fetchRequest.propertiesToFetch = [#keyPath(LibraryItem.relativePath)]
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.fetchLimit = 1

    do {
      let results = try context.fetch(fetchRequest)
      return results.first?[#keyPath(LibraryItem.relativePath)] as? String
    } catch {
      return nil
    }
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
    
    var params = [
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.currentTime): time,
      #keyPath(LibraryItem.lastPlayDate): date.timeIntervalSince1970,
      #keyPath(LibraryItem.percentCompleted): percentCompleted,
      #keyPath(LibraryItem.uuid): item.uuid
    ] as [String : Any]
    
    if let externalResource = item.resourcesArray.first {
      params[#keyPath(ExternalResource.providerId)] = externalResource.providerId
      params[#keyPath(ExternalResource.providerName)] = externalResource.providerName
      params["hostId"] = externalResource.hostId
    }
    
    progressPassthroughPublisher.send(params)
  }

  func recursiveFolderLastPlayedDateUpdate(from relativePath: String, date: Date) {
    guard let folder = getItemReference(with: relativePath) as? Folder else { return }

    folder.lastPlayDate = date

    metadataPassthroughPublisher.send([
      #keyPath(LibraryItem.relativePath): relativePath,
      #keyPath(LibraryItem.lastPlayDate): date.timeIntervalSince1970,
      #keyPath(LibraryItem.uuid): folder.uuid
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
      #keyPath(LibraryItem.uuid): item.uuid,
    ])

    if let folder = item.folder,
      let folderPath = folder.relativePath
    {
      metadataPassthroughPublisher.send([
        #keyPath(LibraryItem.relativePath): folderPath,
        #keyPath(LibraryItem.speed): speed,
        #keyPath(LibraryItem.uuid): item.uuid,
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
      #keyPath(LibraryItem.uuid): book.uuid,
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
      #keyPath(LibraryItem.uuid): folder.uuid,
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
      #keyPath(LibraryItem.uuid): book.uuid,
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
      #keyPath(LibraryItem.uuid): folder.uuid,
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
        let uuid = dictionary["item.uuid"] as? String,
        let rawType = dictionary["type"] as? Int16,
        let type = BookmarkType(rawValue: rawType)
      else { return nil }

      return SimpleBookmark(
        time: time,
        note: dictionary["note"] as? String,
        type: type,
        relativePath: relativePath,
        uuid: uuid
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

  public func createBookmark(at time: Double, relativePath: String, uuid: String, type: BookmarkType) -> SimpleBookmark? {
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
      relativePath: relativePath,
      uuid: uuid
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

extension LibraryService {
  public func findResource(for providerId: String, providerName: String? = nil, context: NSManagedObjectContext? = nil) -> ExternalResource? {
    let fetch: NSFetchRequest<ExternalResource> = ExternalResource.fetchRequest()
    // Scope by provider when known: provider item ids are only unique per provider, and a
    // Jellyfin id colliding with an ABS id must not resolve/mutate the other's resource.
    if let providerName {
      fetch.predicate = NSPredicate(format: "providerId == %@ AND providerName == %@", providerId, providerName)
    } else {
      fetch.predicate = NSPredicate(format: "providerId == %@", providerId)
    }
    let context = context ?? self.dataManager.getContext()

    let result = try? context.fetch(fetch)
    
    return result?.first
  }
  
  public func findResources(for uuid: String, context: NSManagedObjectContext? = nil) -> [ExternalResource]? {
    let fetch: NSFetchRequest<ExternalResource> = ExternalResource.fetchRequest()
    fetch.predicate = NSPredicate(format: "%K == %@", #keyPath(ExternalResource.libraryItem.uuid), uuid)
    let context = context ?? self.dataManager.getContext()

    let result = try? context.fetch(fetch)
    
    return result
  }
  
  public func handleSyncFromExternalResouce(remoteItemsDictionary: [String: JellyfinLibraryItem]) {
    let remoteKeys = Array(remoteItemsDictionary.keys)
    
    let fetch: NSFetchRequest<ExternalResource> = ExternalResource.fetchRequest()
    fetch.predicate = NSPredicate(
      format: "%K == %@ AND %K IN %@",
      #keyPath(ExternalResource.providerName), ExternalResource.ProviderName.jellyfin.rawValue,
      #keyPath(ExternalResource.providerId), remoteKeys
    )
    let context = self.dataManager.getContext()
    
    do {
      let localResources = try context.fetch(fetch)
      
      for localResource in localResources {
        // We already know this exists because of our predicate!
        guard let localItem = localResource.libraryItem,
              let remoteItem = remoteItemsDictionary[localResource.providerId] else {
          continue
        }
        
        let localDate = localItem.lastPlayDate ?? .distantPast
        let remoteDate = remoteItem.lastPlayedDate ?? .distantPast
        
        if remoteDate > localDate {
          localItem.currentTime = Double(remoteItem.currentSeconds ?? 0)
          localItem.isFinished = remoteItem.isFinished ?? localItem.isFinished
          localItem.lastPlayDate = remoteDate
        }
      }
      
      dataManager.saveSyncContext(context)
    } catch {
      Self.logger.error("Failed to batch fetch ExternalResources: \(error)")
    }
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

  public func setExternalResource(
    providerName: String,
    providerId: String,
    for uuid: String
  ) async -> SyncableExternalResource? {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()

      context.perform { [unowned self, context] in
        let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.uuid), uuid)
        fetchRequest.fetchLimit = 1

        guard let item = try? context.fetch(fetchRequest).first else {
          continuation.resume(returning: nil)
          return
        }

        /// Skip if the same resource is already linked
        if item.resourcesArray.contains(where: {
          $0.providerName == providerName && $0.providerId == providerId
        }) {
          continuation.resume(returning: nil)
          return
        }

        let syncable = SyncableExternalResource(
          providerName: providerName,
          providerId: providerId,
          syncStatus: ExternalResource.SyncStatus.notSynced.rawValue,
          lastSyncedAt: nil,
          processedFile: true,
          hostId: nil
        )

        _ = ExternalResource.create(syncable, libraryItem: item, in: context)

        dataManager.saveSyncContext(context)
        continuation.resume(returning: syncable)
      }
    }
  }

  public func removeExternalResource(
    providerName: String,
    for uuid: String
  ) async -> String? {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()

      context.perform { [unowned self, context] in
        let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.uuid), uuid)
        fetchRequest.fetchLimit = 1

        guard
          let item = try? context.fetch(fetchRequest).first,
          let resource = item.resourcesArray.first(where: { $0.providerName == providerName })
        else {
          continuation.resume(returning: nil)
          return
        }

        let providerId = resource.providerId
        item.removeFromExternalResources(resource)
        context.delete(resource)

        dataManager.saveSyncContext(context)
        continuation.resume(returning: providerId)
      }
    }
  }

  public func getExternalResources(for relativePath: String) async -> [SimpleExternalResource] {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()

      context.perform { [unowned self, context] in
        guard let item = getItemReference(with: relativePath, context: context) else {
          continuation.resume(returning: [])
          return
        }

        let resources = item.resourcesArray.map {
          SimpleExternalResource(from: $0, ignoreLibraryItem: true)
        }
        continuation.resume(returning: resources)
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
