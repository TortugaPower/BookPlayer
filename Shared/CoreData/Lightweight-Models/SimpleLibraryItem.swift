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
    && lhs.title == rhs.title
    && lhs.details == rhs.details
    && lhs.relativePath == rhs.relativePath
    && lhs.progress == rhs.progress
    && lhs.playbackState == rhs.playbackState
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(details)
    hasher.combine(relativePath)
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
    if let book = item as? Book {
      self.init(from: book, themeAccent: themeAccent, playbackState: playbackState)
    } else {
      // swiftlint:disable force_cast
      let folder = item as! Folder
      self.init(from: folder, themeAccent: themeAccent, playbackState: playbackState)
    }
  }

  public init(from book: Book, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    self.title = book.title
    self.details = book.author
    self.duration = TimeParser.formatTotalDuration(book.duration)
    self.progress = book.isFinished ? 1.0 : book.progressPercentage
    self.themeAccent = themeAccent
    self.relativePath = book.relativePath
    self.type = .book
    self.playbackState = playbackState
  }

  public init(from folder: Folder, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    self.title = folder.title
    self.details = folder.info()
    self.duration = TimeParser.formatTotalDuration(folder.duration)
    self.progress = folder.isFinished ? 1.0 : folder.progressPercentage
    self.themeAccent = themeAccent
    self.relativePath = folder.relativePath
    self.type = .folder
    self.playbackState = playbackState
  }
}
