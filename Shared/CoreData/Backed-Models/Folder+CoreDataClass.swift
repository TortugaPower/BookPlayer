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

  public convenience init(
    context: NSManagedObjectContext,
    title: String,
    details: String,
    relativePath: String,
    originalFileName: String,
    speed: Float?,
    currentTime: Double,
    duration: Double,
    percentCompleted: Double,
    isFinished: Bool,
    orderRank: Int16,
    lastPlayDate: Date?,
    syncStatus: SyncStatus
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)

    self.title = title
    self.details = details
    self.relativePath = relativePath
    self.originalFileName = originalFileName
    if let speed = speed {
      self.speed = speed
    }
    self.currentTime = currentTime
    self.duration = duration
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.orderRank = orderRank
    self.lastPlayDate = lastPlayDate
    self.syncStatus = syncStatus
  }

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

    public override var duration: Double {
        get {
            let itemTime = self.getProgressAndDuration()
            return itemTime.duration
        }
        set {
            super.duration = newValue
        }
    }

    public override var progress: Double {
        let itemTime = self.getProgressAndDuration()

        return itemTime.progress
    }

    public override var progressPercentage: Double {
      switch self.type {
      case .folder:
        let itemTime = self.getProgressAndDuration()

        return itemTime.progress / itemTime.duration
      case .bound:
        guard self.duration > 0 else { return 0 }

        return self.currentTime / self.duration
      case .book:
        return 0
      }
    }

    public func getProgressAndDuration() -> (progress: Double, duration: Double) {
        if let cachedProgress = self.cachedProgress,
           let cachedDuration = self.cachedDuration {
            return (cachedProgress, cachedDuration)
        }

        guard let items = self.items?.array as? [LibraryItem] else {
            return (0.0, 0.0)
        }

        var totalDuration = 0.0
        var totalProgress = 0.0

        for item in items {
            totalDuration += item.duration
            totalProgress += item.isFinished
                ? item.duration
                : item.progress
        }

        self.cachedProgress = totalProgress
        self.cachedDuration = totalDuration

        guard totalDuration > 0 else {
            return (0.0, 0.0)
        }

        return (totalProgress, totalDuration)
    }

  public func updateDetails() {
    let count = self.items?.count ?? 0

    self.details = String.localizedStringWithFormat("files_title".localized, count)
  }

  public func updateCompletionState() {
    self.resetCachedProgress()
    guard let items = self.items?.array as? [LibraryItem] else { return }

    self.isFinished = !items.contains(where: { !$0.isFinished })
  }

    public func hasBooks() -> Bool {
        guard let books = self.items else {
            return false
        }

        return books.count > 0
    }

    public override func setCurrentTime(_ time: Double) {
        guard let items = self.items?.array as? [LibraryItem] else { return }

        for item in items {
            item.setCurrentTime(time)
        }
    }

  public func insert(item: LibraryItem, at index: Int? = nil) {
    if let parent = item.folder {
      parent.removeFromItems(item)
      parent.updateCompletionState()
      parent.updateDetails()
    }

    if let library = item.library {
      library.removeFromItems(item)
    }

    if let index = index {
      self.insertIntoItems(item, at: index)
    } else {
      self.addToItems(item)
    }

    self.rebuildRelativePaths(for: item)
    self.rebuildOrderRank()
    self.updateDetails()
  }

  public func rebuildRelativePaths(for item: LibraryItem) {
    item.relativePath = self.relativePathBuilder(for: item)

    if let folder = item as? Folder,
       let items = folder.items?.array as? [LibraryItem] {
      items.forEach({ folder.rebuildRelativePaths(for: $0) })
    }
  }

  public func rebuildOrderRank() {
    guard let items = self.items?.array as? [LibraryItem] else { return }

    for (index, item) in items.enumerated() {
      item.orderRank = Int16(index)
      try? item.fileURL?.setAppOrderRank(index)
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
