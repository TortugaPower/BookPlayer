//
//  LibraryService+Sync.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public protocol LibrarySyncProtocol {
  func getItem(with relativePath: String) -> LibraryItem?
  func getItemsToSync(remoteIdentifiers: [String]) -> [SyncableItem]?
  func getItemIdentifiers(in parentFolder: String?) -> [String]?
  func removeItems(notIn relativePaths: [String], parentFolder: String?) throws
  func fetchSyncableNestedContents(at relativePath: String) -> [SyncableItem]?
  func getMaxItemsCount(at relativePath: String?) -> Int

  func updateInfo(from item: SyncableItem)
  func addBook(from item: SyncableItem, parentFolder: String?)
  func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?)
}

extension LibraryService: LibrarySyncProtocol {
  public func updateInfo(from item: SyncableItem) {
    guard let localItem = getItem(with: item.relativePath) else { return }

    localItem.title = item.title
    localItem.details = item.details
    localItem.currentTime = item.currentTime
    localItem.duration = item.duration
    localItem.isFinished = item.isFinished
    localItem.orderRank = Int16(item.orderRank)
    localItem.percentCompleted = item.percentCompleted
    localItem.type = item.type.itemType
    localItem.speed = Float(item.speed ?? 1.0)
    if let timestamp = item.lastPlayDateTimestamp {
      localItem.lastPlayDate = Date(timeIntervalSince1970: timestamp)
    } else {
      localItem.lastPlayDate = nil
    }

    dataManager.saveContext()
    // TODO: handle updated_at timestamp
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
      let library = self.getLibrary()
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
    if let relativePath = parentFolder {
      // The folder object must exist
      let folder = self.findFolder(with: relativePath)!
      folder.addToItems(newFolder)
    } else {
      let library = self.getLibrary()
      library.addToItems(newFolder)
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
      let itemIdentifiers = getItemIdentifiers(notIn: relativePaths, parentFolder: parentFolder),
      let items = getItems(in: itemIdentifiers, parentFolder: parentFolder)
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

  func getItemIdentifiers(notIn relativePaths: [String], parentFolder: String?) -> [String]? {
      let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
      fetchRequest.propertiesToFetch = ["relativePath"]
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

      return results?.compactMap({ $0["relativePath"] as? String })
    }
}
