//
//  PlayerLoaderService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/10/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation

@Observable
public final class PlayerLoaderService: @unchecked Sendable {
  public var syncService: SyncService!
  public var libraryService: LibraryService!
  public var playbackService: PlaybackServiceProtocol!
  public var playerManager: PlayerManagerProtocol!

  public init() {}

  public func setup(
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
  public func loadPlayer(
    _ relativePath: String,
    intent: PlayIntent,
    recordAsLastBook: Bool = true
  ) async throws {
    // The loader's contract is a RELATIVE PATH — every launch surface speaks paths (App
    // Intents, CarPlay, search, watch, last-book restore, deep links). Resolution to the
    // item (and its uuid) happens here, in one place. A path that no longer resolves
    // (stale last-book restore, CarPlay/watch reference to a deleted item) must THROW —
    // develop surfaced fileMissing here, and a silent return leaves the tap doing
    // nothing with no explanation.
    guard let libraryItem = self.libraryService.getSimpleItem(with: relativePath)
    else {
      throw BPPlayerError.fileMissing(relativePath: relativePath)
    }
    
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(libraryItem.relativePath)
    
    // Only a media-server link can serve the file instead: a Hardcover link has none
    if syncService.isActive == false,
       libraryItem.externalResources?.streamingResource == nil,
       !FileManager.default.fileExists(atPath: fileURL.path)
    {
      throw BPPlayerError.fileMissing(relativePath: libraryItem.relativePath)
    }
    
    // Only load if loaded book is a different one. Guard on a REAL uuid: two items
    // carrying a placeholder/empty uuid would otherwise match as "already loaded" and
    // the second tap would silently no-op (same rule as PlayableItem.id).
    if playerManager.hasLoadedBook() == true,
       Constants.isRealUuid(libraryItem.uuid),
       libraryItem.uuid == playerManager.currentItem?.uuid
    {
      if case .wantsToPlay(let origin) = intent {
        playerManager.play(origin: origin)
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
    
    playerManager.load(item, intent: intent)
    
    if recordAsLastBook {
      libraryService.setLibraryLastBook(with: item.relativePath)
    }
  }
}
