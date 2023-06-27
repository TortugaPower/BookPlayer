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

  func getItem(with relativePath: String) -> LibraryItem?
  func getItemsToSync(remoteIdentifiers: [String]) -> [SyncableItem]?
  func getItemIdentifiers(in parentFolder: String?) -> [String]?
  func removeItems(notIn relativePaths: [String], parentFolder: String?) throws
  func fetchSyncableNestedContents(at relativePath: String) -> [SyncableItem]?
  func getMaxItemsCount(at relativePath: String?) -> Int
  func getBookmarks(of type: BookmarkType, relativePath: String) -> [SimpleBookmark]?

  func updateInfo(from items: [SyncableItem])
  func addBook(from item: SyncableItem, parentFolder: String?)
  func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?)
  func addBookmark(from bookmark: SimpleBookmark)
}

extension LibraryService: LibrarySyncProtocol {
  public func updateInfo(from items: [SyncableItem]) {
    for item in items {
      guard let localItem = getItem(with: item.relativePath) else { continue }

      localItem.title = item.title
      localItem.details = item.details
      localItem.currentTime = item.currentTime
      localItem.duration = item.duration
      localItem.isFinished = item.isFinished
      localItem.orderRank = Int16(item.orderRank)
      localItem.percentCompleted = item.percentCompleted
      localItem.remoteURL = item.remoteURL
      localItem.artworkURL = item.artworkURL
      localItem.type = item.type.itemType
      localItem.speed = Float(item.speed ?? 1.0)
      if let timestamp = item.lastPlayDateTimestamp {
        localItem.lastPlayDate = Date(timeIntervalSince1970: timestamp)
      } else {
        localItem.lastPlayDate = nil
      }
    }

    dataManager.saveSyncContext()
  }

  public func addBook(from item: SyncableItem, parentFolder: String?) {
    let newBook = Book(
      syncItem: item,
      context: self.dataManager.getContext()
    )

    if let relativePath = parentFolder,
       let folder = self.getItem(with: relativePath) as? Folder {
      folder.addToItems(newBook)
    } else {
      let library = self.getLibraryReference()
      library.addToItems(newBook)
    }

    self.dataManager.saveSyncContext()
  }

  public func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?) {
    // This shouldn't fail
    try? createFolderOnDisk(title: item.title, inside: parentFolder)

    let newFolder = Folder(
      syncItem: item,
      context: self.dataManager.getContext()
    )

    // insert into existing folder or library at index
    if let relativePath = parentFolder,
       let folder = getItemReference(with: relativePath) as? Folder {
      folder.addToItems(newFolder)
    } else {
      let library = self.getLibraryReference()
      library.addToItems(newFolder)
    }

    self.dataManager.saveSyncContext()
  }

  public func addBookmark(from bookmark: SimpleBookmark) {
    if let fetchedBookmark = getBookmarkReference(from: bookmark) {
      fetchedBookmark.note = bookmark.note
    } else if let item = getItemReference(with: bookmark.relativePath) {
      let newBookmark = Bookmark(with: bookmark.time, type: bookmark.type, context: dataManager.getContext())
      newBookmark.note = bookmark.note
      item.addToBookmarks(newBookmark)
    }

    self.dataManager.saveSyncContext()
  }

  public func getItemsToSync(remoteIdentifiers: [String]) -> [SyncableItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = SyncableItem.fetchRequestProperties
    fetchRequest.resultType = .dictionaryResultType
    fetchRequest.predicate = NSPredicate(
      format: "%K != nil AND NOT (%K IN %@)",
      #keyPath(LibraryItem.library),
      #keyPath(LibraryItem.relativePath),
      remoteIdentifiers
    )

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return parseSyncableItems(from: results)
  }

  public func getItemIdentifiers(in parentFolder: String?) -> [String]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: ["relativePath"],
      relativePath: parentFolder,
      limit: nil,
      offset: nil
    )

    let results = try? self.dataManager.getContext().fetch(fetchRequest) as? [[String: Any]]

    return results?.compactMap({ $0["relativePath"] as? String })
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

  public func removeItems(notIn relativePaths: [String], parentFolder: String?) throws {
    guard
      let items = getItems(notIn: relativePaths, parentFolder: parentFolder)
    else { return }

    try delete(items, mode: .deep)
  }

  func getItems(in relativePaths: [String], parentFolder: String?) -> [LibraryItem]? {
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

    return try? self.dataManager.getContext().fetch(fetchRequest)
  }
}
