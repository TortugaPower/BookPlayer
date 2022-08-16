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
  func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SyncableItem]?
  func fetchSyncableContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SyncableItem]?

  func addBook(from item: SyncableItem, parentFolder: String?)
  func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?)
}

extension LibraryService: LibrarySyncProtocol {
  public func addBook(from item: SyncableItem, parentFolder: String?) {
    var speed: Float?
    if let itemSpeed = item.speed {
      speed = Float(itemSpeed)
    }

    var lastPlayDate: Date?
    if let timestamp = item.lastPlayDateTimestamp {
      lastPlayDate = Date(timeIntervalSince1970: timestamp)
    }

    let newBook = Book(
      context: self.dataManager.getContext(),
      title: item.title,
      details: item.details,
      relativePath: item.relativePath,
      originalFileName: item.originalFileName,
      speed: speed,
      currentTime: item.currentTime,
      duration: item.duration,
      percentCompleted: item.percentCompleted,
      isFinished: item.isFinished,
      orderRank: Int16(item.orderRank),
      lastPlayDate: lastPlayDate,
      syncStatus: .contentsDownload
    )

    if let relativePath = parentFolder,
       let folder = self.getItem(with: relativePath) as? Folder {
      let count = folder.items?.count ?? 0
      let index = count == 0 ? 0 : count - 1
      folder.insert(item: newBook, at: min(index, item.orderRank))
      folder.rebuildOrderRank()
    } else {
      let library = self.getLibrary()
      let count = library.items?.count ?? 0
      let index = count == 0 ? 0 : count - 1
      library.insert(item: newBook, at: min(index, item.orderRank))
      library.rebuildOrderRank()
    }

    self.dataManager.saveContext()
  }

  public func addFolder(from item: SyncableItem, type: SimpleItemType, parentFolder: String?) {
    // This shouldn't fail
    try? createFolderOnDisk(title: item.title, inside: parentFolder)

    var speed: Float?
    if let itemSpeed = item.speed {
      speed = Float(itemSpeed)
    }

    var lastPlayDate: Date?
    if let timestamp = item.lastPlayDateTimestamp {
      lastPlayDate = Date(timeIntervalSince1970: timestamp)
    }

    let newFolder = Folder(
      context: self.dataManager.getContext(),
      title: item.title,
      details: item.details,
      relativePath: item.relativePath,
      originalFileName: item.originalFileName,
      speed: speed,
      currentTime: item.currentTime,
      duration: item.duration,
      percentCompleted: item.percentCompleted,
      isFinished: item.isFinished,
      orderRank: Int16(item.orderRank),
      lastPlayDate: lastPlayDate,
      syncStatus: .contentsDownload
    )

    // insert into existing folder or library at index
    if let relativePath = parentFolder {
      // The folder object must exist
      let folder = self.findFolder(with: relativePath)!
      folder.insert(item: newFolder, at: item.orderRank)
    } else {
      let library = self.getLibrary()
      library.insert(item: newFolder, at: item.orderRank)
    }

    self.dataManager.saveContext()
  }

  public func getItems(notIn relativePaths: [String], parentFolder: String?) -> [SyncableItem]? {
    let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest<NSDictionary>(entityName: "LibraryItem")
    fetchRequest.propertiesToFetch = SyncableItem.fetchRequestProperties
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

    return parseSyncableItems(from: results)
  }

  public func fetchSyncableContents(at relativePath: String?, limit: Int?, offset: Int?) -> [SyncableItem]? {
    let fetchRequest = buildListContentsFetchRequest(
      properties: SyncableItem.fetchRequestProperties,
      relativePath: relativePath,
      limit: limit,
      offset: offset
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
}
