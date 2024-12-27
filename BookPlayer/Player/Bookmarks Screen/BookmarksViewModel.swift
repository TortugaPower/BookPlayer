//
//  BookmarksViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class BookmarksViewModel: ViewModelProtocol {
  /// Available routes for this screen
  enum Routes {
    case export(bookmarks: [SimpleBookmark], item: PlayableItem)
  }

  weak var coordinator: BookmarkCoordinator!

  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  var automaticBookmarks = [SimpleBookmark]()
  var userBookmarks = [SimpleBookmark]()

  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?
  let reloadDataPublisher = PassthroughSubject<Bool, Never>()
  private var disposeBag = Set<AnyCancellable>()

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
  }

  func bindCurrentItemObserver() {
    playerManager.currentItemPublisher()
      .sink { [weak self] currentItem in
        guard let self else { return }

        if let currentItem {
          self.automaticBookmarks = self.getAutomaticBookmarks(for: currentItem.relativePath)
          self.userBookmarks = self.getUserBookmarks(for: currentItem.relativePath)
          self.syncBookmarks(for: currentItem.relativePath)
        } else {
          self.automaticBookmarks = []
          self.userBookmarks = []
        }

        self.reloadDataPublisher.send(true)
      }
      .store(in: &disposeBag)
  }

  func getAutomaticBookmarks(for relativePath: String) -> [SimpleBookmark] {
    let playBookmarks = self.libraryService.getBookmarks(of: .play, relativePath: relativePath) ?? []
    let skipBookmarks = self.libraryService.getBookmarks(of: .skip, relativePath: relativePath) ?? []

    let bookmarks = playBookmarks + skipBookmarks

    return bookmarks.sorted(by: { $0.time < $1.time })
  }

  func getUserBookmarks(for relativePath: String) -> [SimpleBookmark] {
    return self.libraryService.getBookmarks(of: .user, relativePath: relativePath) ?? []
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
    userBookmarks = getUserBookmarks(for: bookmark.relativePath)
    syncService.scheduleSetBookmark(
      relativePath: bookmark.relativePath,
      time: bookmark.time,
      note: note
    )
  }

  func deleteBookmark(_ bookmark: SimpleBookmark) {
    libraryService.deleteBookmark(bookmark)
    userBookmarks = getUserBookmarks(for: bookmark.relativePath)
    syncService.scheduleDeleteBookmark(bookmark)
  }

  func showExportController() {
    guard let currentItem = playerManager.currentItem else { return }

    onTransition?(.export(bookmarks: userBookmarks, item: currentItem))
  }

  func syncBookmarks(for relativePath: String) {
    Task { [weak self] in
      guard
        let self = self,
        let bookmarks = try await self.syncService.syncBookmarksList(relativePath: relativePath)
      else { return }

      self.userBookmarks = bookmarks
      self.reloadDataPublisher.send(true)
    }
  }
}
