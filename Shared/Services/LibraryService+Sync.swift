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

  func getItemsToSync(remoteIdentifiers: [String]) async -> [SyncableItem]?
  func fetchItemIdentifiers(in parentFolder: String?) async -> [String]?
  func removeItems(notIn relativePaths: [String], parentFolder: String?) async throws
  func fetchSyncableNestedContents(at relativePath: String) -> [SyncableItem]?
  func getMaxItemsCount(at relativePath: String?) async -> Int
  func getBookmarks(of type: BookmarkType, relativePath: String) async -> [SimpleBookmark]?

  func updateItemInfo(from item: SyncableItem) async
  func addBook(from item: SyncableItem, parentFolder: String?) async
  func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?) async
  func addBookmark(from bookmark: SimpleBookmark) async
}

extension LibraryService: LibrarySyncProtocol {
  public func updateItemInfo(from item: SyncableItem) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(LibraryItem.relativePath), item.relativePath)
        fetchRequest.fetchLimit = 1

        guard let storedItem = try? context.fetch(fetchRequest).first else {
          continuation.resume()
          return
        }

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

        context.saveContext()

        continuation.resume()
      }
    }
  }

  public func addBook(from item: SyncableItem, parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [unowned self] context in
        let newBook = Book(
          syncItem: item,
          context: context
        )

        if let relativePath = parentFolder,
           let folder = self.getItem(with: relativePath, context: context) as? Folder {
          folder.addToItems(newBook)
        } else {
          let library = self.getLibraryReference(context: context)
          library.addToItems(newBook)
        }

        self.dataManager.saveContext(context)
        continuation.resume()
      }
    }
  }

  public func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [unowned self] context in
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
          let library = self.getLibraryReference(context: context)
          library.addToItems(newFolder)
        }

        self.dataManager.saveContext(context)
        continuation.resume()
      }
    }
  }

  public func addBookmark(from bookmark: SimpleBookmark) async {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        if let fetchedBookmark = self?.getBookmarkReference(from: bookmark, context: context) {
          fetchedBookmark.note = bookmark.note
        } else if let item = self?.getItemReference(with: bookmark.relativePath, context: context) {
          let newBookmark = Bookmark(with: bookmark.time, type: bookmark.type, context: context)
          newBookmark.note = bookmark.note
          item.addToBookmarks(newBookmark)
        }

        context.saveContext()
        continuation.resume()
      }
    }
  }

  public func getItemsToSync(remoteIdentifiers: [String]) async -> [SyncableItem]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [weak self] context in
        let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
        fetchRequest.propertiesToFetch = SyncableItem.fetchRequestProperties
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.predicate = NSPredicate(
          format: "%K != nil AND NOT (%K IN %@)",
          #keyPath(LibraryItem.library),
          #keyPath(LibraryItem.relativePath),
          remoteIdentifiers
        )

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]
        continuation.resume(returning: self?.parseSyncableItems(from: results))
      }
    }
  }

  public func fetchItemIdentifiers(in parentFolder: String?) async -> [String]? {
    return await withCheckedContinuation { continuation in
      dataManager.performBackgroundTask { [unowned self] context in
        let fetchRequest = buildListContentsFetchRequest(
          properties: ["relativePath"],
          relativePath: parentFolder,
          limit: nil,
          offset: nil
        )

        let results = try? context.fetch(fetchRequest) as? [[String: Any]]
        let identifiers = results?.compactMap({ $0["relativePath"] as? String })
        continuation.resume(returning: identifiers)
      }
    }
  }

  public func fetchSyncableNestedContents(at relativePath: String) -> [SyncableItem]? {
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

  public func removeItems(notIn relativePaths: [String], parentFolder: String?) async throws {
    guard
      let items = await getItems(notIn: relativePaths, parentFolder: parentFolder)
    else { return }

    try await delete(items, mode: .deep)
  }

  func getItems(in relativePaths: [String], parentFolder: String?, context: NSManagedObjectContext) -> [LibraryItem]? {
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
}
