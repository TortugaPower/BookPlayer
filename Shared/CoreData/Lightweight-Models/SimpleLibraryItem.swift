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
  public let duration: String
  public let progress: Double
  public let themeAccent: UIColor
  public let relativePath: String
  public let type: SimpleItemType
  public let playbackState: PlaybackState

  public static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
    return lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(details)
    hasher.combine(progress)
    hasher.combine(playbackState)
  }
}

extension SimpleLibraryItem {
  // Reserved for Add item
  public init() {
    self.title = "Add Button"
    self.details = ""
    self.duration = ""
    self.progress = 0
    self.themeAccent = UIColor(hex: "3488D1")
    self.relativePath = "bookplayer/add-button"
    self.type = .book
    self.playbackState = .stopped
  }

  public init(from item: SimpleLibraryItem, themeAccent: UIColor) {
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = item.playbackState
  }

  public init(from item: SimpleLibraryItem, progress: Double?, playbackState: PlaybackState = .stopped) {
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = progress ?? item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = playbackState
  }

  public init(from item: SimpleLibraryItem, playbackState: PlaybackState) {
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = playbackState
  }

  public init(from item: LibraryItem, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    self.title = item.title
    self.details = item.details
    self.duration = TimeParser.formatTotalDuration(item.duration)
    self.progress = item.isFinished ? 1.0 : item.progressPercentage
    self.themeAccent = themeAccent
    self.relativePath = item.relativePath
    self.playbackState = playbackState

    if let folder = item as? Folder {
      switch folder.type {
      case .folder:
        self.type = .folder
      case .book:
        self.type = .bound
      }
    } else {
      self.type = .book
    }
  }
}
