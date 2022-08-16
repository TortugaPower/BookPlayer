//
//  SimpleLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

public struct SimpleLibraryItem: Hashable, Identifiable {
  public var id: String {
    return self.relativePath
  }
  public let title: String
  public let details: String
  public let duration: Double
  public let durationFormatted: String
  public var progress: Double
  public let isFinished: Bool
  public let relativePath: String
  public let parentFolder: String?
  public let type: SimpleItemType
  public let syncStatus: SyncStatus

  public static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
    return lhs.id == rhs.id
  }

  static var fetchRequestProperties = [
    "title",
    "details",
    "duration",
    "percentCompleted",
    "isFinished",
    "relativePath",
    "folder.relativePath",
    "type",
    "syncStatus"
  ]

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(details)
    hasher.combine(progress)
  }

  public init(
    title: String,
    details: String,
    duration: Double,
    progress: Double,
    isFinished: Bool,
    relativePath: String,
    parentFolder: String?,
    type: SimpleItemType,
    syncStatus: SyncStatus
  ) {
    self.title = title
    self.details = details
    self.duration = duration
    self.durationFormatted = TimeParser.formatTotalDuration(duration)
    self.progress = progress
    self.isFinished = isFinished
    self.relativePath = relativePath
    self.parentFolder = parentFolder
    self.type = type
    self.syncStatus = syncStatus
  }
}

extension SimpleLibraryItem {
  public init(from item: LibraryItem) {
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.durationFormatted = TimeParser.formatTotalDuration(item.duration)
    self.progress = item.isFinished ? 1.0 : item.progressPercentage
    self.isFinished = item.isFinished
    self.relativePath = item.relativePath
    self.parentFolder = item.folder?.relativePath
    self.syncStatus = item.syncStatus

    switch item.type {
    case .folder:
      self.type = .folder
    case .bound:
      self.type = .bound
    case .book:
      self.type = .book
    }
  }
}
