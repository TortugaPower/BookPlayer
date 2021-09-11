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

class BookmarksViewModel {
  weak var coordinator: BookmarkCoordinator!
  let playerManager: PlayerManager

  init(playerManager: PlayerManager) {
    self.playerManager = playerManager
  }

  func getAutomaticBookmarks() -> [Bookmark] {
    guard let bookmarks = self.playerManager.currentBook?.bookmarks as? Set<Bookmark> else {
      return []
    }

    return Array(bookmarks).filter({ $0.type != .user }).sorted(by: { $0.time < $1.time })
  }

  func getUserBookmarks() -> [Bookmark] {
    guard let bookmarks = self.playerManager.currentBook?.bookmarks as? Set<Bookmark> else {
      return []
    }

    return Array(bookmarks).filter({ $0.type == .user }).sorted(by: { $0.time < $1.time })
  }

  func handleBookmarkSelected(_ bookmark: Bookmark) {
    self.playerManager.jumpTo(bookmark.time + 0.01)
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

  func editNote(_ note: String, for bookmark: Bookmark) {
    BookmarksService.updateNote(note, for: bookmark)
  }

  func getBookmarkNoteAlert(_ bookmark: Bookmark) -> UIAlertController {
    let alert = UIAlertController(title: "bookmark_note_action_title".localized,
                                  message: nil,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = bookmark.note
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: { _ in
      guard let note = alert.textFields?.first?.text else {
        return
      }

      DataManager.addNote(note, bookmark: bookmark)
    }))

    return alert
  }

  func deleteBookmark(_ bookmark: Bookmark) {
    DataManager.deleteBookmark(bookmark)
  }

  func dismiss() {
    self.coordinator.dismiss()
  }
}
