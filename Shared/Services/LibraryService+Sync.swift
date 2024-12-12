//
//  LibraryService+Sync.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation
import Combine

public protocol LibrarySyncProtocol {
  var metadataUpdatePublisher: AnyPublisher<[String: Any], Never> { get }
  var progressUpdatePublisher: AnyPublisher<[String: Any], Never> { get }

  /// Fetch all the stored items in the library that are not in the remote identifiers array
  func getItemsToSync(remoteIdentifiers: [String]) async -> [SyncableItem]?
  /// Update local items with synced info
  func updateInfo(for itemsDict: [String: SyncableItem], parentFolder: String?) async
  /// Update single local item with synced info
  func updateInfo(for item: SyncableItem) async
  /// Create new items from synced info
  func storeNewItems(from itemsDict: [String: SyncableItem], parentFolder: String?) async
  /// Remove local items that were not in the remote identifiers
  func removeItems(notIn identifiers: [String], parentFolder: String?) async

  /// Get last played library item
  func fetchLibraryLastItem() async -> SimpleLibraryItem?
  /// Set the last played book
  func updateLibraryLastBook(with relativePath: String?) async
  /// Returns boolean determining if the item exists for the relativePath
  func itemExists(for relativePath: String) async -> Bool
  /// Load encoded chapters from file into DB
  func loadChaptersIfNeeded(relativePath: String) async

  /// Fetch all items and folders inside a given folder (Used for newly imported folders)
  func getAllNestedItems(inside relativePath: String) -> [SyncableItem]?
  /// Get max items count inside the specified path
  func getMaxItemsCount(at relativePath: String?) -> Int

  /// Get all stored bookmarks of the specified type for a book
  func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]?
  /// Store new synced bookmark
  func addBookmark(from bookmark: SimpleBookmark) async
}

extension LibraryService: LibrarySyncProtocol {
  public func updateLibraryLastBook(with relativePath: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        setLibraryLastBook(with: relativePath, context: context)
        continuation.resume()
      }
    }
  }

  public func fetchLibraryLastItem() async -> SimpleLibraryItem? {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        let lastItem = getLibraryLastItem(context: context)
        continuation.resume(returning: lastItem)
      }
    }
  }

  public func itemExists(for relativePath: String) async -> Bool {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        let storedItem = getItemReference(with: relativePath, context: context)

        continuation.resume(returning: storedItem != nil)
      }
    }
  }

  public func updateInfo(for itemsDict: [String: SyncableItem], parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        guard let storedItems = getItems(in: Array(itemsDict.keys), parentFolder: parentFolder, context: context) else {
          continuation.resume()
          return
        }

        for storedItem in storedItems {
          guard let item = itemsDict[storedItem.relativePath] else { continue }

          updateInfo(for: item, context: context, shouldSaveContext: false)
        }

        dataManager.saveSyncContext(context)
        continuation.resume()
      }
    }
  }

  public func updateInfo(for item: SyncableItem) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        updateInfo(for: item, context: context, shouldSaveContext: true)
        continuation.resume()
      }
    }
  }

  private func updateInfo(for item: SyncableItem, context: NSManagedObjectContext, shouldSaveContext: Bool) {
    guard let storedItem = getItem(with: item.relativePath, context: context) else { return }

    storedItem.title = item.title
    storedItem.details = item.details
    storedItem.currentTime = item.currentTime
    storedItem.duration = item.duration
    storedItem.isFinished = item.isFinished
    storedItem.orderRank = Int16(item.orderRank)
    storedItem.percentCompleted = item.percentCompleted
    storedItem.remoteURL = item.remoteURL
    storedItem.artworkURL = item.artworkURL
    storedItem.type = item.type.itemType
    storedItem.speed = Float(item.speed ?? 1.0)
    if let timestamp = item.lastPlayDateTimestamp {
      storedItem.lastPlayDate = Date(timeIntervalSince1970: timestamp)
    } else {
      storedItem.lastPlayDate = nil
    }

    if shouldSaveContext {
      dataManager.saveSyncContext(context)
    }
  }

  public func storeNewItems(from itemsDict: [String: SyncableItem], parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        let incomingKeys = Set(itemsDict.keys)
        let storedKeys = Set(getItemIdentifiers(in: parentFolder, context: context) ?? [])
        let newKeys = incomingKeys.subtracting(storedKeys)

        for key in newKeys {
          guard let item = itemsDict[key] else { continue }

          switch item.type {
          case .book:
            addBook(from: item, parentFolder: parentFolder, context: context)
          case .folder, .bound:
            addFolder(from: item, parentFolder: parentFolder, context: context)
          }
        }

        dataManager.saveSyncContext(context)
        continuation.resume()
      }
    }
  }

  func addBook(from item: SyncableItem, parentFolder: String?, context: NSManagedObjectContext) {
    let newBook = Book(
      syncItem: item,
      context: context
    )

    if let relativePath = parentFolder,
       let folder = getItem(with: relativePath, context: context) as? Folder {
      folder.addToItems(newBook)
    } else {
      let library = getLibraryReference(context: context)
      library.addToItems(newBook)
    }
  }

  func addFolder(from item: SyncableItem, parentFolder: String?, context: NSManagedObjectContext) {
    // This shouldn't fail
    try? createFolderOnDisk(title: item.title, inside: parentFolder, context: context)

    let newFolder = Folder(
      syncItem: item,
      context: context
    )

    // insert into existing folder or library at index
    if let relativePath = parentFolder,
       let folder = getItemReference(with: relativePath, context: context) as? Folder {
      folder.addToItems(newFolder)
    } else {
      let library = getLibraryReference(context: context)
      library.addToItems(newFolder)
    }
  }

  public func addBookmark(from bookmark: SimpleBookmark) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        if let fetchedBookmark = getBookmarkReference(from: bookmark, context: context) {
          fetchedBookmark.note = bookmark.note
        } else if let item = getItemReference(with: bookmark.relativePath, context: context) {
          let newBookmark = Bookmark(with: bookmark.time, type: bookmark.type, context: context)
          newBookmark.note = bookmark.note
          item.addToBookmarks(newBookmark)
        }

        dataManager.saveSyncContext(context)
        continuation.resume()
      }
    }
  }

  public func getItemsToSync(remoteIdentifiers: [String]) async -> [SyncableItem]? {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
        fetchRequest.propertiesToFetch = SyncableItem.fetchRequestProperties
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.predicate = NSPredicate(
          format: "NOT (%K IN %@)",
          #keyPath(LibraryItem.relativePath),
          remoteIdentifiers
        )
        let sort = NSSortDescriptor(
          key: #keyPath(LibraryItem.relativePath),
          ascending: true,
          selector: #selector(NSString.localizedStandardCompare(_:))
        )
        fetchRequest.sortDescriptors = [sort]

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]

        continuation.resume(returning: parseSyncableItems(from: results))
      }
    }
  }

  public func getAllNestedItems(inside relativePath: String) -> [SyncableItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = SyncableItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.predicate = NSPredicate(
      format: "%K BEGINSWITH %@", #keyPath(LibraryItem.folder.relativePath), relativePath
    )

    let results = try? self.dataManager.getBackgroundContext().fetch(fetchRequest) as? [[String: Any]]

    return parseSyncableItems(from: results)
  }

  func parseSyncableItems(from results: [[String: Any]]?) -> [SyncableItem]? {
    return results?.compactMap({ dictionary -> SyncableItem? in
      guard
        let relativePath = dictionary["relativePath"] as? String,
        let originalFileName = dictionary["originalFileName"] as? String,
        let title = dictionary["title"] as? String,
        let details = dictionary["details"] as? String,
        let speed = dictionary["speed"] as? Double,
        let currentTime = dictionary["currentTime"] as? Double,
        let duration = dictionary["duration"] as? Double,
        let percentCompleted = dictionary["percentCompleted"] as? Double,
        let isFinished = dictionary["isFinished"] as? Bool,
        let orderRank = dictionary["orderRank"] as? Int,
        let rawType = dictionary["type"] as? Int16,
        let type = SimpleItemType(rawValue: rawType)
      else { return nil }

      var lastPlayDateTimestamp: Double?

      if let lastPlayDate = dictionary["lastPlayDate"] as? Date {
        lastPlayDateTimestamp = lastPlayDate.timeIntervalSince1970
      }

      return SyncableItem(
        relativePath: relativePath,
        remoteURL: dictionary["remoteURL"] as? URL,
        artworkURL: dictionary["artworkURL"] as? URL,
        originalFileName: originalFileName,
        title: title,
        details: details,
        speed: speed,
        currentTime: currentTime,
        duration: duration,
        percentCompleted: percentCompleted,
        isFinished: isFinished,
        orderRank: orderRank,
        lastPlayDateTimestamp: lastPlayDateTimestamp,
        type: type
      )
    })
  }

  public func removeItems(notIn identifiers: [String], parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getBackgroundContext()
      context.perform { [unowned self, context] in
        guard
          let items = getItems(notIn: identifiers, parentFolder: parentFolder, context: context)
        else {
          continuation.resume()
          return
        }

        let backupFolderURL = DataManager.getBackupFolderURL()
        let processedFolderURL = DataManager.getProcessedFolderURL()

        /// Try to move files to backup folder before deleting
        for item in items {
          createBackup(
            for: item,
            parentFolder: parentFolder,
            processedFolderURL: processedFolderURL,
            backupFolderURL: backupFolderURL
          )
        }

        try? delete(items, mode: .deep)
        continuation.resume()
      }
    }
  }

  private func createBackup(
    for item: SimpleLibraryItem,
    parentFolder: String?,
    processedFolderURL: URL,
    backupFolderURL: URL
  ) {
    let fileURL = processedFolderURL.appendingPathComponent(item.relativePath)

    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

    if let parentFolder {
      try? createFolderIfNeeded(for: parentFolder, inside: backupFolderURL)
    }

    let destinationURL = backupFolderURL.appendingPathComponent(item.relativePath)
    try? FileManager.default.moveItem(atPath: fileURL.path, toPath: destinationURL.path)
  }

  private func createFolderIfNeeded(for folderPath: String, inside folderURL: URL) throws {
    let url = folderURL.appendingPathComponent(folderPath)

    if !FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }

  public func loadChaptersIfNeeded(relativePath: String) async {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

    await loadChaptersIfNeeded(relativePath: relativePath, asset: AVAsset(url: fileURL))
  }
}
