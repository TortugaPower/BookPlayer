//
//  Environment+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension EnvironmentValues {
  @Entry var libraryService: LibraryService = .init()
  @Entry var accountService: AccountService = .init()
  @Entry var syncService: SyncService = .init()
  @Entry var playerLoaderService: PlayerLoaderService = .init()
  @Entry var playbackService: PlaybackService = .init()
  @Entry var jellyfinService: JellyfinConnectionService = .init()
  @Entry var hardcoverService: HardcoverService = .init()
  @Entry var loadingState: LoadingOverlayState = .init()
  @Entry var playerState: PlayerState = .init()
  @Entry var reloadCenter: ListReloadCenter = .init()
}

extension EnvironmentValues {
  /// Cached path for containing folder of playing item in relation to a list path
  @Entry var playingItemParentPath: String?
  @Entry var libraryNode: LibraryNode?
}
