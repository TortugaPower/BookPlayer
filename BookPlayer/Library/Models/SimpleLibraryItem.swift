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
  let artworkData: Data?
  let relativePath: String
  let type: SimpleItemType

  static func == (lhs: SimpleLibraryItem, rhs: SimpleLibraryItem) -> Bool {
      return lhs.relativePath == rhs.relativePath
  }

  func hash(into hasher: inout Hasher) {
      hasher.combine(relativePath)
  }
}

extension SimpleLibraryItem {
  init() {
    self.id = UUID()
    self.title = ""
    self.details = ""
    self.duration = ""
    self.progress = 0
    self.artworkData = nil
    self.relativePath = ""
    self.type = .book
  }

  init(from item: SimpleLibraryItem, defaultArtwork: Data? = nil) {
    self.id = item.id
    self.title = item.title
    self.details = item.details
    self.duration = item.duration
    self.progress = item.progress
    self.artworkData = item.artworkData as Data? ?? defaultArtwork
    self.relativePath = item.relativePath
    self.type = item.type
  }

  init(from item: LibraryItem, defaultArtwork: Data? = nil) {
    if let book = item as? Book {
      self.init(from: book, defaultArtwork: defaultArtwork)
    } else {
      // swiftlint:disable force_cast
      let folder = item as! Folder
      self.init(from: folder, defaultArtwork: defaultArtwork)
    }
  }

  init(from book: Book, defaultArtwork: Data? = nil) {
    self.id = UUID()
    self.title = book.title
    self.details = book.author
    self.duration = TimeParser.formatTotalDuration(book.duration)
    self.progress = book.isFinished ? 1.0 : book.progressPercentage
    self.artworkData = book.artworkData as Data? ?? defaultArtwork
    self.relativePath = book.relativePath
    self.type = .book
  }

  init(from folder: Folder, defaultArtwork: Data? = nil) {
    self.id = UUID()
    self.title = folder.title
    self.details = folder.info()
    self.duration = TimeParser.formatTotalDuration(folder.duration)
    self.progress = folder.isFinished ? 1.0 : folder.progressPercentage
    self.artworkData = folder.artworkData as Data? ?? defaultArtwork
    self.relativePath = folder.relativePath
    self.type = .folder
  }
}

enum SimpleItemType {
  case book, folder
}
