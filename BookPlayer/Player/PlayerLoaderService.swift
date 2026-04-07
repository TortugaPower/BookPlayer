//
//  PlayerLoaderService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/10/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif
import Foundation

@Observable
final class PlayerLoaderService: @unchecked Sendable {
  var syncService: SyncService!
  var libraryService: LibraryService!
  var playbackService: PlaybackServiceProtocol!
  var playerManager: PlayerManagerProtocol!

  init() {}

  func setup(
    syncService: SyncService,
    libraryService: LibraryService,
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
    _ uuid: String,
    autoplay: Bool,
    recordAsLastBook: Bool = true
  ) async throws {
    guard let libraryItem = self.libraryService.getSimpleItem(for: uuid)
    else { return }
    
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(libraryItem.relativePath)
    
    if (syncService.isActive == false && (libraryItem.externalResources?.isEmpty ?? true)),
       !FileManager.default.fileExists(atPath: fileURL.path)
    {
      throw BPPlayerError.fileMissing(relativePath: libraryItem.relativePath)
    }
    
    // Only load if loaded book is a different one
    if playerManager.hasLoadedBook() == true,
       libraryItem.uuid == playerManager.currentItem?.uuid
    {
      if autoplay {
        playerManager.play()
      }
      return
    }
    
    /// If the selected item is a bound book, check that the contents are loaded
    if syncService.isActive == true,
       libraryItem.type == .bound,
       libraryService.getMaxItemsCount(at: libraryItem.relativePath) == 0
    {
      _ = try await syncService.syncListContents(at: libraryItem.relativePath)
    }
    
    let item = try self.playbackService.getPlayableItem(from: libraryItem)
    
    playerManager.load(item, autoplay: autoplay)
    
    if recordAsLastBook {
      libraryService.setLibraryLastBook(with: item.relativePath)
    }
  }
}
