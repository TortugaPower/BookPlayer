//
//  PlayerLoaderService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/10/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif
import Foundation

final class PlayerLoaderService: @unchecked Sendable {
  var syncService: SyncServiceProtocol
  var libraryService: LibraryServiceProtocol
  var playbackService: PlaybackServiceProtocol
  var playerManager: PlayerManagerProtocol

  init(
    syncService: SyncServiceProtocol,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    playerManager: PlayerManagerProtocol
  ) {
    self.syncService = syncService
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager
  }

  @MainActor
  func loadPlayer(
    _ relativePath: String,
    autoplay: Bool,
    recordAsLastBook: Bool = true
  ) async throws {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

    if syncService.isActive == false,
      !FileManager.default.fileExists(atPath: fileURL.path)
    {
      throw BPPlayerError.fileMissing
    }

    // Only load if loaded book is a different one
    if playerManager.hasLoadedBook() == true,
      relativePath == playerManager.currentItem?.relativePath
    {
      if autoplay {
        playerManager.play()
      }
      return
    }

    guard
      let libraryItem = self.libraryService.getSimpleItem(with: relativePath)
    else { return }

    /// If the selected item is a bound book, check that the contents are loaded
    if syncService.isActive == true,
      libraryItem.type == .bound,
      libraryService.getMaxItemsCount(at: relativePath) == 0
    {
      _ = try await syncService.syncListContents(at: relativePath)
    }

    let item = try self.playbackService.getPlayableItem(from: libraryItem)

    playerManager.load(item, autoplay: autoplay)

    if recordAsLastBook {
      await MainActor.run {
        libraryService.setLibraryLastBook(with: item.relativePath)
      }
    }
  }
}
