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

final class BookmarksViewModel: BookmarksView.Model {
  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  private var disposeBag = Set<AnyCancellable>()
  
  /// Callback for export functionality
  /// TODO: Replace with Transferable protocol implementation
  var onExport: ((PlayableItem, [SimpleBookmark]) -> Void)?

  init(
    playerManager: PlayerManagerProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    self.syncService = syncService
    
    super.init()
    
    self.bindCurrentItemObserver()
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
      }
      .store(in: &disposeBag)
  }

  func getAutomaticBookmarks(for relativePath: String) -> [SimpleBookmark] {
    let playBookmarks = self.libraryService.getBookmarks(of: .play, relativePath: relativePath) ?? []
    let skipBookmarks = self.libraryService.getBookmarks(of: .skip, relativePath: relativePath) ?? []
    let sleepBookmarks = self.libraryService.getBookmarks(of: .sleep, relativePath: relativePath) ?? []

    let bookmarks = playBookmarks + skipBookmarks + sleepBookmarks

    return bookmarks.sorted(by: { $0.time < $1.time })
  }

  func getUserBookmarks(for relativePath: String) -> [SimpleBookmark] {
    return self.libraryService.getBookmarks(of: .user, relativePath: relativePath) ?? []
  }

  override func handleBookmarkSelected(_ bookmark: SimpleBookmark) {
    self.playerManager.jumpTo(bookmark.time + 0.01, recordBookmark: false)
  }

  override func addNote(_ note: String, bookmark: SimpleBookmark) {
    libraryService.addNote(note, bookmark: bookmark)
    userBookmarks = getUserBookmarks(for: bookmark.relativePath)
    syncService.scheduleSetBookmark(
      relativePath: bookmark.relativePath,
      time: bookmark.time,
      note: note
    )
  }

  override func deleteBookmark(_ bookmark: SimpleBookmark) {
    libraryService.deleteBookmark(bookmark)
    userBookmarks = getUserBookmarks(for: bookmark.relativePath)
    syncService.scheduleDeleteBookmark(bookmark)
  }

  override func exportBookmarks() {
    guard let currentItem = playerManager.currentItem else { return }
    onExport?(currentItem, userBookmarks)
  }

  func syncBookmarks(for relativePath: String) {
    Task { [weak self] in
      guard
        let self = self,
        let bookmarks = try await self.syncService.syncBookmarksList(relativePath: relativePath)
      else { return }

      self.userBookmarks = bookmarks
    }
  }
}
