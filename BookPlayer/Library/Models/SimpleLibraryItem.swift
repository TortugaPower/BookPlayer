//
//  SimpleLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

struct SimpleLibraryItem: Hashable, Identifiable {
  let id: UUID
  let title: String
  let details: String
  let duration: String
  let progress: Double
  let themeAccent: UIColor
  let relativePath: String
  let type: SimpleItemType
  let playbackState: PlaybackState

  static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
    return lhs.relativePath == rhs.relativePath
      && lhs.progress == rhs.progress
      && lhs.playbackState == rhs.playbackState
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(relativePath)
    hasher.combine(progress)
    hasher.combine(playbackState)
  }
}

extension SimpleLibraryItem {
  init() {
    self.id = UUID()
    self.title = ""
    self.details = ""
    self.duration = ""
    self.progress = 0
    self.themeAccent = UIColor(hex: "3488D1")
    self.relativePath = ""
    self.type = .book
    self.playbackState = .stopped
  }

  init(from item: SimpleLibraryItem, themeAccent: UIColor) {
    self.id = item.id
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = item.playbackState
  }

  init(from item: SimpleLibraryItem, progress: Double?, playbackState: PlaybackState = .stopped) {
    self.id = item.id
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = progress ?? item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = playbackState
  }

  init(from item: SimpleLibraryItem, playbackState: PlaybackState) {
    self.id = item.id
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = item.progress
    self.themeAccent = item.themeAccent
    self.relativePath = item.relativePath
    self.type = item.type
    self.playbackState = playbackState
  }

  init(from item: LibraryItem, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    if let book = item as? Book {
      self.init(from: book, themeAccent: themeAccent, playbackState: playbackState)
    } else {
      // swiftlint:disable force_cast
      let folder = item as! Folder
      self.init(from: folder, themeAccent: themeAccent, playbackState: playbackState)
    }
  }

  init(from book: Book, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    self.id = UUID()
    self.title = book.title
    self.details = book.author
    self.duration = TimeParser.formatTotalDuration(book.duration)
    self.progress = book.isFinished ? 1.0 : book.progressPercentage
    self.themeAccent = themeAccent
    self.relativePath = book.relativePath
    self.type = .book
    self.playbackState = playbackState
  }

  init(from folder: Folder, themeAccent: UIColor, playbackState: PlaybackState = .stopped) {
    self.id = UUID()
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
