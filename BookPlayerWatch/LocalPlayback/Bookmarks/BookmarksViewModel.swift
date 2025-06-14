//
//  BookmarksViewModel.swift
//  BookPlayerWatch
//
//  Created by GC on 1/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import Combine
import Foundation

@MainActor
class BookmarksViewModel: ObservableObject {
  @Published var automaticBookmarks = [SimpleBookmark]()
  @Published var userBookmarks = [SimpleBookmark]()
  @Published var selectedBookmarkToDelete: SimpleBookmark?
  private var disposeBag = Set<AnyCancellable>()

  let playerManager: PlayerManager
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  init(coreServices: CoreServices) {
    self.playerManager = coreServices.playerManager
    self.libraryService = coreServices.libraryService
    self.syncService = coreServices.syncService

    self.bindCurrentItemObserver()
  }

  func bindCurrentItemObserver() {
    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
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

  func syncBookmarks(for relativePath: String) {
    Task { @MainActor [weak self] in
      guard
        let self = self,
        let bookmarks = try await self.syncService.syncBookmarksList(relativePath: relativePath)
      else { return }

      self.userBookmarks = bookmarks
    }
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

  func createBookmark() throws {
    guard let currentItem = playerManager.currentItem else { return }

    let currentTime = currentItem.currentTime

    if let bookmark = libraryService.getBookmark(
      at: currentTime,
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      throw BookmarksAlerts.bookmarkExists(bookmark: bookmark)
    }

    if let bookmark = libraryService.createBookmark(
      at: floor(currentTime),
      relativePath: currentItem.relativePath,
      type: .user
    ) {
      syncService.scheduleSetBookmark(
        relativePath: currentItem.relativePath,
        time: floor(currentTime),
        note: nil
      )
      userBookmarks = getUserBookmarks(for: currentItem.relativePath)
      throw BookmarksAlerts.bookmarkCreated(bookmark: bookmark)
    } else {
      throw BookmarksAlerts.fileMissing
    }
  }

  func deleteBookmark(_ bookmark: SimpleBookmark) {
    libraryService.deleteBookmark(bookmark)
    userBookmarks = getUserBookmarks(for: bookmark.relativePath)
    syncService.scheduleDeleteBookmark(bookmark)
  }
}

enum BookmarksAlerts: LocalizedError {
  case bookmarkExists(bookmark: SimpleBookmark)
  case bookmarkCreated(bookmark: SimpleBookmark)
  case fileMissing

  public var errorDescription: String? {
    switch self {
    case .bookmarkExists(let bookmark):
      let formattedTime = TimeParser.formatTime(bookmark.time)
      return String.localizedStringWithFormat("bookmark_exists_title".localized, formattedTime)
    case .bookmarkCreated(let bookmark):
      let formattedTime = TimeParser.formatTime(bookmark.time)
      return String.localizedStringWithFormat("bookmark_created_title".localized, formattedTime)
    case .fileMissing:
      return "file_missing_title".localized
    }
  }
}
