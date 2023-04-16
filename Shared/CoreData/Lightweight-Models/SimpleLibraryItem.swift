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
  public let currentTime: Double
  public let duration: Double
  public let durationFormatted: String
  public var percentCompleted: Double
  public let isFinished: Bool
  public let relativePath: String
  public let orderRank: Int16
  public let parentFolder: String?
  public let originalFileName: String
  public let lastPlayDate: Date?
  public let type: SimpleItemType

  public var progress: Double {
    if type == .folder,
       duration == 0 {
      return 0
    }

    return isFinished ? 1.0 : (percentCompleted / 100)
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
  }

  public static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
    return lhs.id == rhs.id
  }

  static var fetchRequestProperties = [
    "title",
    "details",
    "currentTime",
    "duration",
    "percentCompleted",
    "isFinished",
    "relativePath",
    "orderRank",
    "folder.relativePath",
    "originalFileName",
    "lastPlayDate",
    "type",
  ]

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(details)
    hasher.combine(percentCompleted)
  }

  public init(
    title: String,
    details: String,
    currentTime: Double,
    duration: Double,
    percentCompleted: Double,
    isFinished: Bool,
    relativePath: String,
    orderRank: Int16,
    parentFolder: String?,
    originalFileName: String,
    lastPlayDate: Date?,
    type: SimpleItemType
  ) {
    self.title = title
    self.details = details
    self.currentTime = currentTime
    self.duration = duration
    self.durationFormatted = TimeParser.formatTotalDuration(duration)
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.relativePath = relativePath
    self.orderRank = orderRank
    self.parentFolder = parentFolder
    self.originalFileName = originalFileName
    self.lastPlayDate = lastPlayDate
    self.type = type
  }
}

extension SimpleLibraryItem {
  public init(from item: LibraryItem) {
    self.title = item.title
    self.details = item.details
    self.currentTime = item.currentTime
    self.duration = item.duration
    self.durationFormatted = TimeParser.formatTotalDuration(item.duration)
    self.percentCompleted = item.percentCompleted
    self.isFinished = item.isFinished
    self.relativePath = item.relativePath
    self.orderRank = item.orderRank
    self.parentFolder = item.folder?.relativePath
    self.originalFileName = item.originalFileName
    self.lastPlayDate = item.lastPlayDate

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
