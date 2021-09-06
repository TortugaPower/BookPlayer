//
//  BookmarksViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

struct BookmarksViewModel {
  func getAutomaticBookmarks() -> [Bookmark] {
    guard let bookmarks = PlayerManager.shared.currentBook?.bookmarks as? Set<Bookmark> else {
      return []
    }

    return Array(bookmarks).filter({ $0.type != .user }).sorted(by: { $0.time < $1.time })
  }

  func getUserBookmarks() -> [Bookmark] {
    guard let bookmarks = PlayerManager.shared.currentBook?.bookmarks as? Set<Bookmark> else {
      return []
    }

    return Array(bookmarks).filter({ $0.type == .user }).sorted(by: { $0.time < $1.time })
  }

  func handleBookmarkSelected(_ bookmark: Bookmark) {
    PlayerManager.shared.jumpTo(bookmark.time + 0.01)
  }

  func getBookmarkImageName(for type: BookmarkType) -> String? {
    switch type {
    case .play:
      return "play.fill"
    case .skip:
      return "clock.arrow.2.circlepath"
    case .user:
      return nil
    }
  }
}
