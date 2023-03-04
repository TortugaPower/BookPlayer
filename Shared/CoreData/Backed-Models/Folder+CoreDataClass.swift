//
//  Playlist+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

@objc(Folder)
public class Folder: LibraryItem {
  var cachedDuration: Double?
  var cachedProgress: Double?

  // MARK: - Init

  public convenience init(title: String, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    self.relativePath = title
    self.title = title
    self.originalFileName = title
    self.type = .folder
    self.details = String.localizedStringWithFormat("files_title".localized, 0)
  }

  public convenience init(from fileURL: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    let fileTitle = fileURL.lastPathComponent
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    self.title = fileTitle
    self.originalFileName = fileTitle
    self.type = .folder
    self.details = String.localizedStringWithFormat("files_title".localized, 0)
  }

    // MARK: - Methods

    public func resetCachedProgress() {
        self.cachedProgress = nil
        self.cachedDuration = nil
        self.folder?.resetCachedProgress()
    }

    func totalDuration() -> Double {
        guard let items = self.items?.array as? [LibraryItem] else {
            return 0.0
        }

        let totalDuration = items.reduce(0.0, {$0 + $1.duration})

        guard totalDuration > 0 else {
            return 0.0
        }

        return totalDuration
    }

  public func updateDetails(with count: Int? = nil) {
    let count = count ?? self.items?.count ?? 0

    self.details = String.localizedStringWithFormat("files_title".localized, count)
  }

  public func updateCompletionState() {
    self.resetCachedProgress()
    guard let items = self.items?.array as? [LibraryItem] else { return }

    self.isFinished = !items.contains(where: { !$0.isFinished })
  }

  public func insert(item: LibraryItem) {
    if let parent = item.folder {
      parent.removeFromItems(item)
      parent.updateCompletionState()
      parent.updateDetails()
    }

    if let library = item.library {
      library.removeFromItems(item)
    }

    self.addToItems(item)
    self.rebuildRelativePaths(for: item)
    self.updateDetails()
  }

  public func rebuildRelativePaths(for item: LibraryItem) {
    item.relativePath = self.relativePathBuilder(for: item)

    if let folder = item as? Folder,
       let items = folder.items?.array as? [LibraryItem] {
      items.forEach({ folder.rebuildRelativePaths(for: $0) })
    }
  }

    public func relativePathBuilder(for item: LibraryItem) -> String {
        let itemRelativePath = item.relativePath.split(separator: "/").map({ String($0) }).last ?? item.relativePath

        return "\(self.relativePath!)/\(itemRelativePath!)"
    }

  public override func info() -> String {
    let count = self.items?.array.count ?? 0

    return String.localizedStringWithFormat("files_title".localized, count)
  }

    enum CodingKeys: String, CodingKey {
        case title, details, books, folders, library, orderRank, items
    }

    public override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(title, forKey: .title)
      try container.encode(details, forKey: .details)
      try container.encode(orderRank, forKey: .orderRank)

      guard let itemsArray = self.items?.array as? [LibraryItem] else { return }

      try container.encode(itemsArray, forKey: .items)
    }

    public required convenience init(from decoder: Decoder) throws {
      // Create NSEntityDescription with NSManagedObjectContext
      guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "Folder", in: managedObjectContext) else {
              fatalError("Failed to decode Folder!")
            }
      self.init(entity: entity, insertInto: nil)

      let values = try decoder.container(keyedBy: CodingKeys.self)
      title = try values.decode(String.self, forKey: .title)
      details = try values.decode(String.self, forKey: .details)

      if let encodedItems = try? values.decode([LibraryItem].self, forKey: .items) {
        items = NSOrderedSet(array: encodedItems)
      }
    }
}

extension Folder {
  public convenience init(
    syncItem: SyncableItem,
    context: NSManagedObjectContext
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    self.title = syncItem.title
    self.details = syncItem.details
    self.relativePath = syncItem.relativePath
    self.originalFileName = syncItem.originalFileName
    if let speed = syncItem.speed {
      self.speed = Float(speed)
    }
    self.currentTime = syncItem.currentTime
    self.duration = syncItem.duration
    self.percentCompleted = syncItem.percentCompleted
    self.isFinished = syncItem.isFinished
    self.orderRank = Int16(syncItem.orderRank)
    if let timestamp = syncItem.lastPlayDateTimestamp {
      self.lastPlayDate = Date(timeIntervalSince1970: timestamp)
    }
    self.type = syncItem.type.itemType
  }
}
