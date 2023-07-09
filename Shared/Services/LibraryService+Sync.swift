//
//  LibraryService+Sync.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

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
  /// Create new items from synced info
  func storeNewItems(from itemsDict: [String: SyncableItem], parentFolder: String?) async
  /// Remove local items that were not in the remote identifiers
  func removeItems(notIn identifiers: [String], parentFolder: String?) async

  /// Update last played info
  func updateLastPlayedInfo(_ item: SyncableItem) async

  /// Fetch all items and folders inside a given folder (Used for newly imported folders)
  func getAllNestedItems(inside relativePath: String) -> [SyncableItem]?

  /// Get all stored bookmarks of the specified type for a book
  func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]?
  /// Store new synced bookmark
  func addBookmark(from bookmark: SimpleBookmark) async
}

extension LibraryService: LibrarySyncProtocol {
  public func updateInfo(for itemsDict: [String: SyncableItem], parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getContext()
      context.perform { [unowned self, context] in
        guard let storedItems = getItems(in: Array(itemsDict.keys), parentFolder: parentFolder, context: context) else {
          continuation.resume()
          return
        }

        for storedItem in storedItems {
          guard let item = itemsDict[storedItem.relativePath] else { continue }

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
        }

        dataManager.saveSyncContext(context)
        continuation.resume()
      }
    }
  }

  public func updateLastPlayedInfo(_ item: SyncableItem) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getContext()
      context.perform { [unowned self, context] in
        guard let localItem = getItem(with: item.relativePath, context: context) else {
          continuation.resume()
          return
        }

        if let remoteURL = item.remoteURL {
          localItem.remoteURL = remoteURL
        }

        if let artworkURL = item.artworkURL {
          localItem.artworkURL = artworkURL
        }

        if let timestamp = item.lastPlayDateTimestamp {
          localItem.lastPlayDate = Date(timeIntervalSince1970: timestamp)
        }

        if let speed = item.speed {
          localItem.speed = Float(speed)
        }

        dataManager.saveSyncContext(context)
        continuation.resume()
      }
    }
  }

  public func storeNewItems(from itemsDict: [String: SyncableItem], parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      let context = dataManager.getContext()
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
      let context = dataManager.getContext()
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
      let context = dataManager.getContext()
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

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

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
      let context = dataManager.getContext()
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
          let fileURL = processedFolderURL.appendingPathComponent(item.relativePath)
          if FileManager.default.fileExists(atPath: fileURL.path) {
            let destinationURL = backupFolderURL.appendingPathComponent(item.relativePath)
            try? FileManager.default.moveItem(at: fileURL, to: destinationURL)
          }
        }

        try? delete(items, mode: .deep)
        continuation.resume()
      }
    }
  }
}
