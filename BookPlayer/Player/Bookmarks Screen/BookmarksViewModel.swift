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

class BookmarksViewModel: BaseViewModel<BookmarkCoordinator> {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let reloadDataPublisher = PassthroughSubject<Bool, Never>()

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func getAutomaticBookmarks() -> [SimpleBookmark] {
    guard let currentItem = self.playerManager.currentItem else { return [] }

    let playBookmarks = self.libraryService.getBookmarks(of: .play, relativePath: currentItem.relativePath) ?? []
    let skipBookmarks = self.libraryService.getBookmarks(of: .skip, relativePath: currentItem.relativePath) ?? []

    let bookmarks = playBookmarks + skipBookmarks

    return bookmarks.sorted(by: { $0.time < $1.time })
  }

  func getUserBookmarks() -> [SimpleBookmark] {
    guard let currentItem = self.playerManager.currentItem else { return [] }

    let bookmarks = self.libraryService.getBookmarks(of: .user, relativePath: currentItem.relativePath) ?? []

    return bookmarks
  }

  func handleBookmarkSelected(_ bookmark: SimpleBookmark) {
    self.playerManager.jumpTo(bookmark.time + 0.01, recordBookmark: false)
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

  func editNote(_ note: String, for bookmark: SimpleBookmark) {
    addNote(note, bookmark: bookmark)
  }

  func getBookmarkNoteAlert(_ bookmark: SimpleBookmark) -> UIAlertController {
    let alert = UIAlertController(title: "bookmark_note_action_title".localized,
                                  message: nil,
                                  preferredStyle: .alert)

    alert.addTextField(configurationHandler: { textfield in
      textfield.text = bookmark.note
    })

    alert.addAction(UIAlertAction(title: "cancel_button".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "ok_button".localized, style: .default, handler: { [weak self] _ in
      guard let note = alert.textFields?.first?.text else {
        return
      }

      self?.addNote(note, bookmark: bookmark)
      self?.reloadDataPublisher.send(true)
    }))

    return alert
  }

  func addNote(_ note: String, bookmark: SimpleBookmark) {
    libraryService.addNote(note, bookmark: bookmark)
    syncService.scheduleSetBookmark(
      relativePath: bookmark.relativePath,
      time: bookmark.time,
      note: note
    )
  }

  func deleteBookmark(_ bookmark: SimpleBookmark) {
    libraryService.deleteBookmark(bookmark)
    syncService.scheduleDeleteBookmark(bookmark)
  }

  func showExportController() {
    guard let currentItem = playerManager.currentItem else { return }

    let bookmarks = getUserBookmarks()

    self.coordinator.showExportController(currentItem: currentItem, bookmarks: bookmarks)
  }
}
