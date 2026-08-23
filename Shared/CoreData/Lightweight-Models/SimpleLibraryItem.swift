//
//  SimpleLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleLibraryItem: Identifiable, Hashable, Equatable {
  public var id: String {
    return self.relativePath
  }
  public let title: String
  public let details: String
  public let speed: Double
  public let currentTime: Double
  public let duration: Double
  public let durationFormatted: String
  public var percentCompleted: Double
  public let isFinished: Bool
  public let relativePath: String
  public let remoteURL: URL?
  public let artworkURL: URL?
  public let orderRank: Int16
  public let parentFolder: String?
  public let originalFileName: String
  public let lastPlayDate: Date?
  public let type: SimpleItemType
  public let uuid: String
  public let externalResources: [SimpleExternalResource]?
  
  public var progress: Double {
    if type == .folder,
       duration == 0 {
      return 0
    }

    return isFinished ? 1.0 : (percentCompleted / 100)
  }

  public var fileURL: URL {
    return DataManager.processedFolderURL.appendingPathComponent(relativePath)
  }

  public static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
    return lhs.id == rhs.id
    && lhs.title == rhs.title
    && lhs.details == rhs.details
    && lhs.percentCompleted == rhs.percentCompleted
    && lhs.isFinished == rhs.isFinished
    && lhs.type.rawValue == rhs.type.rawValue
    && lhs.orderRank == rhs.orderRank
    && lhs.uuid == rhs.uuid
    // Rows render provider icons from this — snapshots differing only in their
    // external resources must not compare equal, or removeDuplicates/onChange
    // paths skip refreshing a row that just gained or lost a media-server link
    && lhs.externalResources == rhs.externalResources
  }

  static var fetchRequestProperties = [
    "title",
    "details",
    "speed",
    "currentTime",
    "duration",
    "percentCompleted",
    "isFinished",
    "relativePath",
    "remoteURL",
    "artworkURL",
    "orderRank",
    "folder.relativePath",
    "originalFileName",
    "lastPlayDate",
    "type",
    "uuid"
  ]

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(details)
    hasher.combine(percentCompleted)
    hasher.combine(type.rawValue)
  }

  public init(
    title: String,
    details: String,
    speed: Double,
    currentTime: Double,
    duration: Double,
    percentCompleted: Double,
    isFinished: Bool,
    relativePath: String,
    remoteURL: URL?,
    artworkURL: URL?,
    orderRank: Int16,
    parentFolder: String?,
    originalFileName: String,
    lastPlayDate: Date?,
    type: SimpleItemType,
    uuid: String,
    externalResources: [SimpleExternalResource]? = nil
  ) {
    self.title = title
    self.details = details
    self.speed = speed
    self.currentTime = currentTime
    self.duration = duration
    self.durationFormatted = TimeParser.formatTotalDuration(duration)
    self.percentCompleted = percentCompleted
    self.isFinished = isFinished
    self.relativePath = relativePath
    self.remoteURL = remoteURL
    self.artworkURL = artworkURL
    self.orderRank = orderRank
    self.parentFolder = parentFolder
    self.originalFileName = originalFileName
    self.lastPlayDate = lastPlayDate
    self.type = type
    self.uuid = uuid
    self.externalResources = externalResources
  }
}

extension SimpleLibraryItem {
  public init(from item: LibraryItem) {
    self.title = item.title
    self.details = item.details
    self.speed = Double(item.speed)
    self.currentTime = item.currentTime
    self.duration = item.duration
    self.durationFormatted = TimeParser.formatTotalDuration(item.duration)
    self.percentCompleted = item.percentCompleted
    self.isFinished = item.isFinished
    self.relativePath = item.relativePath
    self.remoteURL = item.remoteURL
    self.artworkURL = item.artworkURL
    self.orderRank = item.orderRank
    self.parentFolder = item.folder?.relativePath
    self.originalFileName = item.originalFileName
    self.lastPlayDate = item.lastPlayDate
    self.uuid = item.uuid

    self.externalResources = item.resourcesArray.map({ SimpleExternalResource(from: $0, ignoreLibraryItem: true) })

    switch item.type {
    case .folder:
      self.type = .folder
    case .bound:
      self.type = .bound
    case .book:
      self.type = .book
    }
  }

  /// Title to render in the library tab, honoring the
  /// `libraryDisplayTitleSource` user preference.
  ///
  /// When `useOriginalFileName` is true and the item actually has an
  /// imported filename, returns that. Otherwise falls back to the parsed
  /// `title` — including for legacy items where `originalFileName` is
  /// empty, so toggling the preference can never produce a blank row.
  public func displayTitle(useOriginalFileName: Bool) -> String {
    if useOriginalFileName, !originalFileName.isEmpty {
      return originalFileName
    }
    return title
  }
}

/// Minimal ordered view of a library item for playback navigation walks
/// (prev/next/first-playable). Deliberately tiny: the hot path fetches one of
/// these per sibling instead of a full `SimpleLibraryItem` row, and skips
/// `parseFetchedItems`' folder-details side effects entirely. The chosen
/// neighbor is then materialized via `getSimpleItem(with:)`, which carries
/// the type/metadata the player needs.
public struct SimpleNavigationItem {
  public let relativePath: String
  public let isFinished: Bool

  public init(relativePath: String, isFinished: Bool) {
    self.relativePath = relativePath
    self.isFinished = isFinished
  }
}
